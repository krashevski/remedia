#!/usr/bin/env python3
"""Restore a Remedia compact tar.gz safely; repair paths ONLY in extracted MLT copies.

No pipeline execution and no mutation of the source project/archive.
"""
from remedia_i18n import t, value_error, runtime_error, exception_text, ArgumentParser
import argparse
import os
import shutil
import sys
import tarfile
import tempfile
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path, PurePosixPath

MEDIA_KEYS = {'resource', 'filename', 'results', 'warp_resource', 'av.file', 'shotcut:resource', 'luma'}
SKIP_PREFIXES = ('color:', '#', 'https:', 'http:', '0x', 'pipe:', 'lavfi:', 'qtext:', 'data:')

def safe_archive_members(tf):
    members = tf.getmembers()
    names = set()
    top = set()
    for m in members:
        raw = m.name
        p = PurePosixPath(raw)
        if not raw or raw.startswith('/') or '..' in p.parts or not p.parts or p.parts[0] in ('', '.'):
            raise value_error('MP_PY_UNSAFE_PATH', repr(raw))
        if not (m.isfile() or m.isdir()):
            raise value_error('MP_PY_UNSUPPORTED_ARCHIVE_ENTRY_LINK_DEVICE', repr(raw))
        if raw in names:
            raise value_error('MP_PY_DUPLICATE_ARCHIVE_MEMBER', repr(raw))
        names.add(raw)
        top.add(p.parts[0])
    if len(top) != 1:
        raise value_error('MP_PY_ARCHIVE_MUST_CONTAIN_EXACTLY_ONE_PROJECT_DIRECTORY_FOUND', sorted(top))
    return members, next(iter(top))

def is_path_value(value):
    if not value or value.isdigit() or value in ('black', 'transparent'):
        return False
    if value.startswith(SKIP_PREFIXES) or '://' in value:
        return False
    return True

def canonical_candidate(mlt, value, root, old_root):
    """Return a local restored path only if the original reference maps unambiguously.

    For absolute references accept only exact old root or an unambiguous /projects/NAME
    suffix; unknown outside files remain untouched.
    """
    ref = Path(value)
    if not ref.is_absolute():
        p = (mlt.parent / ref).resolve(strict=False)
        if p.is_relative_to(root):
            return p
        # Shotcut projects sometimes contain ../... traversing outside project root.
        return None
    if old_root:
        if ref == old_root or ref.is_relative_to(old_root):
            return root / ref.relative_to(old_root)
    parts = ref.parts
    matches = [i for i in range(len(parts)-1) if parts[i] == 'projects' and parts[i+1] == root.name]
    if len(matches) == 1:
        return root.joinpath(*parts[matches[0]+2:])
    return None

def rewrite_mlt(mlt, root, old_root, stats, dry_run=False):
    tree = ET.parse(mlt)
    changed = False
    for prop in tree.iter('property'):
        key = prop.get('name')
        if key not in MEDIA_KEYS or not prop.text:
            continue
        raw = prop.text.strip()
        if not is_path_value(raw):
            continue
        # Preserve MLT's stream_index:path form.
        prefix, value = '', raw
        if ':' in raw and raw.split(':', 1)[0].isdigit():
            prefix, value = raw.split(':', 1)
            prefix += ':'
        ref = Path(value)
        candidate = canonical_candidate(mlt, value, root, old_root)
        if ref.suffix.lower() == '.stab':
            # Shotcut may record partial results paths. Sibling is authoritative.
            beside = mlt.parent / ref.name
            if beside.is_file():
                candidate = beside
                stats['stab_found'] += 1
            else:
                stats['stab_missing'] += 1
                print(t('MP_PY_MISSING_STAB', mlt.relative_to(root), value))
                continue
        if candidate is None:
            stats['external_unresolved'] += 1
            print(t('MP_PY_EXTERNAL', mlt.relative_to(root), value))
            continue
        if not candidate.is_relative_to(root):
            stats['external_unresolved'] += 1
            continue
        if not candidate.exists():
            if candidate.is_relative_to(root / 'scenes') and mlt.name in {
                f'{root.name}_short.mlt', f'{root.name}_video.mlt'
            } and mlt.parent.name in ('short', 'video'):
                stats['pipeline_scenes'] += 1
            else:
                stats['missing'] += 1
                print(t('MP_PY_MISSING', mlt.relative_to(root), candidate.relative_to(root)))
            continue
        relative = os.path.relpath(candidate, mlt.parent)
        new_value = prefix + relative
        if raw != new_value:
            prop.text = new_value
            changed = True
            stats['rewritten'] += 1
    if changed and not dry_run:
        # Atomic write, copies only (archive never touched). Backup remains in the restored folder.
        backup = mlt.with_suffix(mlt.suffix + '.before-path-repair')
        shutil.copy2(mlt, backup)
        fd, tmp = tempfile.mkstemp(prefix='.remedia-', suffix='.mlt', dir=mlt.parent)
        try:
            with os.fdopen(fd, 'wb') as f:
                tree.write(f, encoding='utf-8', xml_declaration=True)
            ET.parse(tmp)
            os.replace(tmp, mlt)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
    return changed

