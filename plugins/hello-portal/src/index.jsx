// SPDX-License-Identifier: Apache-2.0
import { usePortalContext } from '@openan/portal-sdk';

export default function HelloPortal() {
    const { auth, theme, i18n } = usePortalContext();
    return <section style={{ height: '100%', overflow: 'auto', padding: 24, boxSizing: 'border-box', background: theme.isDark ? '#182234' : '#fff', color: theme.isDark ? '#fff' : '#182234' }}>
        <h1>Hello Portal</h1>
        <p>User: {auth.user || 'Guest'} · Role: {auth.role || 'none'} · Language: {i18n.language}</p>
        <button onClick={theme.toggle}>Toggle theme</button>
        <p>This local example makes no business requests and needs no backend.</p>
    </section>;
}
