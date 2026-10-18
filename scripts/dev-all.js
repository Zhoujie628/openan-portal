// Copyright (c) 2026 Huawei Technologies Co., Ltd.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//
//    Licensed under the Apache License, Version 2.0 (the "License"); you may
//    not use this file except in compliance with the License. You may obtain
//    a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//    License for the specific language governing permissions and limitations
//    under the License.

/**
 * dev-all.js — one-click dev startup.
 *
 * Starts the Portal only. Source plugins are compiled by Vite; independent
 * UMD artifacts and backend services must be prepared separately.
 */
import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');

console.log('');
console.log('  ╔══════════════════════════════════════╗');
console.log('  ║   OpenAN Portal — Dev Mode           ║');
console.log('  ╚══════════════════════════════════════╝');
console.log('');
console.log('  Portal:    http://localhost:3003');
console.log('  Backend:   http://127.0.0.1:5001 (external)');
console.log('');

const proc = spawn('npm', ['run', 'dev:portal'], {
    cwd: root,
    stdio: 'inherit',
    shell: true,
});

proc.on('close', (code) => {
    process.exit(code ?? 0);
});
