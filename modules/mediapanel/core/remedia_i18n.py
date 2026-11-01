"""Standard-library adapter for the same module *.env dictionaries as Bash t().

No shell execution, subprocesses, network calls or import-time file reads.
Exceptions keep canonical English str() for persistent machine records.
"""
import argparse
import os
from pathlib import Path
import re
import sys
from functools import lru_cache

_DIRECTORY = Path(__file__).resolve().parent.parent / 'i18n'
_KEY = re.compile(r'^[A-Z][A-Z0-9_]*$')
_TOKEN = re.compile(r'\{([1-9])\}')
_ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\'}


def _locale(value):
    code = re.split(r'[_.@-]', (value or 'en').lower(), maxsplit=1)[0]
    if code == 'kz':
        code = 'kk'
    return code if code not in ('c', 'posix') and re.fullmatch(r'[a-z]{2,3}', code) else 'en'


def _decode(raw):
    if len(raw) < 2 or raw[0] not in ('"', "'") or raw[-1] != raw[0]:
        raise ValueError('expected a quoted value')
    quote, content = raw[0], raw[1:-1]
    out, index = [], 0
    while index < len(content):
        char = content[index]
        if quote == '"' and char == '\\':
            index += 1
            if index >= len(content) or content[index] not in _ESCAPES:
                raise ValueError('invalid escape')
            out.append(_ESCAPES[content[index]])
        elif char == quote:
            raise ValueError('unescaped quote')
        else:
            out.append(char)
        index += 1
    return ''.join(out)


def _read(path):
    values = {}
    with path.open(encoding='utf-8', newline=None) as stream:
        for number, line in enumerate(stream, 1):
            line = line.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            key, separator, raw = line.partition('=')
            if not separator or not _KEY.fullmatch(key) or key in values:
                raise ValueError(f'{path}:{number}: invalid or duplicate key')
            values[key] = _decode(raw)
    return values


@lru_cache(maxsize=16)
def _tables(directory, override, system):
    directory = Path(directory)
    try:
        english = _read(directory / 'en.env')
    except (OSError, ValueError, UnicodeError) as exc:
        print(f'[i18n] Cannot read English dictionary: {exc}', file=sys.stderr)
        return {}, {}
    selected = {}
    for language in (override, system, 'en'):
        path = directory / f'{language}.env'
        if not path.is_file():
            continue
        if language == 'en':
            break
        try:
            selected = _read(path)
            if selected.keys() - english.keys():
                raise ValueError(f'{path}: translation keys missing from English')
        except (OSError, ValueError, UnicodeError) as exc:
            print(f'[i18n] Cannot read translation dictionary; using English: {exc}', file=sys.stderr)
            selected = {}
        break
    return english, selected


def _lookup(key, english_only=False):
    system = _locale(os.environ.get('LANG'))
    override = _locale(os.environ.get('REM_MEDIA_LANG') or os.environ.get('LANG'))
    english, selected = _tables(str(_DIRECTORY), override, system)
    return ('' if english_only else selected.get(key)) or english.get(key) or key


def _render(text, args):
    # One pass: tokens inside argument values are not expanded recursively.
    return _TOKEN.sub(lambda m: str(args[int(m[1]) - 1]) if int(m[1]) <= len(args) else m[0], text)


def t(key, *args):
    if not isinstance(key, str) or not _KEY.fullmatch(key):
        return str(key)
    return _render(_lookup(key), args)


class _MessageError:
    def __init__(self, key, *arguments):
        self.i18n_key = key
        self.i18n_arguments = arguments
        super().__init__(_render(_lookup(key, english_only=True), arguments))


class LocalizedValueError(_MessageError, ValueError):
    pass


class LocalizedRuntimeError(_MessageError, RuntimeError):
    pass


def value_error(key, *args):
    return LocalizedValueError(key, *args)


def runtime_error(key, *args):
    return LocalizedRuntimeError(key, *args)


def exception_text(exc):
    if isinstance(exc, _MessageError):
        return t(exc.i18n_key, *exc.i18n_arguments)
    message = getattr(exc, '_remedia_i18n_message', None)
    if message is not None:
        return t(message[0], *message[1])
    return str(exc)


def message_error(error_type, key, *args):
    """Preserve the original exception class/name and canonical str()."""
    exc = error_type(_render(_lookup(key, english_only=True), args))
    exc._remedia_i18n_message = (key, args)
    return exc


def _argument_error(message):
    for prefix, key in (
        ('the following arguments are required: ', 'MP_PY_ARGS_REQUIRED'),
        ('unrecognized arguments: ', 'MP_PY_ARGS_UNRECOGNIZED'),
        ('invalid choice: ', 'MP_PY_ARGS_INVALID_CHOICE'),
    ):
        if message.startswith(prefix):
            return t(key, message[len(prefix):])
    if message.startswith('argument ') and ': ' in message:
        argument, detail = message[len('argument '):].split(': ', 1)
        if detail == 'expected one argument':
            detail = t('MP_PY_ARGS_EXPECTED_ONE')
        elif detail.startswith('invalid choice: '):
            detail = t('MP_PY_ARGS_INVALID_CHOICE', detail[len('invalid choice: '):])
        return t('MP_PY_ARGS_ARGUMENT', argument, detail)
    return message


class ArgumentParser(argparse.ArgumentParser):
    """Localized headings/help and common CLI errors without patching argparse."""
    def __init__(self, *args, **kwargs):
        add_help = kwargs.pop('add_help', True)
        super().__init__(*args, add_help=False, **kwargs)
        for group in self._action_groups:
            if group.title == 'positional arguments':
                group.title = t('MP_PY_ARGS_POSITIONAL')
            elif group.title == 'options':
                group.title = t('MP_PY_ARGS_OPTIONS')
        if add_help:
            self.add_argument('-h', '--help', action='help', help=t('MP_PY_ARGS_HELP'))

    @staticmethod
    def _usage(text):
        return t('MP_PY_ARGS_USAGE') + text[len('usage: '):] if text.startswith('usage: ') else text

    def format_usage(self):
        return self._usage(super().format_usage())

    def format_help(self):
        return self._usage(super().format_help())

    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(2, t('MP_PY_ARGS_ERROR', self.prog, _argument_error(message)) + '\n')
