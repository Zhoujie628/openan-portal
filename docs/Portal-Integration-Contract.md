# Portal 集成与验证契约

## API 与执行流

- 编排网关为 `/api/orchestrate`，注册网关为 `/api/registry-center`；`/api/registry` 仅作历史兼容，旧 `/rest/v1/registry` 会映射到 `/rest/v1/registry-center`。
- 插件声明 `backend.gateway` 后，REST 使用注入的 `api`，原生 EventSource 使用 `api.getUri({url: '/rest/v1/...'})` 构造地址。客户端兼容已经包含同一 gateway 的 URL，不会重复拼接。
- 未声明 gateway 的旧插件仍使用无 baseURL 的宿主客户端，由插件自己的服务层构造完整 URL。旧组件兼容桥为冻结的 `{mode: 'portal', i18n}`，只暴露宿主共用语言实例，不含任何用户、认证、路由或插件专属 API 对象；新插件仍使用 SDK Context。
- dev、preview、容器 Nginx、独立 Nginx 保持相同接口路径。直接 `/rest/v1/orchestrate/`、`/rest/v1/registry-center/` 为兼容入口。
- 单次执行的 complete/close/cancelled/error/dispatch_error/dispatch_result 会结束流；畸形帧或连接异常也关闭流并提示。禁止自动重连触发式 GET，以免重复执行。这不改变底层 SDK 任务无关通知订阅的长连接规则。

## 插件与认证

- 源码/独立 UMD 都使用同一份宿主 React 和 `@openan/portal-sdk`；独立包必须 externalize React、ReactDOM、ReactI18next、OpenANPortalSDK。SDK 不再通过可变全局变量寻找上下文，以免拿到其他插件的 API。
- 仅支持 manifest 声明式 menu/routes。旧文档中未实现的 onInit/onActivate/onDeactivate 已移除；携带这些字段的插件会显式校验失败。用组件 useEffect 管理挂载、订阅和卸载清理；没有 registerMenu/registerRoute 空实现。
- 单个插件的 manifest、语言资源或运行时错误不应影响其他插件；错误在页面可见。全部禁用后仍能打开管理器恢复。
- 认证保留后端 role；must_change_password 状态不挂载业务页面。完成改密后因后端撤销会话，必须重新登录；普通权限不足的 403 不等同于登录失效。

## 本地交付

`portal/bundled-plugins.json` 是唯一 bundle 启用清单。当前默认启用注册中心、编排中心、观测中心、虚拟展厅和 AN 本体五个独立插件，旧 `ontology-demo` 已移除。修改启用状态或远程 entry 不再编辑另一份 JS 列表。

在各插件的来源项目中独立构建后安装制品。下面的观测中心和 AN 本体路径是由组件维护者提供的制品目录，不代表本仓包含它们的源码：

```bash
npm ci
npm run plugins:install -- registry-center=../registry-center/registry-center-web/dist-plugin orchestration-center=../orchestration-center/workflow-designer/dist-plugin
npm run plugins:install -- virtual-showroom=../openan-demo/portal-plugins/virtual-showroom/dist-plugin
npm run plugins:install -- observation-center=/path/to/observation-center/dist-plugin an-ontology=/path/to/an-ontology/dist-plugin
npm run lint
npm test
npm run build:release
```

`plugins:install` 校验 manifest 身份及全部静态资源后复制整个发布目录，包括 `cards.json`、图片和辅助 JS；拒绝隐藏文件、私钥等非发布文件及符号链接。`build:release` 对已启用的本地制品作强校验，生成全部文件的版本/哈希清单；缺少任一启用插件会失败，不会静默关闭它。精简部署应由交付者显式修改 JSON 后重建。

源码、构建制品和业务数据分离，制品继续被 gitignore 排除，不向本仓复制其他组件源码。容器构建同样执行发布校验，需提前安装制品。远程运行时模式仍支持，但离线发布命令拒绝替未经检查的远程产物背书。

部署脚本须携带 deploy-common.sh；目录和端口先校验，Nginx root 按实际 WEB_ROOT 渲染，自检只访问发布清单中的启用插件。完整端到端联调仍需真实后端、正确 TLS/身份配置，不由单元测试替代。

`apply-plugin-registration.sh` 仅作为旧预构建制品的兼容工具，保留补回三类插件及设置 AN 本体 URL 的接口。它支持旧反引号和当前 JSON 风格，幂等且拒绝歧义/未知结构，不依赖 `zu` 等压缩变量名。新源码已经登记五个插件，应重建而非修改 hash 产物；兼容脚本不能替代制品安装和发布校验。
