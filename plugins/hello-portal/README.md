# Hello Portal

Minimal SDK reference / 最小 SDK 参考例。No backend, login or external bundle is required.

```bash
# From the repository root / 在仓库根目录执行
npm ci
npm -w @openan-plugins/hello-portal run dev
# Open http://127.0.0.1:3004
npm -w @openan-plugins/hello-portal run build
```

The example uses MockPortal only in standalone.jsx. In the full Portal, the
shell supplies the same SDK Context; plugin code does not create another provider.
完整 Portal 中默认禁用本示例，避免混入正式导航。在 plugins/plugin-overrides.json
将 hello-portal.enabled 改为 true 后，可通过 /hello 访问。

Copy this folder under plugins/ to begin another source plugin. Rename its
package name, manifest id, menu id and route together; run npm install to refresh
the workspace lock. Add i18n/API only as needed; declare backend.gateway and
backend.authScope explicitly when introducing a service (component by default,
host only when sharing the Portal session). Never copy real credentials.