def main():
    ap = ArgumentParser(description=t('MP_PY_RESTORE_A_REMEDIA_COMPACT_TAR_GZ_SAFELY_REPAIR_PATHS_ONLY_IN_EXTR'))
    ap.add_argument('archive', type=Path, help=t('MP_PY_COMPACT_TAR_GZ_ARCHIVE'))
    ap.add_argument('--destination', required=True, type=Path, help=t('MP_PY_EXISTING_EMPTY_TEST_DIRECTORY'))
    ap.add_argument('--old-root', type=Path, help=t('MP_PY_ORIGINAL_PROJECT_ROOT_IMPROVES_ABSOLUTE_PATH_RELOCATION'))
    ap.add_argument('--dry-run', action='store_true', help=t('MP_PY_LIST_CHECK_ARCHIVE_ONLY_DO_NOT_EXTRACT'))
    args = ap.parse_args()
    archive = args.archive.expanduser().resolve()
    dest = args.destination.expanduser().resolve()
    old_root = args.old_root.expanduser().resolve() if args.old_root else None
    if not archive.is_file():
        ap.error(t('MP_PY_ARCHIVE_NOT_FOUND', archive))
    with tarfile.open(archive, 'r:gz') as tf:
        members, project_name = safe_archive_members(tf)
        project = dest / project_name
        if args.dry_run:
            print(t('MP_PY_DRY_RUN_PROJECT_ENTRIES_DESTINATION', project_name, len(members), project))
            return 0
        if project.exists():
            ap.error(t('MP_PY_DESTINATION_PROJECT_ALREADY_EXISTS_NEVER_OVERWRITES', project))
        if not dest.is_dir() or any(dest.iterdir()):
            ap.error(t('MP_PY_DESTINATION_MUST_EXIST_AND_BE_EMPTY', dest))
        print(t('MP_PY_EXTRACT', archive.name, dest))
        # PEP706 extraction_filter blocks special links as additional protection.
        try:
            tf.extractall(dest, members=members, filter='data')
        except (TypeError, tarfile.FilterError):
            # Do not fall back to unsafe extraction.
            raise runtime_error('MP_PY_SAFE_TAR_EXTRACTION_REQUIRES_PYTHON_3_12_OR_BACKPORTED_EXTRACTION')
    project = dest / project_name
    stats = Counter()
    mlts = sorted(project.rglob('*.mlt'))
    for mlt in mlts:
        rewrite_mlt(mlt, project, old_root, stats)
    print(t('MP_PY_OK_EXTRACTED_PROJECT', project))
    print(t('MP_PY_MLT_PROJECTS_REPAIRED_PROPERTIES', len(mlts), stats["rewritten"]))
    print(t('MP_PY_STAB_FOUND_MISSING', stats["stab_found"], stats["stab_missing"]))
    print(t('MP_PY_MEDIA_MISSING_NON_PIPELINE_REFERENCES', stats["missing"]))
    print(t('MP_PY_PIPELINE_EXCLUDED_SCENE_REFERENCES', stats["pipeline_scenes"]))
    print(t('MP_PY_EXTERNAL_UNRESOLVED_REFERENCES', stats["external_unresolved"]))
    print(t('MP_PY_NEXT_NO_PIPELINE_WAS_EXECUTED_AND_NO_ORIGINAL_PROJECT_WAS_CHANGED'))
    print(t('MP_PY_NEXT_INSPECT_EDITED_MLTS_IN_SHOTCUT_AND_CONFIRM_MEDIA_PATHS_ARE_U'))
    print(t('MP_PY_NEXT_TO_REGENERATE_PIPELINE_SCENES_FIRST_RESTORE_COPY_EDIT_MEDIA'))
    print(t('MP_PY_THEN_RUN_FULL_PIPELINE_ONLY_AFTER_REVIEWING_OUTPUTS_AND_PROTECTIN'))
    if stats['missing'] or stats['stab_missing'] or stats['external_unresolved']:
        print(t('MP_PY_WARN_RESTORED_PROJECT_HAS_UNRESOLVED_DEPENDENCIES'))
        return 1
    if stats['pipeline_scenes']:
        print(t('MP_PY_WARN_ORIGINAL_PIPELINE_PROJECTS_NEED_REGENERATION_OF_SCENES_FOR_D'))
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, tarfile.TarError, ET.ParseError, RuntimeError) as e:
        print(t('MP_PY_ERROR', exception_text(e)), file=sys.stderr)
        sys.exit(2)
