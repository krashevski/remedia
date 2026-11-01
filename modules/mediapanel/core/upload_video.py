#!/usr/bin/env python3
"""MediaPanel YouTube API backend: OAuth and resumable single-file upload."""
from remedia_i18n import t, value_error, runtime_error, exception_text, ArgumentParser
import argparse
import json
import os
import random
import socket
import sys
import time
from pathlib import Path

SCOPES = ['https://www.googleapis.com/auth/youtube.upload']
RETRY_CODES = {500, 502, 503, 504, 429}


def atomic_json(path, obj):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + f'.tmp-{os.getpid()}')
    try:
        with open(tmp, 'x', encoding='utf-8') as f:
            os.chmod(tmp, 0o600)
            json.dump(obj, f, indent=2, ensure_ascii=False)
            f.write('\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def credentials_for(config_dir, authorize=False):
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    from google_auth_oauthlib.flow import InstalledAppFlow

    config_dir = Path(config_dir).expanduser()
    secrets = config_dir / 'client_secrets.json'
    token = config_dir / 'token.json'
    if not secrets.is_file():
        raise runtime_error('MP_PY_OAUTH_CLIENT_FILE_MISSING', secrets)
    creds = None
    if token.is_file():
        creds = Credentials.from_authorized_user_file(str(token), SCOPES)
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        atomic_json(token, json.loads(creds.to_json()))
    if not creds or not creds.valid:
        if not authorize:
            raise runtime_error('MP_PY_OAUTH_AUTHORIZATION_REQUIRED_RUN_UPLOAD_VIDEO_PY_AUTH')
        flow = InstalledAppFlow.from_client_secrets_file(str(secrets), SCOPES)
        creds = flow.run_local_server(host='localhost', port=0, access_type='offline', prompt='consent')
        atomic_json(token, json.loads(creds.to_json()))
    return creds


def upload(media, metadata, config_dir):
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload
    media = Path(media)
    if not media.is_file() or not media.stat().st_size:
        raise value_error('MP_PY_MISSING_OR_EMPTY_MEDIA_FILE', media)
    with open(metadata, encoding='utf-8') as f:
        data = json.load(f)
    if data.get('platform') != 'youtube' or data.get('media_file') != media.name:
        raise value_error('MP_PY_METADATA_DOES_NOT_MATCH_THE_SELECTED_MEDIA_FILE')
    privacy = data.get('visibility', 'private')
    if privacy not in ('private', 'unlisted', 'public'):
        raise value_error('MP_PY_INVALID_VISIBILITY')
    title = data.get('title')
    if not isinstance(title, str) or not title.strip():
        raise value_error('MP_PY_YOUTUBE_TITLE_MUST_BE_NON_EMPTY')
    tags = data.get('tags', [])
    if not isinstance(tags, list) or any(not isinstance(t, str) for t in tags):
        raise value_error('MP_PY_TAGS_MUST_BE_A_STRING_LIST')
    body = {
        'snippet': {'title': title, 'description': data.get('description', ''),
                    'tags': tags, 'categoryId': str(data.get('category_id', '22'))},
        'status': {'privacyStatus': privacy},
    }
    credentials = credentials_for(config_dir)
    service = build('youtube', 'v3', credentials=credentials, cache_discovery=False)
    media_body = MediaFileUpload(str(media), mimetype='video/mp4', chunksize=8 * 1024 * 1024, resumable=True)
    req = service.videos().insert(part='snippet,status', body=body, media_body=media_body)
    attempts = 0
    while True:
        try:
            status, response = req.next_chunk()
            attempts = 0
            if status is not None:
                print(t('MP_PY_UPLOAD', format(status.progress() * 100, '.1f')), flush=True)
            if response is not None:
                video_id = response.get('id')
                if not video_id:
                    raise runtime_error('MP_PY_YOUTUBE_RETURNED_RESPONSE_WITHOUT_VIDEO_ID_CHECK_THE_CHANNEL_BEFO')
                return video_id
        except (HttpError, OSError, socket.timeout) as exc:
            if isinstance(exc, HttpError) and exc.resp.status not in RETRY_CODES:
                raise
            attempts += 1
            if attempts > 7:
                raise runtime_error('MP_PY_UPLOAD_INTERRUPTED_OUTCOME_UNCERTAIN_CHECK_YOUTUBE_STUDIO_BEFORE') from exc
            wait = min(60, 2 ** attempts) * random.uniform(0.5, 1.0)
            print(t('MP_PY_TEMPORARY_UPLOAD_ERROR_RETRY_7_AFTER_S', attempts, format(wait, '.1f')), file=sys.stderr, flush=True)
            time.sleep(wait)


def main():
    p = ArgumentParser()
    p.add_argument('--config-dir', default=str(Path.home() / '.config/remedia/youtube'))
    sub = p.add_subparsers(dest='command', required=True)
    sub.add_parser('auth', help=t('MP_PY_AUTHORIZE_THE_DESKTOP_OAUTH_CLIENT_IN_THE_BROWSER'))
    up = sub.add_parser('upload', help=t('MP_PY_UPLOAD_ONE_MP4_USING_ITS_MEDIAPANEL_JSON'))
    up.add_argument('--file', required=True)
    up.add_argument('--metadata', required=True)
    args = p.parse_args()
    try:
        if args.command == 'auth':
            credentials_for(args.config_dir, authorize=True)
            print(t('MP_PY_OAUTH_AUTHORIZATION_READY'))
        else:
            video_id = upload(args.file, args.metadata, args.config_dir)
            print('YOUTUBE_VIDEO_ID=' + video_id)
        return 0
    except Exception as exc:
        print(t('MP_PY_ERROR_2', exception_text(exc)), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
