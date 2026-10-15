#!/usr/bin/env bash
# ============================================================================
# OpenAN Portal 一键部署脚本 / One-click deployment script for OpenAN Portal
#
# 用法 / Usage:
#   sudo bash deploy.sh [--lang zh|en] [WEB_ROOT] [PORT1] [PORT2]
#
#   WEB_ROOT   部署目录 / deployment web root   (默认 / default: /OpenA2A-T/openan-portal-frontend)
#   PORT1/PORT2  nginx 监听端口 / listen ports  (默认 / default: 9003 3003)
#
# 语言切换 / Language:
#   1) --lang zh|en      命令行参数 / command line flag (highest)
#   2) DEPLOY_LANG=zh|en 环境变量 / environment variable
#   3) auto detect       按系统 locale 自动检测 / auto-detect from system locale
# ============================================================================
set -euo pipefail

# ---------------- language selection / 语言选择 ----------------
LANG_CHOICE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --lang|-l)
            [ $# -ge 2 ] || { echo "ERROR: --lang requires zh|en"; exit 1; }
            LANG_CHOICE="$2"; shift 2 ;;
        --lang=*)
            LANG_CHOICE="${1#--lang=}"; shift ;;
        *)
            break ;;
    esac
done
case "$LANG_CHOICE" in
    zh|zh_*|en|en_*) LANG_CHOICE="${LANG_CHOICE%%_*}" ;;
    "") LANG_CHOICE="" ;;
    *) echo "ERROR: unknown language '$LANG_CHOICE' (use zh|en)"; exit 1 ;;
esac
if [ -z "$LANG_CHOICE" ]; then
    case "${DEPLOY_LANG:-}" in
        zh|en) LANG_CHOICE="$DEPLOY_LANG" ;;
    esac
fi
if [ -z "$LANG_CHOICE" ]; then
    case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
        zh*) LANG_CHOICE=zh ;;
        *)   LANG_CHOICE=en ;;
    esac
fi

# t <中文> <English>  — print message in selected language
t() {
    if [ "$LANG_CHOICE" = "zh" ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi
}

# ---------------- parameters / 参数 ----------------
WEB_ROOT="${1:-/OpenA2A-T/openan-portal-frontend}"
PORT1="${2:-9003}"
PORT2="${3:-3003}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARBALL="$SCRIPT_DIR/openan-portal-dist.tar.gz"
NGINX_CONF_SRC="$SCRIPT_DIR/openan-portal.nginx.conf"
NGINX_CONF_DST="/etc/nginx/conf.d/openan-portal.conf"
TS=$(date +%Y%m%d%H%M%S)
BACKUP="${WEB_ROOT}.bak-${TS}"

echo "$(t '语言' 'Language'): $LANG_CHOICE"
echo ""

# ---------------- 1/5 backup / 备份 ----------------
# 备份用 cp 而非 mv：旧 hash 命名的 chunk 需留在 web root，
# 让部署前打开的浏览器会话（SPA 懒加载旧 chunk）平滑过渡。
# The backup COPIES instead of MOVES: old hash-named chunks must stay in the
# web root so browser sessions opened before the deploy (which lazy-load the
# old chunks) keep working.
echo "$(t '== 1/5 备份旧目录 ==' '== 1/5 Backing up existing deployment ==')"
OVERLAY=0
if [ -d "$WEB_ROOT" ]; then
    OVERLAY=1
    cp -a "$WEB_ROOT" "$BACKUP"
    echo "$(t "   旧目录已复制备份至: $BACKUP" "   Existing deployment copied to: $BACKUP")"
else
    echo "$(t '   无旧部署，跳过备份' '   No existing deployment, skip backup')"
fi

# ---------------- 2/5 extract / 解压（叠加式 / overlay） ----------------
if [ ! -f "$TARBALL" ]; then
    echo "$(t "ERROR: 发布包不存在: $TARBALL" "ERROR: release tarball not found: $TARBALL")"
    exit 1
fi
echo "$(t '== 2/5 解压新版本（叠加，保留旧 chunk） ==' '== 2/5 Extracting new release (overlay, old chunks kept) ==')"
mkdir -p "$WEB_ROOT"
tar -xzf "$TARBALL" -C "$WEB_ROOT"
FILE_COUNT=$(find "$WEB_ROOT" -type f | wc -l)
echo "$(t "   已部署到: $WEB_ROOT ($FILE_COUNT 个文件)" "   Deployed to: $WEB_ROOT ($FILE_COUNT files)")"
if [ "$OVERLAY" = "1" ]; then
    echo "$(t "   提示: 历史 chunk 持续累积，可定期清理 30 天前文件:" "   Note: stale chunks accumulate over time; periodically clean files older than 30 days:")"
    echo "        find $WEB_ROOT/assets -type f -mtime +30 -delete"
fi

# ---------------- 3/5 nginx conf / 安装 nginx 配置 ----------------
if [ ! -f "$NGINX_CONF_SRC" ]; then
    echo "$(t "ERROR: nginx 配置模板不存在: $NGINX_CONF_SRC" "ERROR: nginx conf template not found: $NGINX_CONF_SRC")"
    exit 1
fi
echo "$(t "== 3/5 安装 nginx 配置 (listen $PORT1 / $PORT2) ==" "== 3/5 Installing nginx config (listen $PORT1 / $PORT2) ==")"
sed -e "s/__PORT1__/$PORT1/g" -e "s/__PORT2__/$PORT2/g" "$NGINX_CONF_SRC" > "$NGINX_CONF_DST"
echo "$(t "   已写入: $NGINX_CONF_DST" "   Written to: $NGINX_CONF_DST")"

# ---------------- 4/5 reload / 校验并重载 ----------------
echo "$(t '== 4/5 nginx 校验并重载 ==' '== 4/5 Validating and reloading nginx ==')"
nginx -t
systemctl reload nginx 2>/dev/null || nginx -s reload

# ---------------- 5/5 self check / 自检 ----------------
echo "$(t '== 5/5 自检 ==' '== 5/5 Self check ==')"
sleep 1
FAIL=0
for p in "$PORT1" "$PORT2"; do
    CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$p/" 2>/dev/null || echo ERR)
    echo "$(t "   portal on :$p -> $CODE" "   portal on :$p -> $CODE")"
    [ "$CODE" = "200" ] || FAIL=1
done
JS=$(grep -oE '/assets/index-[^"]+\.js' "$WEB_ROOT/index.html" | head -1)
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT1$JS" 2>/dev/null || echo ERR)
echo "$(t "   主包 $JS -> $CODE" "   main bundle $JS -> $CODE")"
[ "$CODE" = "200" ] || FAIL=1
for plugin in orchestration-center registry-center ontology-demo; do
    CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT1/plugins/$plugin/plugin.manifest.json" 2>/dev/null || echo ERR)
    echo "$(t "   插件 $plugin -> $CODE" "   plugin $plugin -> $CODE")"
    [ "$CODE" = "200" ] || FAIL=1
done

echo ""
if [ "$FAIL" = "0" ]; then
    echo "$(t '✅ 部署完成，全部自检通过。' '✅ Deployment finished, all self checks passed.')"
else
    echo "$(t '⚠️ 部署完成，但部分自检未通过，请检查上方输出。' '⚠️ Deployment finished, but some self checks FAILED, see output above.')"
fi
echo "$(t "回滚方式: rm -rf $WEB_ROOT && cp -a $BACKUP $WEB_ROOT && nginx -s reload" "Rollback: rm -rf $WEB_ROOT && cp -a $BACKUP $WEB_ROOT && nginx -s reload")"
[ "$FAIL" = "0" ]
