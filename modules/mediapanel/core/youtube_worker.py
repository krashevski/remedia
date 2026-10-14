#!/usr/bin/env python3
"""Process MediaPanel delivery queue one job at a time, without a daemon."""
import argparse
import fcntl
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from upload_video import atomic_json, upload


def utcnow():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def save(path, data):
    data['updated_at'] = utcnow()
    atomic_json(path, data)


def process(job_file, config_dir):
    with open(job_file, encoding='utf-8') as f:
        job = json.load(f)
    if job.get('action') != 'youtube_upload' or not isinstance(job.get('items'), list):
        raise ValueError(f'Not a YouTube queue job: {job_file}')
    if job.get('status') == 'completed':
        return True
    if job.get('status') in ('uploading', 'needs_review'):
        print(f'REVIEW REQUIRED: {job_file} (previous upload may have succeeded)', file=sys.stderr)
        return False
    for item in job['items']:
        if item.get('status') == 'uploaded' and item.get('video_id'):
            continue
        if item.get('status') in ('uploading', 'needs_review'):
            job['status'] = 'needs_review'
            save(job_file, job)
            return False
        media = Path(item['media_file'])
        metadata_path = Path(item['metadata_file'])
        if not media.is_file() or not metadata_path.is_file():
            item['status'] = 'failed'
            item['error'] = 'Media or metadata missing'
            job['status'] = 'failed'
            save(job_file, job)
            return False
        # --------------------------------------------------
        # DUPLICATE PROTECTION: CHECK SIDECAR METADATA
        # --------------------------------------------------
        try:
            with open(metadata_path, encoding='utf-8') as stream:
                metadata = json.load(stream)

            if not isinstance(metadata, dict):
                raise ValueError("Invalid metadata structure")

        except (OSError, ValueError) as exc:
            item['status'] = 'needs_review'
            item['error'] = f'Cannot read metadata: {exc}'
            job['status'] = 'needs_review'
            save(job_file, job)
            return False

        metadata_status = metadata.get('status')
        existing_video_id = metadata.get('video_id')

        # Already published: restore the result to this job.
        if metadata_status == 'uploaded' and existing_video_id:
            item['status'] = 'uploaded'
            item['video_id'] = existing_video_id
            item['youtube_url'] = metadata.get(
                'youtube_url'
            ) or f'https://youtu.be/{existing_video_id}'

            if metadata.get('uploaded_at'):
                item['uploaded_at'] = metadata['uploaded_at']

            item.pop('error', None)

            save(job_file, job)

            print(
                f'Already uploaded: {media.name} '
                f'→ {item["youtube_url"]}',
                flush=True
            )
            continue

        # An uncertain sidecar must never trigger another upload.
        if metadata_status in ('uploading', 'needs_review', 'failed'):
            item['status'] = 'needs_review'
            item['error'] = (
                f'Sidecar requires review: {metadata_status}'
            )
            job['status'] = 'needs_review'
            save(job_file, job)
            return False

        # Inconsistent publication records require investigation.
        if existing_video_id or metadata_status == 'uploaded':
            item['status'] = 'needs_review'
            item['error'] = 'Inconsistent YouTube publication metadata'
            job['status'] = 'needs_review'
            save(job_file, job)
            return False

        item['status'] = 'uploading'
        job['status'] = 'uploading'
        save(job_file, job)
        try:
            video_id = upload(media, metadata_path, config_dir)
        except Exception as exc:
            item['status'] = 'needs_review'
            item['error'] = str(exc)
            job['status'] = 'needs_review'
            save(job_file, job)
            print(f'Upload outcome must be checked in YouTube Studio: {exc}', file=sys.stderr)
            return False
        # Persist API success in the queue before touching sidecar metadata.
        item['video_id'] = video_id
        item['youtube_url'] = f'https://youtu.be/{video_id}'
        item['status'] = 'uploaded'
        item['uploaded_at'] = utcnow()
        item.pop('error', None)
        job['status'] = 'queued'
        save(job_file, job)
        # Update the sidecar as a secondary operation; never re-upload on failure.
        try:
            with open(metadata_path, encoding='utf-8') as stream:
                metadata = json.load(stream)
            metadata.update({'backend': 'youtube_api', 'status': 'uploaded',
                             'video_id': video_id, 'youtube_url': item['youtube_url'],
                             'updated_at': utcnow()})
            atomic_json(metadata_path, metadata)
        except Exception as exc:
            print(f'WARNING: YouTube upload succeeded, but sidecar update failed: {exc}', file=sys.stderr)
        print(f'Uploaded: {media.name} → {item["youtube_url"]}', flush=True)
    job['status'] = 'completed'
    save(job_file, job)
    return True

def main():
    p = argparse.ArgumentParser()
    p.add_argument(
        '--state-dir',
        default=str(
            Path(os.environ.get('REMEDIA_VAR', Path.home() / '.remedia'))
            / 'mediapanel'
        ),
    )
    p.add_argument('--config-dir', default=str(Path.home() / '.config/remedia/youtube'))
    p.add_argument('--job', help='Process one named job JSON; default: all queued jobs')
    args = p.parse_args()
    queue_dir = Path(args.state_dir).expanduser() / 'delivery/queue'
    queue_dir.mkdir(parents=True, exist_ok=True)
    lock_path = queue_dir / '.worker.lock'
    with open(lock_path, 'a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Another delivery worker is running', file=sys.stderr)
            return 1
        jobs = [Path(args.job)] if args.job else sorted(queue_dir.glob('*.json'))
        overall_ok = True
        for job_file in jobs:
            try:
                with open(job_file, encoding='utf-8') as f:
                    status = json.load(f).get('status')
                if status == 'completed':
                    continue
                if status not in ('queued', 'failed'):
                    print(f'Skipping {job_file.name}: status {status}')
                    continue
                print(f'Processing {job_file.name}', flush=True)
                if not process(job_file, args.config_dir):
                    overall_ok = False
            except Exception as exc:
                overall_ok = False
                print(f'Job error {job_file}: {exc}', file=sys.stderr)
        return 0 if overall_ok else 1


if __name__ == '__main__':
    sys.exit(main())
