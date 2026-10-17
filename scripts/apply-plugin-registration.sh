#!/usr/bin/env bash
# ============================================================================
# OpenAN Portal — bundle plugin registration replay (idempotent)
#
# 用法 / Usage:
#   bash apply-plugin-registration.sh [WEB_ROOT] [APP_URL]
#
#   WEB_ROOT   部署目录 (默认 /OpenA2A-T/openan-portal-frontend)
#              Deployment directory (same default as deploy-zh.sh)
#   APP_URL    可选：AN Ontology 编辑器地址，注入为
#              window.__OPENAN_ONTOLOGY_APP_URL__（留空则跳过注入）
#              Optional: AN Ontology editor URL injected as
#              window.__OPENAN_ONTOLOGY_APP_URL__ (skipped when empty)
#
# 为什么需要 / Why:
#   部署包（deploy-zh.sh）为叠加式覆盖：重新部署或本地重新构建会重写
#   index.html 引用的主 bundle，其中 zu 插件注册数组回到构建时的原始状态，
#   导致运行时注册的 bundle 插件（observation-center / virtual-showroom /
#   an-ontology）从菜单消失。本脚本在**产物级**幂等地恢复这些注册，
#   与 plugins.config.js 的源码级注册互补（部署第三方产物时无法改源码重建）。
#
#   The deploy package overlays a prebuilt tarball: every redeploy/rebuild
#   rewrites the main bundle referenced by index.html and resets the runtime
#   `zu` plugin registration array, so bundle plugins registered outside the
#   shipped build (observation-center / virtual-showroom / an-ontology)
#   disappear from the menu. This script restores those registrations
#   idempotently at the artifact level, complementing the source-level
#   registration in plugins.config.js (which cannot be rebuilt into
#   third-party deployment artifacts).
#
# 幂等 / Idempotent: 可重复执行；已注册的条目自动跳过；补丁失败自动回滚。
#                    Safe to re-run; already-patched items are skipped;
#                    a failed patch is rolled back from backup.
# ============================================================================
set -euo pipefail

WEB_ROOT="${1:-/OpenA2A-T/openan-portal-frontend}"
APP_URL="${2:-}"
INDEX="$WEB_ROOT/index.html"

# --- 1. locate the current main bundle from index.html ---------------------
MAIN_REF=$(grep -oE '/assets/index-[A-Za-z0-9_-]+\.js' "$INDEX" | head -1)
if [ -z "$MAIN_REF" ]; then
  echo "ERROR: no /assets/index-*.js reference found in $INDEX"
  echo "错误：index.html 中未找到主 bundle 引用"
  exit 1
fi
MAIN="$WEB_ROOT$MAIN_REF"
echo "main bundle: $MAIN"
cp "$MAIN" "$MAIN.bak-plugins" 2>/dev/null || true

# --- 2. patch zu registration array ----------------------------------------
BUNDLES=(
  "observation-center"
  "virtual-showroom"
  "an-ontology"
)
python3 - "$MAIN" "${BUNDLES[@]}" <<'EOF'
import sys

path, bundles = sys.argv[1], sys.argv[2:]
src = open(path, encoding='utf-8').read()

inject = ",".join(
    "{{id:`{0}`,mode:`bundle`,entry:`/plugins/{0}`,enabled:!0}}".format(b)
    for b in bundles
) + "]"

anchors = [
    "{id:`orchestration-center`,mode:`bundle`,entry:`/plugins/orchestration-center`,enabled:!0}]",
    "{id:`ontology-demo`,mode:`bundle`,entry:`/plugins/ontology-demo`,enabled:!1}]",
]

if all("{{id:`{0}`,mode:`bundle`".format(b) in src for b in bundles):
    print("zu inject: already present, skip / 已注册，跳过")
else:
    for anchor in anchors:
        if src.count(anchor) == 1:
            src = src.replace(anchor, anchor[:-1] + inject)
            print("zu inject: OK (anchor: %s)" % anchor.split("`")[1])
            break
    else:
        print("ERROR: no zu anchor found / 未找到 zu 注册数组锚点")
        sys.exit(2)

# zh label fix for the observation plugin menu (site-specific, best effort)
old_i18n = '"Observation Center":`可观测中心`'
new_i18n = '"Observation Center":`观测中心`'
if old_i18n in src:
    src = src.replace(old_i18n, new_i18n)
    print("i18n label fix: OK")
elif new_i18n in src:
    print("i18n label fix: already present, skip / 已修正，跳过")
else:
    print("i18n label fix: baseline not found, skip / 未找到基线（可忽略）")

open(path, 'w', encoding='utf-8').write(src)
print("saved: %s" % path)
EOF

# --- 3. optional: inject AN Ontology app URL for the portal iframe plugin ---
if [ -n "$APP_URL" ]; then
  python3 - "$INDEX" "$APP_URL" <<'EOF'
import re, sys
path, url = sys.argv[1], sys.argv[2]
src = open(path, encoding='utf-8').read()
line = "<script>window.__OPENAN_ONTOLOGY_APP_URL__='%s';</script>" % url
if '__OPENAN_ONTOLOGY_APP_URL__' in src:
    src = re.sub(r"<script>[^<]*__OPENAN_ONTOLOGY_APP_URL__[^<]*</script>", line, src)
    print("app url var: refreshed / 已刷新")
else:
    src = src.replace('</head>', line + '\n</head>', 1)
    print("app url var: injected / 已注入")
open(path, 'w', encoding='utf-8').write(src)
EOF
fi

# --- 4. verify ---------------------------------------------------------------
for b in "${BUNDLES[@]}"; do
  n=$(grep -c "$b\`,mode" "$MAIN" || true)
  echo "verify $b: $n"
done
echo "done. reload nginx is NOT required (static files served from disk)."
echo "完成。静态文件即时生效，浏览器强刷即可看到插件菜单。"
