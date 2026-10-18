#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Sourced by both variants; never starts deployment on its own.
OPENAN_DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validate_deploy_args() {
    [[ "$WEB_ROOT" =~ ^/[a-zA-Z0-9_./\ -]+$ ]] && [[ "$WEB_ROOT" != *'/../'* && "$WEB_ROOT" != */.. ]] || {
        echo 'ERROR: WEB_ROOT must be an absolute, literal directory path'; return 1;
    }
    WEB_ROOT="$(realpath -m -- "$WEB_ROOT")"
    [[ "$WEB_ROOT" != / && "$WEB_ROOT" != /home && "$WEB_ROOT" != /root && "$WEB_ROOT" != /etc && "$WEB_ROOT" != /usr ]] || {
        echo 'ERROR: unsafe WEB_ROOT'; return 1;
    }
    local port
    for port in "$PORT1" "$PORT2"; do
        [[ "$port" =~ ^[0-9]{1,5}$ ]] && ((10#$port > 0 && 10#$port <= 65535)) || {
            echo 'ERROR: port must be in 1..65535'; return 1;
        }
    done
    PORT1=$((10#$PORT1))
    PORT2=$((10#$PORT2))
    [[ "$PORT1" != "$PORT2" ]] || { echo 'ERROR: ports must differ'; return 1; }
}

render_nginx() {
    sed -e "s/__PORT1__/$PORT1/g" -e "s/__PORT2__/$PORT2/g" -e "s|__WEB_ROOT__|$WEB_ROOT|g" "$NGINX_CONF_SRC"
}

verify_release_files() {
    "${PYTHON_BIN:-python3}" "$OPENAN_DEPLOY_SCRIPT_DIR/verify-release.py" "$WEB_ROOT"
}

check_plugins() {
    "${PYTHON_BIN:-python3}" "$OPENAN_DEPLOY_SCRIPT_DIR/verify-release.py" "$WEB_ROOT" --url "http://127.0.0.1:$PORT1"
}
