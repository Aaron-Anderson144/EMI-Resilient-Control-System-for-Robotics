"""Restore only hash-pinned local inputs into this checkout; no network access."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import shutil


def checked_path(root, relative):
    part = PurePosixPath(relative)
    if part.is_absolute() or '..' in part.parts or ':' in relative or '\\' in relative:
        raise ValueError(f'Unsafe manifest path: {relative}')
    target = root.joinpath(*part.parts).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError(f'Path escapes selected root: {relative}')
    return target


def matches(path, row):
    return path.is_file() and path.stat().st_size == row['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest() == row['sha256']


def restore(checkout, evidence_root, manifest, groups=None, dry_run=False):
    selected = [r for r in manifest['files'] if not groups or r['group'] in groups]
    if not selected:
        raise ValueError('No dependency files selected.')
    planned = []
    # Validate the whole selection before making directories or copying bytes.
    for row in selected:
        source = checked_path(evidence_root, row['path'])
        target = checked_path(checkout, row['path'])
        if not matches(source, row):
            raise ValueError(f'Missing or changed retained input: {source}')
        if target.exists() and not matches(target, row):
            raise ValueError(f'Existing destination differs; refusing overwrite: {target}')
        planned.append((source, target, row, target.exists()))
    copied = 0
    if not dry_run:
        for source, target, row, exists in planned:
            if exists:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            # Exclusive destination creation also prevents a race from
            # replacing a file created after the preflight check.
            with source.open('rb') as src, target.open('xb') as dst:
                shutil.copyfileobj(src, dst)
            if not matches(target, row):
                raise ValueError(f'Post-copy identity mismatch: {target}')
            copied += 1
    return {'passed': True, 'dry_run': dry_run, 'selected_files': len(planned), 'already_matching': sum(p[3] for p in planned), 'copied': copied, 'checkout': str(checkout), 'evidence_root': str(evidence_root)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', type=Path, required=True, help='Retained project folder containing the pinned results/tools.')
    parser.add_argument('--group', action='append', choices=['regression_inputs', 'motion_history', 'circuit_runtimes', 'experiment_source'])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    checkout = Path(__file__).resolve().parents[2]
    manifest = json.loads((checkout / '00_Project_Management/Local_Dependencies.json').read_text(encoding='utf-8'))
    print(json.dumps(restore(checkout, args.evidence_root.resolve(), manifest, args.group, args.dry_run), indent=2))


if __name__ == '__main__':
    main()
