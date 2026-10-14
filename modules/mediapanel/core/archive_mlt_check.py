#!/usr/bin/env python3
"""Read-only compact archive preflight for Shotcut MLT dependencies."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    if len(sys.argv) < 3:
        print('Usage: archive_mlt_check.py PROJECT_DIR KEEP_DIR [KEEP_DIR ...]', file=sys.stderr)
        return 2

    project = Path(sys.argv[1]).resolve()
    if not project.is_dir():
        print(f'[ERROR] Project directory does not exist: {project}', file=sys.stderr)
        return 2
    keep = set(sys.argv[2:])
    pipeline_names = {f'{project.name}_short.mlt', f'{project.name}_video.mlt'}
    mlts = sorted(project.rglob('*.mlt'))
    missing, excluded, external = [], [], []
    skipped_scenes = 0
    resolved_stab = 0
    keys = {'resource', 'filename', 'results', 'warp_resource', 'luma', 'av.file', 'shotcut:resource'}

    for mlt in mlts:
        try:
            tree = ET.parse(mlt)
        except (ET.ParseError, OSError) as exc:
            missing.append((str(mlt.relative_to(project)), 'invalid/unreadable MLT XML: ' + str(exc)))
            continue
        for prop in tree.iter('property'):
            if prop.attrib.get('name') not in keys or not prop.text:
                continue
            value = prop.text.strip()
            if not value or value.isdigit() or value.startswith((
                'color:', '#', 'https:', 'http:', '0x', 'pipe:', 'lavfi:',
                'qtext:', 'data:'
            )) or '://' in value or value in ('black', 'transparent'):
                continue
            if ':' in value and value.split(':', 1)[0].isdigit():
                value = value.split(':', 1)[1]
            reference = Path(value)
            path = (reference if reference.is_absolute() else mlt.parent / reference).resolve()

            # Shotcut stabilization results may contain truncated paths.
            # Resolve the original reference first, then the file beside the MLT.
            if reference.suffix.lower() == '.stab' and not path.is_file():
                sibling = (mlt.parent / reference.name).resolve()
                if sibling.is_file():
                    path = sibling
                    resolved_stab += 1

            try:
                rel = path.relative_to(project)
            except ValueError:
                if path.exists():
                    external.append((mlt.name, str(path)))
                else:
                    missing.append((mlt.name, str(path)))
                continue

            # Only auto-generated root-level pipeline MLTs can have rebuildable scenes.
            if mlt.parent == project / 'short' or mlt.parent == project / 'video':
                is_pipeline = mlt.name in pipeline_names
            else:
                is_pipeline = False
            if is_pipeline and rel.parts and rel.parts[0] == 'scenes':
                skipped_scenes += 1
                continue

            if not path.exists():
                missing.append((mlt.name, str(rel)))
            elif not rel.parts or rel.parts[0] not in keep:
                excluded.append((mlt.name, str(rel)))

    print(f'[MLT] Checked {len(mlts)} project files')
    if skipped_scenes:
        print(f'[INFO] Pipeline scene references skipped: {skipped_scenes} (require regeneration)')
    if resolved_stab:
        print(f'[OK] Shotcut .stab references resolved beside MLT: {resolved_stab}')
    for label, rows in (('MISSING', missing), ('EXCLUDED', excluded), ('EXTERNAL', external)):
        if rows:
            print(f'[{label}] {len(rows)} references:')
            for name, target in rows[:30]:
                print(f'  {name} -> {target}')
            if len(rows) > 30:
                print(f'  ... and {len(rows) - 30} more')
    if missing or excluded or external:
        print('[WARN] Use Full archive or repair project dependencies before compact archiving.')
        return 1
    print('[OK] Checked retained media dependencies are satisfied.')
    if skipped_scenes:
        print('[WARN] Original pipeline MLTs require scene regeneration after restore.')
    print('[INFO] Custom filter dependencies and exact pipeline reproducibility are not proven.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
