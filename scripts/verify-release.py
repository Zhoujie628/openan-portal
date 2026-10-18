#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify a static release inventory locally and, optionally, over HTTP."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import quote
from urllib.request import urlopen


def public_path(value):
    if not isinstance(value, str) or not value or '\\' in value:
        raise ValueError('Invalid inventory path')
    parts = value.split('/')
    if any(not re.fullmatch(r'[A-Za-z0-9_-][A-Za-z0-9_.-]*', part) for part in parts):
        raise ValueError(f'Unsafe inventory path: {value}')
    return PurePosixPath(*parts)


def read_inventory(root):
    records = json.loads((root / 'plugins.release.json').read_text(encoding='utf-8'))
    enabled = (root / 'plugins.enabled').read_text(encoding='utf-8').splitlines()
    enabled = [item for item in enabled if item]
    if not isinstance(records, list) or any(not isinstance(item, dict) for item in records):
        raise ValueError('Invalid release inventory')
    ids = [item.get('id') for item in records]
    if (any(not isinstance(item, str) or not re.fullmatch(r'[a-z0-9-]+', item) for item in ids)
            or len(ids) != len(set(ids)) or enabled != ids):
        raise ValueError('Enabled list does not match release inventory')
    assets = []
    for record in records:
        hashes = record.get('sha256')
        if not isinstance(hashes, dict) or 'plugin.manifest.json' not in hashes:
            raise ValueError(f"Missing asset hashes: {record['id']}")
        directory = root / 'plugins' / record['id']
        for name, digest in hashes.items():
            relative = public_path(name)
            if not isinstance(digest, str) or not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise ValueError(f'Invalid SHA-256: {name}')
            target = directory
            for part in relative.parts:
                target = target / part
                if target.is_symlink():
                    raise ValueError(f'Symlink in release: {target}')
            if directory.is_symlink() or (root / 'plugins').is_symlink():
                raise ValueError('Symlink in plugin directory')
            if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                raise ValueError(f'Asset SHA-256 mismatch: {record["id"]}/{name}')
            assets.append((f"plugins/{record['id']}/{relative.as_posix()}", digest))
        manifest = json.loads((directory / 'plugin.manifest.json').read_text(encoding='utf-8'))
        if manifest.get('id') != record['id'] or manifest.get('version') != record.get('version'):
            raise ValueError('Manifest identity/version does not match inventory')
        for name in [manifest.get('entry', 'index.js'), manifest.get('css')]:
            if name is not None and name not in hashes:
                raise ValueError(f'Manifest asset missing from inventory: {name}')
    return assets


def verify(root, base_url=None):
    assets = read_inventory(root)
    if base_url:
        for relative, digest in assets:
            with urlopen(base_url.rstrip('/') + '/' + quote(relative, safe='/'), timeout=15) as response:
                content = response.read()
                mime = response.headers.get_content_type()
                if response.status != 200 or hashlib.sha256(content).hexdigest() != digest:
                    raise ValueError(f'HTTP asset missing or changed: {relative}')
                extension = PurePosixPath(relative).suffix
                allowed = {'.js': {'text/javascript', 'application/javascript', 'application/ecmascript', 'text/ecmascript'},
                           '.mjs': {'text/javascript', 'application/javascript'}, '.css': {'text/css'}, '.json': {'application/json'}}
                if extension in allowed and mime not in allowed[extension]:
                    raise ValueError(f'Wrong Content-Type {mime}: {relative}')
    return len(assets)


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('web_root', type=Path)
    parser.add_argument('--url', help='Probe the same release over HTTP(S) after local validation')
    args = parser.parse_args()
    try:
        count = verify(args.web_root.resolve(), args.url)
        print(f'Verified {count} release assets' + (' locally and over HTTP' if args.url else ' locally'))
    except (ValueError, OSError, TypeError, KeyError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
