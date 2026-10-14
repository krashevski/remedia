#!/usr/bin/env python3
"""Restore a Remedia compact tar.gz safely; repair paths ONLY in extracted MLT copies.

No pipeline execution and no mutation of the source project/archive.
"""
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
            raise ValueError(f'unsafe path: {raw!r}')
        if not (m.isfile() or m.isdir()):
            raise ValueError(f'unsupported archive entry (link/device): {raw!r}')
        if raw in names:
            raise ValueError(f'duplicate archive member: {raw!r}')
        names.add(raw)
        top.add(p.parts[0])
    if len(top) != 1:
        raise ValueError(f'archive must contain exactly one project directory, found: {sorted(top)}')
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
                print(f'[MISSING .stab] {mlt.relative_to(root)} -> {value}')
                continue
        if candidate is None:
            stats['external_unresolved'] += 1
            print(f'[EXTERNAL] {mlt.relative_to(root)} -> {value}')
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
                print(f'[MISSING] {mlt.relative_to(root)} -> {candidate.relative_to(root)}')
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
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('archive', type=Path, help='compact .tar.gz archive')
    ap.add_argument('--destination', required=True, type=Path, help='existing EMPTY test directory')
    ap.add_argument('--old-root', type=Path, help='original project root; improves absolute path relocation')
    ap.add_argument('--dry-run', action='store_true', help='list/check archive only; do not extract')
    args = ap.parse_args()
    archive = args.archive.expanduser().resolve()
    dest = args.destination.expanduser().resolve()
    old_root = args.old_root.expanduser().resolve() if args.old_root else None
    if not archive.is_file():
        ap.error(f'archive not found: {archive}')
    with tarfile.open(archive, 'r:gz') as tf:
        members, project_name = safe_archive_members(tf)
        project = dest / project_name
        if args.dry_run:
            print(f'[DRY RUN] Project: {project_name}; entries: {len(members)}; destination: {project}')
            return 0
        if project.exists():
            ap.error(f'destination project already exists: {project} (never overwrites)')
        if not dest.is_dir() or any(dest.iterdir()):
            ap.error(f'destination must exist and be empty: {dest}')
        print(f'[EXTRACT] {archive.name} -> {dest}')
        # PEP706 extraction_filter blocks special links as additional protection.
        try:
            tf.extractall(dest, members=members, filter='data')
        except (TypeError, tarfile.FilterError):
            # Do not fall back to unsafe extraction.
            raise RuntimeError('Safe tar extraction requires Python 3.12+ or backported extraction filters')
    project = dest / project_name
    stats = Counter()
    mlts = sorted(project.rglob('*.mlt'))
    for mlt in mlts:
        rewrite_mlt(mlt, project, old_root, stats)
    print(f'[OK] Extracted project: {project}')
    print(f'[MLT] {len(mlts)} projects; repaired properties: {stats["rewritten"]}')
    print(f'[STAB] found: {stats["stab_found"]}, missing: {stats["stab_missing"]}')
    print(f'[MEDIA] missing non-pipeline references: {stats["missing"]}')
    print(f'[PIPELINE] excluded scene references: {stats["pipeline_scenes"]}')
    print(f'[EXTERNAL] unresolved references: {stats["external_unresolved"]}')
    print('[NEXT] No pipeline was executed and no original project was changed.')
    print('[NEXT] Inspect edited MLTs in Shotcut and confirm media paths are under restored root.')
    print('[NEXT] To regenerate pipeline scenes, first restore/copy edit -> media in this TEST project,')
    print('       then run Full pipeline only after reviewing outputs and protecting saved MLTs.')
    if stats['missing'] or stats['stab_missing'] or stats['external_unresolved']:
        print('[WARN] Restored project has unresolved dependencies.')
        return 1
    if stats['pipeline_scenes']:
        print('[WARN] Original pipeline projects need regeneration of scenes for direct playback.')
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, tarfile.TarError, ET.ParseError, RuntimeError) as e:
        print(f'[ERROR] {e}', file=sys.stderr)
        sys.exit(2)
