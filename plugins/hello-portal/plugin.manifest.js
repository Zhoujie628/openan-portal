// SPDX-License-Identifier: Apache-2.0
export default {
    id: 'hello-portal', name: 'Hello Portal', version: '0.1.0',
    menu: [{ id: 'hello-portal', labelKey: 'Hello Portal', route: '/hello', order: 100 }],
    routes: [{ path: '/hello', menuId: 'hello-portal', component: () => import('./src/index.jsx') }],
};
