# OpenAN Portal Standalone Deployment Package

> Chinese documentation: [README-DEPLOY.md](./README-DEPLOY.md) / 中文版部署文档见同目录

This package contains the **production build artifacts** of OpenAN Portal (the pluggable unified portal) and one-click deployment scripts, ready to deploy standalone on any fresh server.

- Build source: the `openan-portal` repository, `main` branch
- Verified on production (Ubuntu 24.04 / nginx 1.24)

## Package Contents

| File | Description |
|---|---|
| `openan-portal-dist.tar.gz` | Portal production build (index.html + assets/ + plugins/) |
| `deploy-zh.sh` | One-click deploy script (Chinese output): copy-backup → overlay extract → install nginx config → self-check |
| `deploy-en.sh` | One-click deploy script (English output) |
| `openan-portal.nginx.conf` | nginx config template (ports parametrizable) |
| `README-DEPLOY-EN.md` | This document |

## Prerequisites (target server)

1. **nginx** (`apt install nginx` or `yum install nginx`)
2. **Backend services** (Portal is a pure frontend + gateway; business data comes from the backends below — deploy as needed):

| Gateway path | Upstream | Description |
|---|---|---|
| `/api/orchestrate/`, `/rest/v1/orchestrate/` | `127.0.0.1:5001` | Orchestration Center FastAPI |
| `/api/registry-center/`, `/api/registry/` | `127.0.0.1:5000` | Registry Center FastAPI |

> Without backends the Portal still opens; the corresponding plugin panels just show empty data / errors. Deploying the Orchestration backend (5001) alone enables "Orchestration Center + Execution Center".

3. **Firewall / security group**: open the Portal port (default 9003).

## Deployment Steps (target server)

```bash
# 1. Upload the whole directory to the target server, e.g. /tmp/openan-portal-release/
scp -r portal-release/ user@<server>:/tmp/openan-portal-release/

# 2. Run on the target server (deploys to /OpenA2A-T/openan-portal-frontend, ports 9003+3003 by default)
sudo bash /tmp/openan-portal-release/deploy-en.sh    # English output
sudo bash /tmp/openan-portal-release/deploy-zh.sh    # 中文提示

# Custom path and ports (both scripts take identical arguments):
sudo bash deploy-en.sh /data/openan-portal-frontend 8080 8081
```

The script automatically: copies a backup of the old directory (keeping old chunks so open browser sessions transition smoothly) → **overlay**-extracts the new build → generates the nginx config → validates with `nginx -t` → reloads → self-checks page / main bundle / plugin manifests.

## Post-deployment Verification

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9003/                      # expect 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9003/plugins/registry-center/plugin.manifest.json   # expect 200
curl -s http://127.0.0.1:9003/api/orchestrate/rest/v1/orchestrate/workflows          # expect JSON (needs the Orchestration backend)
```

Open `http://<server-ip>:9003/` in a browser — the left menu should show: Registry Center / Orchestration Center / Execution Center (Execution Center and Skill Center are built-in plugins shipped with the main bundle).

## Rollback

```bash
rm -rf /OpenA2A-T/openan-portal-frontend && cp -a /OpenA2A-T/openan-portal-frontend.bak-<timestamp> /OpenA2A-T/openan-portal-frontend && nginx -s reload
```

> Deployment is **overlay mode**: old hash-named chunks stay in the web root so browser sessions opened before the deploy transition smoothly; stale files accumulate over time and can be cleaned periodically (the script prints the cleanup command when it finishes).

## Rebuild from Source (optional)

```bash
git clone <openan-portal repository> && cd openan-portal
npm install
npm run build          # artifacts in portal/dist/
# Plugin UMD bundles live in portal/public/plugins/ and are copied into dist/plugins/ at build time
```

> Note: JS artifacts use content-hash file names; hashes may differ between build environments (dependency drift) while functionality stays the same. `npm run build` succeeding + the page self-check passing is the acceptance criteria.
