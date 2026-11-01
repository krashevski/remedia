#!/usr/bin/env python3
"""YouTube OAuth management for MediaPanel; no upload operations."""
import json
import os
import sys
from pathlib import Path

# This UI script shares the core adapter and the module's existing dictionaries.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "core"))
from remedia_i18n import t, message_error, exception_text

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.readonly",
]


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in {"authorize", "check", "test"}:
        raise message_error(ValueError, "MP_OAUTH_USAGE")
    action, config_dir = sys.argv[1], Path(sys.argv[2]).expanduser()
    client = config_dir / "client_secrets.json"
    token_file = config_dir / "token.json"
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials

    if action == "authorize":
        if not client.is_file():
            raise message_error(FileNotFoundError, "MP_OAUTH_INSTALL_CLIENT")
        from google_auth_oauthlib.flow import InstalledAppFlow
        flow = InstalledAppFlow.from_client_secrets_file(str(client), SCOPES)
        creds = flow.run_local_server(host="localhost", port=0, open_browser=True)
        config_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        os.chmod(config_dir, 0o700)
        # Use exclusive mode and atomic replacement to avoid exposing a partial token.
        import tempfile
        fd, temp_name = tempfile.mkstemp(prefix=".token-", suffix=".json", dir=config_dir)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as out:
                os.fchmod(out.fileno(), 0o600)
                out.write(creds.to_json())
            os.replace(temp_name, token_file)
        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)
        print(t("MP_OAUTH_AUTHORIZED"))
        return

    if not token_file.is_file():
        raise message_error(FileNotFoundError, "MP_OAUTH_TOKEN_MISSING")
    creds = Credentials.from_authorized_user_file(str(token_file))
    if not set(SCOPES).issubset(set(creds.scopes or [])):
        raise message_error(ValueError, "MP_OAUTH_SCOPES_MISSING")
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            # Persist refreshed token with restricted permissions, atomically.
            import tempfile
            fd, temp_name = tempfile.mkstemp(prefix=".token-", suffix=".json", dir=config_dir)
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as out:
                    os.fchmod(out.fileno(), 0o600)
                    out.write(creds.to_json())
                os.replace(temp_name, token_file)
            finally:
                if os.path.exists(temp_name):
                    os.unlink(temp_name)
            print(t("MP_OAUTH_REFRESHED"))
        else:
            raise message_error(RuntimeError, "MP_OAUTH_TOKEN_INVALID")
    print(t("MP_OAUTH_TOKEN_VALID"))
    if action == "test":
        from googleapiclient.discovery import build
        svc = build("youtube", "v3", credentials=creds, cache_discovery=False)
        result = svc.channels().list(part="snippet", mine=True, maxResults=1).execute()
        items = result.get("items", [])
        if not items:
            raise message_error(RuntimeError, "MP_OAUTH_NO_CHANNEL")
        print(t("MP_OAUTH_CONNECTED", items[0].get("snippet", {}).get("title", t("MP_OAUTH_UNNAMED_CHANNEL"))))
        print(t("MP_OAUTH_READ_ONLY"))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(t("MP_OAUTH_ERROR", type(e).__name__, exception_text(e)), file=sys.stderr)
        sys.exit(1)
