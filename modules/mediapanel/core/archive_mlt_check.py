#!/usr/bin/env python3
"""Read-only compact archive preflight for Shotcut MLT dependencies."""
from remedia_i18n import t, value_error, runtime_error, exception_text, ArgumentParser
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    if len(sys.argv) < 3:
        print(t('MP_PY_USAGE_ARCHIVE_MLT_CHECK_PY_PROJECT_DIR_KEEP_DIR_KEEP_DIR'), file=sys.stderr)
        return 2

    project = Path(sys.argv[1]).resolve()
    if not project.is_dir():
        print(t('MP_PY_ERROR_PROJECT_DIRECTORY_DOES_NOT_EXIST', project), file=sys.stderr)
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
            missing.append((str(mlt.relative_to(project)), t('MP_PY_INVALID_UNREADABLE_MLT_XML', str(exc))))
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

    print(t('MP_PY_MLT_CHECKED_PROJECT_FILES', len(mlts)))
    if skipped_scenes:
        print(t('MP_PY_INFO_PIPELINE_SCENE_REFERENCES_SKIPPED_REQUIRE_REGENERATION', skipped_scenes))
    if resolved_stab:
        print(t('MP_PY_OK_SHOTCUT_STAB_REFERENCES_RESOLVED_BESIDE_MLT', resolved_stab))
    for label, rows in (('MISSING', missing), ('EXCLUDED', excluded), ('EXTERNAL', external)):
        if rows:
            print(t('MP_PY_REFERENCES', label, len(rows)))
            for name, target in rows[:30]:
                print(t('MP_PY_MESSAGE', name, target))
            if len(rows) > 30:
                print(t('MP_PY_AND_MORE', len(rows) - 30))
    if missing or excluded or external:
        print(t('MP_PY_WARN_USE_FULL_ARCHIVE_OR_REPAIR_PROJECT_DEPENDENCIES_BEFORE_COMPA'))
        return 1
    print(t('MP_PY_OK_CHECKED_RETAINED_MEDIA_DEPENDENCIES_ARE_SATISFIED'))
    if skipped_scenes:
        print(t('MP_PY_WARN_ORIGINAL_PIPELINE_MLTS_REQUIRE_SCENE_REGENERATION_AFTER_REST'))
    print(t('MP_PY_INFO_CUSTOM_FILTER_DEPENDENCIES_AND_EXACT_PIPELINE_REPRODUCIBILIT'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
