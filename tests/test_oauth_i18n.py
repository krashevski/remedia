#!/usr/bin/env python3
"""Offline OAuth/metadata tests. Google libraries and browser are mocked."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'modules/mediapanel'
sys.path.insert(0, str(MODULE / 'core'))
import remedia_i18n as loc
SCRIPT = MODULE / 'ui/youtube_oauth.py'
spec = importlib.util.spec_from_file_location('oauth_under_test', SCRIPT)
oauth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oauth)


class Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / 'config'
        self.config.mkdir()
        self.environment = patch.dict(os.environ, {'REM_MEDIA_LANG': 'en', 'LANG': 'en_US.UTF-8'})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.creds = Mock(valid=True, expired=False, refresh_token=None, scopes=list(oauth.SCOPES))
        self.creds.to_json.return_value = json.dumps({'token': 'FAKE_TEST_TOKEN'})
        self.credentials = Mock()
        self.credentials.from_authorized_user_file.return_value = self.creds
        self.request = Mock()
        self.flow = Mock()
        self.flow.run_local_server.return_value = self.creds
        self.factory = Mock()
        self.factory.from_client_secrets_file.return_value = self.flow
        self.service = Mock()
        self.service.channels.return_value.list.return_value.execute.return_value = {
            'items': [{'snippet': {'title': 'Test channel {1} 100%'}}]}
        self.build = Mock(return_value=self.service)
        modules = {name: types.ModuleType(name) for name in (
            'google', 'google.auth', 'google.auth.transport', 'google.auth.transport.requests',
            'google.oauth2', 'google.oauth2.credentials', 'google_auth_oauthlib',
            'google_auth_oauthlib.flow', 'googleapiclient', 'googleapiclient.discovery')}
        modules['google.auth.transport.requests'].Request = self.request
        modules['google.oauth2.credentials'].Credentials = self.credentials
        modules['google_auth_oauthlib.flow'].InstalledAppFlow = self.factory
        modules['googleapiclient.discovery'].build = self.build
        self.google = patch.dict(sys.modules, modules)
        self.google.start()
        self.addCleanup(self.google.stop)

    def call(self, action):
        output = io.StringIO()
        with patch.object(sys, 'argv', ['youtube_oauth.py', action, str(self.config)]), contextlib.redirect_stdout(output):
            oauth.main()
        return output.getvalue()

    def token(self):
        path = self.config / 'token.json'
        path.write_text('{"token":"OLD_FAKE"}')
        return path

    def test_check_in_all_languages_without_api_calls(self):
        token = self.token()
        before = token.read_bytes()
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            output = self.call('check')
            self.assertIn(loc.t('MP_OAUTH_TOKEN_VALID'), output)
            self.assertEqual(token.read_bytes(), before)
            self.assertNotIn('OLD_FAKE', output)
        self.build.assert_not_called()
        self.flow.run_local_server.assert_not_called()

    def test_authorize_keeps_atomic_token_permissions(self):
        client = self.config / 'client_secrets.json'
        client.write_text('{}')
        os.environ['REM_MEDIA_LANG'] = 'ru'
        output = self.call('authorize')
        self.assertIn(loc.t('MP_OAUTH_AUTHORIZED'), output)
        self.assertEqual((self.config / 'token.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o700)
        self.assertEqual(json.loads((self.config / 'token.json').read_text()), {'token': 'FAKE_TEST_TOKEN'})
        self.assertEqual(list(self.config.glob('.token-*')), [])
        self.flow.run_local_server.assert_called_once_with(host='localhost', port=0, open_browser=True)
        self.factory.from_client_secrets_file.assert_called_once_with(str(client), oauth.SCOPES)

    def test_refresh_keeps_permissions_and_no_api_upload(self):
        self.token()
        self.creds.valid = False
        self.creds.expired = True
        self.creds.refresh_token = 'FAKE_REFRESH'
        os.environ['REM_MEDIA_LANG'] = 'kk'
        output = self.call('check')
        self.assertIn(loc.t('MP_OAUTH_REFRESHED'), output)
        self.creds.refresh.assert_called_once_with(self.request.return_value)
        self.assertEqual((self.config / 'token.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(self.config.glob('.token-*')), [])
        self.build.assert_not_called()

    def test_test_action_uses_read_only_channel_query(self):
        self.token()
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            output = self.call('test')
            self.assertIn('Test channel {1} 100%', output)
            self.assertIn(loc.t('MP_OAUTH_READ_ONLY'), output)
        self.service.channels.return_value.list.assert_called_with(part='snippet', mine=True, maxResults=1)
        self.service.videos.assert_not_called()

    def test_errors_keep_builtin_class_canonical_text_and_exit_one(self):
        os.environ['REM_MEDIA_LANG'] = 'ru'
        with self.assertRaises(FileNotFoundError) as raised:
            self.call('authorize')
        error = raised.exception
        self.assertIs(type(error), FileNotFoundError)
        self.assertEqual(str(error), 'Install client_secrets.json first')
        self.assertEqual(loc.exception_text(error), 'Сначала установите client_secrets.json')
        stderr = io.StringIO()
        with patch.object(sys, 'argv', ['youtube_oauth.py', 'authorize', str(self.config)]), contextlib.redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as code:
                runpy.run_path(str(SCRIPT), run_name='__main__')
        self.assertEqual(code.exception.code, 1)
        self.assertIn('FileNotFoundError: Сначала установите', stderr.getvalue())
        with self.assertRaises(FileNotFoundError):
            self.call('check')
        self.token()
        self.creds.scopes = []
        with self.assertRaises(ValueError) as raised:
            self.call('check')
        self.assertEqual(str(raised.exception), 'Token lacks required YouTube scopes; reauthorize')
        self.creds.scopes = list(oauth.SCOPES)
        self.creds.valid = False
        with self.assertRaises(RuntimeError):
            self.call('check')

    def test_metadata_variants_have_stable_keys_and_match_catalogs(self):
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            folder = MODULE / 'i18n/meta' / lang
            commands = dict(line.split('=', 1) for line in (folder / 'commands.meta').read_text().splitlines())
            module = dict(line.split('=', 1) for line in (folder / 'module.meta').read_text().splitlines())
            self.assertEqual(set(commands), {'ui', 'status', 'help'})
            self.assertEqual(set(module), {'NAME', 'DESC', 'CATEGORY'})
            self.assertEqual(module['NAME'], 'mediapanel')
            self.assertEqual(module['CATEGORY'], 'media')
            self.assertEqual(module['DESC'], loc.t('MP_META_DESC'))
            for key in commands:
                self.assertEqual(commands[key], loc.t('MP_META_CMD_' + key.upper()))
        for name in ('commands.meta', 'module.meta'):
            self.assertEqual((MODULE / name).read_bytes(), (MODULE / 'i18n/meta/en' / name).read_bytes())

    def test_metadata_selector_and_fallback(self):
        def selected(module, filename, lang, system='en_US.UTF-8'):
            env = dict(os.environ, REM_MEDIA_LANG=lang, LANG=system)
            return subprocess.check_output(['bash', '-eu', '-c',
                'source "$1"; i18n_meta_path "$2" "$3"', 'bash',
                str(ROOT / 'core/i18n.sh'), str(module), filename], env=env, text=True).rstrip('\n')
        for code, lang in [('ru', 'ru'), ('kk', 'kk'), ('kz_KZ.UTF-8', 'kk'), ('C.UTF-8', 'en')]:
            for filename in ('commands.meta', 'module.meta'):
                self.assertEqual(selected(MODULE, filename, code), str(MODULE / 'i18n/meta' / lang / filename))
        self.assertEqual(selected(MODULE, 'commands.meta', 'fr', 'ru_RU.UTF-8'), str(MODULE / 'i18n/meta/ru/commands.meta'))
        plain = Path(self.temp.name) / 'plain module'
        plain.mkdir()
        (plain / 'module.meta').write_text('NAME=plain\nDESC=Plain\nCATEGORY=media\n')
        self.assertEqual(selected(plain, 'module.meta', 'ru'), str(plain / 'module.meta'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
