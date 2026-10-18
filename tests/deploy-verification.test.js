// @vitest-environment node
// SPDX-License-Identifier: Apache-2.0
import { afterAll, afterEach, beforeAll, beforeEach, expect, test } from 'vitest';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { createHash } from 'node:crypto';
import { execFileSync, spawn, spawnSync } from 'node:child_process';

const python = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
const script = path.resolve('scripts/verify-release.py');
let root, server, base, mode;
const hashes = {};
beforeAll(async () => {
    server = http.createServer(async (request, response) => {
        try {
            const relative = decodeURIComponent(new URL(request.url, 'http://localhost').pathname).slice(1);
            if (!relative.startsWith('plugins/healthy/')) throw new Error('Unknown path');
            if (mode === 'missing' && relative.endsWith('index.js')) { response.writeHead(404); response.end(); return; }
            const bytes = await fs.readFile(path.join(root, relative));
            const mime = { '.js': 'application/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml' }[path.extname(relative)];
            response.writeHead(200, { 'Content-Type': mode === 'mime' ? 'text/html' : mime });
            response.end(mode === 'html' ? '<html>SPA fallback</html>' : bytes);
        } catch { response.writeHead(404); response.end(); }
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); base = `http://127.0.0.1:${server.address().port}`;
});
afterAll(async () => { await new Promise(resolve => server.close(resolve)); });
beforeEach(async () => {
    mode = 'ok'; root = await fs.mkdtemp(path.join(os.tmpdir(), 'portal-release-check-'));
    const files = { 'plugin.manifest.json': JSON.stringify({ id: 'healthy', version: '1', entry: 'index.js', css: 'index.css' }),
        'index.js': 'window.healthy=function(){};', 'index.css': '.healthy{}', 'cards.json': '{"cards":[]}', 'images/test.svg': '<svg/>' };
    for (const key of Object.keys(hashes)) delete hashes[key];
    for (const [file, bytes] of Object.entries(files)) {
        const target = path.join(root, 'plugins/healthy', file); await fs.mkdir(path.dirname(target), { recursive: true }); await fs.writeFile(target, bytes);
        hashes[file] = createHash('sha256').update(bytes).digest('hex');
    }
    await fs.writeFile(path.join(root, 'plugins.enabled'), 'healthy\n');
    await fs.writeFile(path.join(root, 'plugins.release.json'), JSON.stringify([{ id: 'healthy', version: '1', sha256: hashes }]));
});
afterEach(async () => {
    expect(path.dirname(root)).toBe(os.tmpdir()); expect(path.basename(root)).toMatch(/^portal-release-check-/);
    await fs.rm(root, { recursive: true, force: true });
});
const local = () => spawnSync(python, [script, root], { encoding: 'utf8' });
const remote = () => new Promise((resolve, reject) => {
    const child = spawn(python, [script, root, '--url', base]); let output = '';
    child.stdout.on('data', bytes => { output += bytes; }); child.stderr.on('data', bytes => { output += bytes; });
    child.on('error', reject); child.on('close', status => resolve({ status, output }));
});
test('checks every inventory asset locally and through a real HTTP server', async () => {
    expect(local().status).toBe(0); const result = await remote(); expect(result.status, result.output).toBe(0); expect(result.output).toContain('5 release assets');
});
test.each(['index.js', 'index.css', 'cards.json', 'images/test.svg'])('missing %s fails pre-reload validation', async file => {
    await fs.unlink(path.join(root, 'plugins/healthy', file)); expect(local().status).not.toBe(0);
});
test('local content tampering and inconsistent inventory fail', async () => {
    await fs.writeFile(path.join(root, 'plugins/healthy/index.js'), 'changed'); expect(local().status).not.toBe(0);
    await fs.writeFile(path.join(root, 'plugins.enabled'), 'other\n'); expect(local().status).not.toBe(0);
});
test.each(['missing', 'html', 'mime'])('HTTP %s cannot masquerade as a successful deployment', async failure => {
    mode = failure; const result = await remote(); expect(result.status, result.output).not.toBe(0);
});
test('unsafe inventory path is rejected', async () => {
    hashes['../outside.js'] = 'a'.repeat(64);
    await fs.writeFile(path.join(root, 'plugins.release.json'), JSON.stringify([{ id: 'healthy', version: '1', sha256: hashes }]));
    expect(local().status).not.toBe(0);
});
test('both deploy entrypoints check local assets before nginx reload', async () => {
    for (const file of ['deploy-en.sh', 'deploy-zh.sh']) {
        const text = await fs.readFile(path.join('scripts', file), 'utf8');
        expect(text.indexOf('verify_release_files')).toBeGreaterThan(text.indexOf('tar -xzf'));
        expect(text.indexOf('verify_release_files')).toBeLessThan(text.indexOf('\nnginx -t'));
    }
});
test('shared shell entrypoint runs the verifier and propagates asset failures', async () => {
    const bash = process.platform === 'win32'
        ? path.resolve(execFileSync('git', ['--exec-path'], { encoding: 'utf8' }).trim(), '../../../bin/bash.exe') : 'bash';
    const binary = execFileSync(python, ['-c', 'import sys; print(sys.executable)'], { encoding: 'utf8' }).trim().replaceAll('\\', '/');
    const run = () => spawnSync(bash, ['-c', 'source scripts/deploy-common.sh; WEB_ROOT="$1"; PYTHON_BIN="$2"; verify_release_files', 'probe', root.replaceAll('\\', '/'), binary], { encoding: 'utf8' });
    const good = run(); expect(good.status, good.stderr).toBe(0); expect(good.stdout).toContain('5 release assets');
    await fs.unlink(path.join(root, 'plugins/healthy/index.js'));
    expect(run().status).not.toBe(0);
});
