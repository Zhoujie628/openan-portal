# OpenAN Portal 独立部署包

本包内含 OpenAN Portal（插件化统一门户）的**生产构建产物**与一键部署脚本，可在任意新服务器上独立部署。

- 构建来源：`openan-portal` 仓库 `feature/portal-bundle-plugins` 分支（与 [PR #13](https://github.com/project-openan/openan-portal/pull/13) 一致，本体插件默认禁用）
- 与线上 `47.236.98.226:9003` 部署版本同源

## 包内容

| 文件 | 说明 |
|---|---|
| `openan-portal-dist.tar.gz` | Portal 生产构建产物（index.html + assets/ + plugins/） |
| `deploy-zh.sh` | 一键部署脚本（中文提示）：复制备份 → 叠加解压 → 装 nginx 配置 → 自检 |
| `deploy-en.sh` | One-click deploy script (English output) |
| `openan-portal.nginx.conf` | nginx 配置模板（端口可参数化） |
| `README-DEPLOY.md` | 本文档 |

## 前置条件（目标服务器）

1. **nginx**（`apt install nginx` 或 `yum install nginx`）
2. **后端服务**（Portal 是纯前端 + 网关，业务数据来自以下后端，按需部署）：

| 网关路径 | 上游 | 说明 |
|---|---|---|
| `/api/orchestrate/`、`/rest/v1/orchestrate/` | `127.0.0.1:5001` | 编排中心 FastAPI（`python -m orchestrate.start`） |
| `/api/registry-center/`、`/api/registry/` | `127.0.0.1:5000` | 注册中心 FastAPI |
| `/api/ontology/` | `127.0.0.1:8787` | 本体演示 node 服务（docker） |

> 后端未部署时 Portal 仍可打开，只是对应插件的列表数据为空/报错；至少部署编排中心（5001）即可使用「编排中心 + 执行中心」。

3. **防火墙/安全组**：放行 Portal 端口（默认 9003）。

## 部署步骤（目标服务器）

```bash
# 1. 上传整个目录到目标服务器，例如 /tmp/openan-portal-release/
scp -r portal-release/ user@<server>:/tmp/openan-portal-release/

# 2. 在目标服务器上执行（默认部署到 /OpenA2A-T/openan-portal-frontend，端口 9003+3003）
sudo bash /tmp/openan-portal-release/deploy-zh.sh    # 中文提示
sudo bash /tmp/openan-portal-release/deploy-en.sh    # English output

# 自定义路径与端口（两个脚本参数相同）：
sudo bash deploy-zh.sh /data/openan-portal-frontend 8080 8081
```

脚本会自动：复制备份旧目录（保留旧 chunk，平滑过渡旧会话）→ **叠加**解压新版 → 生成 nginx 配置 → `nginx -t` 校验 → reload → 自检页面/主包/插件清单。

## 部署后验证

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9003/                      # 期望 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9003/plugins/registry-center/plugin.manifest.json   # 期望 200
curl -s http://127.0.0.1:9003/api/orchestrate/rest/v1/orchestrate/workflows          # 期望 JSON（需编排中心后端）
```

浏览器访问 `http://<服务器IP>:9003/`，左侧菜单应出现：注册中心 / 编排中心 / 执行中心 / 本体中心（执行中心与技能中心为内置插件，随主包加载）。

## 回滚

```bash
rm -rf /OpenA2A-T/openan-portal-frontend && cp -a /OpenA2A-T/openan-portal-frontend.bak-<时间戳> /OpenA2A-T/openan-portal-frontend && nginx -s reload
```

> 部署为**叠加式**：旧 hash 命名的 chunk 会保留在 web root，部署前打开的浏览器会话可平滑过渡；历史文件会累积，可定期清理（脚本结束时打印清理命令）。

## 从源码重新构建（可选）

```bash
git clone <openan-portal 仓库> && cd openan-portal
npm install
npm run build          # 产物在 portal/dist/
# 插件 UMD 包位于 portal/public/plugins/，构建时自动复制进 dist/plugins/
```

> 注意：JS 产物为内容哈希命名，不同环境构建出的哈希文件名可能不同（依赖版本漂移所致），但功能一致；以 `npm run build` 成功 + 页面自检通过为准。
