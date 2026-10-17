// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const workspace = fileURLToPath(new URL('../', import.meta.url));
const safeFile = value => typeof value === 'string' && /^[A-Za-z0-9_.-]+$/.test(value) && value !== '..';

export async function inspectArtifact(directory, id) {
    const manifest = JSON.parse(await fs.readFile(path.join(directory, 'plugin.manifest.json'), 'utf8'));
    if (manifest.id !== id || !manifest.name || !manifest.version || !manifest.routes?.length ||
        manifest.routes.some(route => typeof route.path !== 'string' || !route.path.startsWith('/'))) {
        throw new Error(`${id}: invalid plugin manifest`);
    }
    const files = [manifest.entry || 'index.js', ...(manifest.css ? [manifest.css] : [])];
    if (files.some(file => !safeFile(file))) throw new Error(`${id}: unsafe artifact filename`);
    const sha256 = {};
    for (const file of ['plugin.manifest.json', ...files]) {
        const bytes = await fs.readFile(path.join(directory, file));
        if (!bytes.length) throw new Error(`${id}: empty ${file}`);
        if (file.endsWith('.js') && !bytes.toString().includes(`__OPENAN_PLUGIN__${id.replaceAll('-', '_')}`)) {
            throw new Error(`${id}: missing UMD global`);
        }
        sha256[file] = createHash('sha256').update(bytes).digest('hex');
    }
    return { manifest, files, sha256 };
}

export async function validateArtifacts(root = workspace) {
    const registry = JSON.parse(await fs.readFile(path.join(root, 'portal/bundled-plugins.json'), 'utf8'));
    const records = [];
    for (const plugin of registry.filter(plugin => plugin.enabled !== false)) {
        if (!/^[a-z0-9-]+$/.test(plugin.id) || plugin.entry !== `/plugins/${plugin.id}`) {
            throw new Error(`${plugin.id}: release validation requires local /plugins/<id> artifacts; remote delivery must be verified separately`);
        }
        const { manifest, sha256 } = await inspectArtifact(path.join(root, 'portal/public', plugin.entry), plugin.id);
        records.push({ id: plugin.id, version: manifest.version, sha256 });
    }
    return records;
}

async function main() {
    if (process.argv[2] === 'install') {
        const args = process.argv.slice(3);
        if (!args.length) throw new Error('Usage: npm run plugins:install -- <plugin-id>=<dist-plugin-directory> [...]');
        for (const arg of args) {
            const index = arg.indexOf('=');
            if (index < 1) throw new Error('Expected plugin-id=directory');
            const id = arg.slice(0, index);
            if (!/^[a-z0-9-]+$/.test(id)) throw new Error('Invalid plugin id');
            const directory = path.resolve(arg.slice(index + 1));
            const { files } = await inspectArtifact(directory, id);
            const destination = path.join(workspace, 'portal/public/plugins', id);
            if (directory === destination) continue;
            await fs.mkdir(destination, { recursive: true });
            for (const file of ['plugin.manifest.json', ...files]) {
                await fs.copyFile(path.join(directory, file), path.join(destination, file));
            }
            console.log(`Installed ${id}`);
        }
    } else {
        const records = await validateArtifacts();
        await fs.mkdir(path.join(workspace, 'portal/public'), { recursive: true });
        await fs.writeFile(path.join(workspace, 'portal/public/plugins.release.json'), JSON.stringify(records, null, 2) + '\n');
        await fs.writeFile(path.join(workspace, 'portal/public/plugins.enabled'), records.map(record => record.id).join('\n') + '\n');
        console.log(`Validated ${records.length} plugin artifacts`);
    }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
