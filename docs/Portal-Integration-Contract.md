# Portal 集成与验证契约

## API 与执行流

- 编排网关为 `/api/orchestrate`，注册网关为 `/api/registry-center`；`/api/registry` 仅作历史兼容，旧 `/rest/v1/registry` 会映射到 `/rest/v1/registry-center`。
- 插件声明 `backend.gateway` 后，REST 使用注入的 `api`，原生 EventSource 使用 `api.getUri({url: '/rest/v1/...'})` 构造地址。客户端兼容已经包含同一 gateway 的 URL，不会重复拼接。
- 未声明 gateway 的旧插件仍使用无 baseURL 的宿主客户端，由插件自己的服务层构造完整 URL。旧编排插件依赖的全局值只保留为只读 Portal 模式标记，不含任何用户、认证或 API 对象。
- dev、preview、容器 Nginx、独立 Nginx 保持相同接口路径。直接 `/rest/v1/orchestrate/`、`/rest/v1/registry-center/` 为兼容入口。
- 单次执行的 complete/close/cancelled/error/dispatch_error/dispatch_result 会结束流；畸形帧或连接异常也关闭流并提示。禁止自动重连触发式 GET，以免重复执行。这不改变底层 SDK 任务无关通知订阅的长连接规则。

## 插件与认证

- 源码/独立 UMD 都使用同一份宿主 React 和 `@openan/portal-sdk`；独立包必须 externalize React、ReactDOM、ReactI18next、OpenANPortalSDK。SDK 不再通过可变全局变量寻找上下文，以免拿到其他插件的 API。
- 仅支持 manifest 声明式 menu/routes。旧文档中未实现的 onInit/onActivate/onDeactivate 已移除；携带这些字段的插件会显式校验失败。用组件 useEffect 管理挂载、订阅和卸载清理；没有 registerMenu/registerRoute 空实现。
- 单个插件的 manifest、语言资源或运行时错误不应影响其他插件；错误在页面可见。全部禁用后仍能打开管理器恢复。
- 认证保留后端 role；must_change_password 状态不挂载业务页面。完成改密后因后端撤销会话，必须重新登录；普通权限不足的 403 不等同于登录失效。

## 本地交付

`portal/bundled-plugins.json` 是 bundle 启用清单。修改本体启用状态或远程 entry 不再编辑另一份 JS 列表。默认本地制品来自两个组件独立的 `npm run build:plugin`：

```bash
npm ci
npm run plugins:install -- registry-center=../registry-center/registry-center-web/dist-plugin orchestration-center=../orchestration-center/workflow-designer/dist-plugin
npm run lint
npm test
npm run build:release
```

`plugins:install` 校验 manifest 身份和资产再复制；`build:release` 对已启用的本地制品作强校验，生成版本/哈希清单。源码、构建制品和业务数据分离，制品继续被 gitignore 排除，不向本仓复制其他组件源码。容器构建同样执行发布校验，需提前安装制品。远程运行时模式仍支持，但离线发布命令拒绝替未经检查的远程产物背书。

部署脚本须携带 deploy-common.sh；目录和端口先校验，Nginx root 按实际 WEB_ROOT 渲染，自检只访问发布清单中的启用插件。完整端到端联调仍需真实后端、正确 TLS/身份配置，不由单元测试替代。
