#!/usr/bin/env python3
"""Offline tests: local tar/MLT and fully mocked Google API/OAuth."""
import contextlib
import hashlib
import importlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / 'modules/mediapanel/core'
sys.path.insert(0, str(CORE))
import remedia_i18n as loc
import upload_video as uploader
import youtube_worker as worker
import restore_compact_project as restore


class Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.environment = patch.dict(os.environ, {'LANG': 'en_US.UTF-8', 'REM_MEDIA_LANG': 'en'})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def run_script(self, name, *args, lang='en'):
        env = dict(os.environ, REM_MEDIA_LANG=lang)
        return subprocess.run([sys.executable, str(CORE / name), *map(str, args)], env=env,
                              capture_output=True, text=True, timeout=15)

    def test_catalogs_and_bash_parity(self):
        directory = CORE.parent / 'i18n'
        catalogs = {lang: loc._read(directory / f'{lang}.env') for lang in ('en', 'ru', 'kk')}
        self.assertEqual(len(catalogs['en']), 859)
        for lang in ('ru', 'kk'):
            self.assertEqual(catalogs[lang].keys(), catalogs['en'].keys())
            for key, value in catalogs[lang].items():
                self.assertEqual(sorted(loc._TOKEN.findall(value)), sorted(loc._TOKEN.findall(catalogs['en'][key])), key)
        for path in CORE.glob('*.py'):
            compile(path.read_text(), str(path), 'exec')
            for key in re.findall(r"(?:t|value_error|runtime_error)\(['\"](MP_[A-Z0-9_]+)", path.read_text()):
                self.assertIn(key, catalogs['en'])
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            for key in ('MP_PY_UPLOADED', 'MP_PY_TEMPORARY_UPLOAD_ERROR_RETRY_7_AFTER_S', 'MP_PY_ARGS_USAGE'):
                args = ['100% {2} $HOME', 'file_{1}.mp4']
                result = subprocess.check_output(['bash', '-c',
                    'source "$1"; i18n_load "$2"; shift 2; t "$@"', 'bash',
                    str(ROOT / 'core/i18n.sh'), str(directory), key, *args], text=True)
                self.assertEqual(result, loc.t(key, *args) + '\n')

    def test_fallback_and_no_execution(self):
        directory = self.root / 'i18n'
        directory.mkdir()
        (directory / 'en.env').write_text('TEST="English {1}"\nLITERAL=\'$(touch injected) `id` $HOME\'\n')
        (directory / 'ru.env').write_text('TEST="Русский {1}"\n')
        (directory / 'kk.env').write_text('TEST="Қазақ {1}"\n')
        with patch.object(loc, '_DIRECTORY', directory):
            os.environ.update(REM_MEDIA_LANG='fr_FR.UTF-8', LANG='ru_RU.UTF-8')
            self.assertEqual(loc.t('TEST', '{2}'), 'Русский {2}')
            os.environ['REM_MEDIA_LANG'] = 'kz_KZ.UTF-8'
            self.assertEqual(loc.t('TEST', 'X'), 'Қазақ X')
            self.assertEqual(loc.t('LITERAL'), '$(touch injected) `id` $HOME')
            self.assertEqual(loc.t('UNKNOWN'), 'UNKNOWN')
            os.environ.update(REM_MEDIA_LANG='', LANG='C.UTF-8')
            self.assertEqual(loc.t('TEST', 'X'), 'English X')

    def test_help_and_cli_error_codes(self):
        for lang, word in [('ru', 'параметры'), ('kk', 'параметрлер')]:
            for name in ('restore_compact_project.py', 'upload_video.py', 'youtube_worker.py'):
                result = self.run_script(name, '--help', lang=lang)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(word, result.stdout)
        result = self.run_script('restore_compact_project.py', lang='ru')
        self.assertEqual(result.returncode, 2)
        self.assertIn('требуются следующие аргументы', result.stderr)
        result = self.run_script('upload_video.py', 'upload', '--file', lang='kk')
        self.assertEqual(result.returncode, 2)
        self.assertIn('бір аргумент күтілуде', result.stderr)

    def make_archive(self):
        project = self.root / '001_Project_{1}_100%'
        (project / 'edit').mkdir(parents=True)
        (project / 'video').mkdir()
        (project / 'edit/clip.mp4').write_bytes(b'test media')
        mlt = project / 'video/custom.mlt'
        mlt.write_text(f'<mlt><producer><property name="resource">{project}/edit/clip.mp4</property></producer></mlt>')
        archive = self.root / 'compact.tar.gz'
        with tarfile.open(archive, 'w:gz') as tf:
            tf.add(project, arcname=project.name)
        return project, archive, mlt

    def test_archive_check_restore_and_source_integrity(self):
        project, archive, mlt = self.make_archive()
        before_archive = archive.read_bytes()
        before_mlt = mlt.read_bytes()
        outputs = []
        for lang in ('en', 'ru', 'kk'):
            result = self.run_script('archive_mlt_check.py', project, 'video', 'edit', lang=lang)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('[MLT]', result.stdout)
            dest = self.root / lang
            dest.mkdir()
            result = self.run_script('restore_compact_project.py', archive, '--destination', dest,
                                     '--old-root', project, lang=lang)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            target = dest / project.name / 'video/custom.mlt'
            outputs.append(target.read_bytes())
            self.assertIn(b'../edit/clip.mp4', outputs[-1])
            self.assertEqual(target.with_suffix('.mlt.before-path-repair').read_bytes(), before_mlt)
            self.assertEqual(archive.read_bytes(), before_archive)
            self.assertEqual(mlt.read_bytes(), before_mlt)
            # Repeated restore must refuse to overwrite.
            self.assertEqual(self.run_script('restore_compact_project.py', archive, '--destination', dest, lang=lang).returncode, 2)
        self.assertEqual(outputs[0], outputs[1])
        self.assertEqual(outputs[0], outputs[2])
        dry = self.root / 'dry'
        result = self.run_script('restore_compact_project.py', archive, '--destination', dry, '--dry-run', lang='kk')
        self.assertEqual(result.returncode, 0)
        self.assertFalse(dry.exists())

    def test_unsafe_archive_rejected_without_extracting(self):
        archive = self.root / 'unsafe.tar.gz'
        with tarfile.open(archive, 'w:gz') as tf:
            info = tarfile.TarInfo('../escaped')
            info.size = 1
            tf.addfile(info, io.BytesIO(b'x'))
        destination = self.root / 'dest'
        destination.mkdir()
        result = self.run_script('restore_compact_project.py', archive, '--destination', destination, lang='ru')
        self.assertEqual(result.returncode, 2)
        self.assertIn('небезопасный путь', result.stderr)
        self.assertEqual(list(destination.iterdir()), [])
        self.assertFalse((self.root / 'escaped').exists())

    def job(self, suffix=''):
        media = self.root / f'video{suffix}.mp4'
        metadata = self.root / f'video{suffix}.youtube.json'
        job = self.root / f'job{suffix}.json'
        media.write_bytes(b'test media')
        metadata.write_text(json.dumps({'status': 'prepared', 'title': 'Title {1}', 'platform': 'youtube',
                                       'media_file': media.name, 'visibility': 'private'}))
        job.write_text(json.dumps({'action': 'youtube_upload', 'status': 'queued', 'items':
                                  [{'media_file': str(media), 'metadata_file': str(metadata), 'status': 'queued'}]}))
        return media, metadata, job

    def test_worker_success_and_no_duplicate_upload(self):
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            media, metadata, job = self.job(lang)
            with patch.object(worker, 'upload', return_value='VIDEO_ID') as fake, contextlib.redirect_stdout(io.StringIO()):
                self.assertTrue(worker.process(job, self.root))
                self.assertTrue(worker.process(job, self.root))
                fake.assert_called_once()
            data = json.loads(job.read_text())
            self.assertEqual(data['status'], 'completed')
            self.assertEqual(data['items'][0]['status'], 'uploaded')
            self.assertEqual(data['items'][0]['video_id'], 'VIDEO_ID')
            sidecar = json.loads(metadata.read_text())
            self.assertEqual(sidecar['backend'], 'youtube_api')
            self.assertEqual(sidecar['title'], 'Title {1}')
            # A second queue entry referencing an uploaded sidecar must not upload.
            other = self.root / f'other{lang}.json'
            other.write_text(json.dumps({'action': 'youtube_upload', 'status': 'queued', 'items':
                [{'media_file': str(media), 'metadata_file': str(metadata), 'status': 'queued'}]}))
            with patch.object(worker, 'upload', side_effect=AssertionError('must not upload')), contextlib.redirect_stdout(io.StringIO()):
                self.assertTrue(worker.process(other, self.root))

    def test_uncertain_upload_keeps_canonical_json_and_blocks_retry(self):
        key = 'MP_PY_UPLOAD_INTERRUPTED_OUTCOME_UNCERTAIN_CHECK_YOUTUBE_STUDIO_BEFORE'
        canonical = 'Upload interrupted; outcome uncertain. Check YouTube Studio before retrying'
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            _, _, job = self.job(lang)
            error = loc.runtime_error(key)
            self.assertIsInstance(error, RuntimeError)
            self.assertEqual(str(error), canonical)
            stderr = io.StringIO()
            with patch.object(worker, 'upload', side_effect=error) as fake, contextlib.redirect_stderr(stderr):
                self.assertFalse(worker.process(job, self.root))
                self.assertFalse(worker.process(job, self.root))
                fake.assert_called_once()
            data = json.loads(job.read_text())
            self.assertEqual(data['status'], 'needs_review')
            self.assertEqual(data['items'][0]['error'], canonical)
            self.assertIn(loc.exception_text(error), stderr.getvalue())

    def google_stubs(self, request):
        class HttpError(Exception):
            pass
        service = Mock()
        service.videos.return_value.insert.return_value = request
        modules = {
            'googleapiclient': types.ModuleType('googleapiclient'),
            'googleapiclient.discovery': types.SimpleNamespace(build=Mock(return_value=service)),
            'googleapiclient.errors': types.SimpleNamespace(HttpError=HttpError),
            'googleapiclient.http': types.SimpleNamespace(MediaFileUpload=Mock()),
        }
        return patch.dict(sys.modules, modules)

    def test_upload_retry_and_machine_stdout(self):
        media, metadata, _ = self.job()
        for lang in ('en', 'ru', 'kk'):
            os.environ['REM_MEDIA_LANG'] = lang
            request = Mock()
            request.next_chunk.side_effect = [(Mock(progress=lambda: .5), None), (None, {'id': 'ID'})]
            with self.google_stubs(request), patch.object(uploader, 'credentials_for', return_value=object()), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(uploader.upload(media, metadata, self.root), 'ID')
                self.assertIn('50.0%', output.getvalue())
            request = Mock()
            request.next_chunk.side_effect = OSError('mock transport failure')
            with self.google_stubs(request), patch.object(uploader, 'credentials_for', return_value=object()), patch.object(uploader.time, 'sleep') as sleep, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(loc.LocalizedRuntimeError):
                    uploader.upload(media, metadata, self.root)
                self.assertEqual(request.next_chunk.call_count, 8)
                self.assertEqual(sleep.call_count, 7)
            with patch.object(sys, 'argv', ['upload_video.py', 'upload', '--file', str(media), '--metadata', str(metadata)]), patch.object(uploader, 'upload', return_value='ABC123'), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(uploader.main(), 0)
                self.assertEqual(output.getvalue(), 'YOUTUBE_VIDEO_ID=ABC123\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
