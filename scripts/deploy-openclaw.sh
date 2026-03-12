#!/bin/bash
# 本文件核心用途：OpenClaw 部署脚本（本地 Docker 构建 + 远程 SSH 部署 + NAT 回环自动 fallback）
# ============================================================================
# OpenClaw 部署脚本 v1.0
# 多渠道 AI 助手 — Docker 部署管理
# ============================================================================
#
# 🚀 快捷命令（常用）:
#   ./scripts/deploy-openclaw.sh deploy       # 一键部署（重建镜像 + 启动 + 健康检查）
#   ./scripts/deploy-openclaw.sh build        # 仅构建镜像（不启动）
#   ./scripts/deploy-openclaw.sh restart      # 快速重启（不重建镜像）
#   ./scripts/deploy-openclaw.sh remote-deploy  # SSH 远程部署（同步代码 + 远程重建）
#
# 📊 状态命令:
#   ./scripts/deploy-openclaw.sh status       # 查看容器状态
#   ./scripts/deploy-openclaw.sh logs         # 查看实时日志
#
# 🛑 停止命令:
#   ./scripts/deploy-openclaw.sh stop         # 停止所有容器
#
# 🔧 维护命令:
#   ./scripts/deploy-openclaw.sh health       # 健康检查
#   ./scripts/deploy-openclaw.sh clean        # 清理废弃镜像
#   ./scripts/deploy-openclaw.sh nginx        # 重载 Nginx 配置
#   ./scripts/deploy-openclaw.sh ssl-check    # 检查 SSL 证书到期时间
#
# ============================================================================

set -e

# ============================================================================
# 配置
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env"

# 服务配置
DOMAIN="openclaw.kline007.top"
GATEWAY_CONTAINER="openclaw-gateway"
GATEWAY_PORT=18791
BRIDGE_PORT=18792
# 健康检查：openclaw gateway 根路径返回 HTTP 响应即视为存活
HEALTH_URL="http://localhost:${GATEWAY_PORT}"
HEALTH_URL_HTTPS="https://${DOMAIN}"

# Nginx 配置（AITRADER 统一管理）
NGINX_CONTAINER="aitrader-nginx"
NGINX_CONF="$HOME/Documents/soft/AITRADER/nginx/nginx.conf"

# 远程 SSH 部署配置（可通过环境变量覆盖）
# 默认指向 openclaw.kline007.top（125.69.16.136）→ Mac Studio 本机
# 注意：从本机通过公网 IP 回连自己（NAT 回环）可能不通，脚本会自动 fallback 到内网
REMOTE_HOST="${REMOTE_HOST:-openclaw.kline007.top}"
REMOTE_PORT="${REMOTE_PORT:-2222}"
REMOTE_USER="${REMOTE_USER:-allenxing00}"
REMOTE_PROJECT_DIR="${REMOTE_PROJECT_DIR:-/Users/allenxing00/Documents/soft/openclaw}"
REMOTE_SSH_KEY="${REMOTE_SSH_KEY:-}"

# 云服务器部署配置（47.237.80.83）
CLOUD_REMOTE_HOST="${CLOUD_REMOTE_HOST:-47.237.80.83}"
CLOUD_REMOTE_PORT="${CLOUD_REMOTE_PORT:-22}"
CLOUD_REMOTE_USER="${CLOUD_REMOTE_USER:-root}"
CLOUD_REMOTE_PROJECT_DIR="${CLOUD_REMOTE_PROJECT_DIR:-/opt/openclaw}"
CLOUD_REMOTE_SSH_KEY="${CLOUD_REMOTE_SSH_KEY:-$HOME/Downloads/Openclaw.pem}"

# 部署锁（防止并发部署）
DEPLOY_LOCK="/tmp/openclaw-deploy.lock"
DEPLOY_LOCK_ACQUIRED=0

# ============================================================================
# 颜色输出
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; }

# ============================================================================
# 部署锁（防止并发部署冲突）
# ============================================================================
acquire_deploy_lock() {
    if [ -f "$DEPLOY_LOCK" ]; then
        local lock_age=$(( $(date +%s) - $(stat -f %m "$DEPLOY_LOCK" 2>/dev/null || echo 0) ))
        if [ "$lock_age" -lt 600 ]; then
            local lock_info=$(cat "$DEPLOY_LOCK" 2>/dev/null || echo "unknown")
            err "部署锁被占用（${lock_info}，${lock_age}秒前）"
            warn "如需强制解锁：rm -f $DEPLOY_LOCK"
            exit 1
        fi
        warn "发现过期锁文件（${lock_age}秒），自动清理"
        rm -f "$DEPLOY_LOCK"
    fi
    echo "OpenClaw $(date '+%Y-%m-%d %H:%M:%S')" > "$DEPLOY_LOCK"
    DEPLOY_LOCK_ACQUIRED=1
    log "已获取部署锁"
}

release_deploy_lock() {
    if [ "$DEPLOY_LOCK_ACQUIRED" -eq 1 ]; then
        rm -f "$DEPLOY_LOCK"
        DEPLOY_LOCK_ACQUIRED=0
    fi
}

cleanup_on_exit() {
    release_deploy_lock 2>/dev/null || true
}
trap cleanup_on_exit EXIT

# ============================================================================
# Docker 检查
# ============================================================================
check_docker() {
    if ! docker info &>/dev/null; then
        err "Docker 未运行，请先启动 Docker Desktop"
        exit 1
    fi
}

# ============================================================================
# .env 检查（openclaw 依赖 OPENCLAW_CONFIG_DIR 和 OPENCLAW_WORKSPACE_DIR）
# ============================================================================
check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        err ".env 文件不存在: $ENV_FILE"
        warn "请复制 .env.example 并填写必要配置: cp .env.example .env"
        exit 1
    fi
    # 检查关键环境变量
    local missing=()
    if ! grep -q "^OPENCLAW_CONFIG_DIR=" "$ENV_FILE" 2>/dev/null; then
        missing+=("OPENCLAW_CONFIG_DIR")
    fi
    if ! grep -q "^OPENCLAW_WORKSPACE_DIR=" "$ENV_FILE" 2>/dev/null; then
        missing+=("OPENCLAW_WORKSPACE_DIR")
    fi
    if [ ${#missing[@]} -gt 0 ]; then
        warn ".env 中缺少以下必要变量: ${missing[*]}"
        warn "docker compose 可能无法正常启动"
    fi
}

# ============================================================================
# 远程 SSH 检查与封装
# ============================================================================
check_remote_config() {
    if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_PROJECT_DIR" ]; then
        err "远程部署配置不完整，请检查 REMOTE_HOST/REMOTE_USER/REMOTE_PROJECT_DIR"
        exit 1
    fi
    if [ -n "$REMOTE_SSH_KEY" ] && [ ! -f "$REMOTE_SSH_KEY" ]; then
        err "SSH 私钥不存在: $REMOTE_SSH_KEY"
        exit 1
    fi
}

# 检测是否为本机（NAT 回环场景），自动 fallback 到本地执行
_is_local_machine() {
    local resolved_ip
    resolved_ip=$(python3 -c "import socket; print(socket.gethostbyname('$REMOTE_HOST'))" 2>/dev/null || echo "")
    # 获取本机所有 IP
    local local_ips
    local_ips=$(python3 -c "
import subprocess, re
out = subprocess.check_output(['ifconfig'], text=True, errors='ignore')
for line in out.splitlines():
    m = re.search(r'inet\s+(\d+\.\d+\.\d+\.\d+)', line)
    if m: print(m.group(1))
" 2>/dev/null || echo "")
    # 如果远程 IP 在本机 IP 列表中，可能是 NAT 回环
    if echo "$local_ips" | grep -qF "$resolved_ip" 2>/dev/null; then
        return 1  # IP 匹配本机，但可能是公网 IP，仍需测试 SSH
    fi
    return 1  # 默认认为不是本机
}

_resolve_ssh_target() {
    # 尝试通过公网连接，如果失败则 fallback 到内网 127.0.0.1:22
    local test_opts=(-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -p "$REMOTE_PORT")
    if [ -n "$REMOTE_SSH_KEY" ]; then
        test_opts+=(-i "$REMOTE_SSH_KEY")
    fi
    if ssh "${test_opts[@]}" "${REMOTE_USER}@${REMOTE_HOST}" 'echo ok' &>/dev/null; then
        RESOLVED_SSH_HOST="$REMOTE_HOST"
        RESOLVED_SSH_PORT="$REMOTE_PORT"
        return 0
    fi
    # Fallback: 尝试内网直连 22 端口
    local fallback_opts=(-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -p 22)
    if [ -n "$REMOTE_SSH_KEY" ]; then
        fallback_opts+=(-i "$REMOTE_SSH_KEY")
    fi
    if ssh "${fallback_opts[@]}" "${REMOTE_USER}@127.0.0.1" 'echo ok' &>/dev/null; then
        warn "公网 SSH 不通（NAT 回环），自动 fallback 到本机 127.0.0.1:22"
        RESOLVED_SSH_HOST="127.0.0.1"
        RESOLVED_SSH_PORT="22"
        return 0
    fi
    err "SSH 连接失败：公网 ${REMOTE_HOST}:${REMOTE_PORT} 和本机 127.0.0.1:22 均不可达"
    return 1
}

remote_ssh() {
    local remote_cmd="$1"
    # macOS SSH 会话 PATH 可能不含 Docker Desktop，注入常用路径
    local path_prefix="export PATH=/usr/local/bin:/opt/homebrew/bin:\$PATH; "
    local ssh_opts=(-p "$RESOLVED_SSH_PORT" -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30)
    if [ -n "$REMOTE_SSH_KEY" ]; then
        ssh_opts+=(-i "$REMOTE_SSH_KEY")
    fi
    ssh "${ssh_opts[@]}" "${REMOTE_USER}@${RESOLVED_SSH_HOST}" "${path_prefix}${remote_cmd}"
}

remote_rsync() {
    local ssh_cmd="ssh -p ${RESOLVED_SSH_PORT} -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30"
    if [ -n "$REMOTE_SSH_KEY" ]; then
        ssh_cmd="${ssh_cmd} -i ${REMOTE_SSH_KEY}"
    fi

    # 如果是本机 fallback，rsync 仍然有效（本机到本机），但跳过以节省时间
    if [ "$RESOLVED_SSH_HOST" = "127.0.0.1" ] && [ "$REMOTE_PROJECT_DIR" = "$PROJECT_ROOT" ]; then
        log "本机 fallback 且目录相同，跳过 rsync"
        return 0
    fi

    rsync -az --delete \
        --exclude ".git/" \
        --exclude "node_modules/" \
        --exclude "dist/" \
        --exclude ".env" \
        --exclude "data/" \
        --exclude ".pnpm-store/" \
        --exclude ".turbo/" \
        --exclude "*.tsbuildinfo" \
        -e "$ssh_cmd" \
        "$PROJECT_ROOT/" \
        "${REMOTE_USER}@${RESOLVED_SSH_HOST}:${REMOTE_PROJECT_DIR}/"
}

# ============================================================================
# 健康检查（openclaw gateway 不一定有 /health，检查端口可达即可）
# ============================================================================
health_check() {
    local url="${1:-$HEALTH_URL}"
    local max_retries="${2:-10}"
    local interval="${3:-3}"

    log "健康检查: $url（最多等待 $((max_retries * interval)) 秒）"

    for i in $(seq 1 $max_retries); do
        # 接受任意非 000（连接失败）的 HTTP 状态码，说明服务已启动
        local status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$url" 2>/dev/null || echo "000")
        if [ "$status" != "000" ]; then
            ok "健康检查通过 ✓ HTTP=${status} (${i}/${max_retries})"
            return 0
        fi
        echo -ne "  等待中... (${i}/${max_retries}) HTTP=${status}\r"
        sleep "$interval"
    done

    err "健康检查失败（${max_retries} 次尝试后仍不可达）"
    warn "查看日志: ./scripts/deploy-openclaw.sh logs"
    return 1
}

# ============================================================================
# 一键部署（全量重建）
# ============================================================================
do_deploy() {
    check_docker
    check_env
    acquire_deploy_lock

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  OpenClaw 一键部署${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""

    cd "$PROJECT_ROOT"

    # 1. 停止旧容器
    log "停止旧容器..."
    docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true

    # 2. 清理旧镜像（加速重建）
    log "清理旧镜像..."
    docker rmi $(docker images --filter "reference=openclaw*" -q) 2>/dev/null || true

    # 3. 重建镜像（无缓存，openclaw 构建较重：pnpm install + build + ui:build）
    log "重建镜像（无缓存，可能需要几分钟）..."
    docker compose -f "$COMPOSE_FILE" build --no-cache --build-arg OPENCLAW_DOCKER_APT_PACKAGES="docker-ce-cli"

    # 4. 启动服务
    log "启动服务..."
    docker compose -f "$COMPOSE_FILE" up -d openclaw-gateway

    # 5. 等待启动
    log "等待服务启动..."
    sleep 8

    # 6. 健康检查
    health_check "$HEALTH_URL" 15 3

    # 7. 清理废弃镜像层
    log "清理废弃镜像层..."
    docker image prune -f 2>/dev/null || true

    # 8. 重载 Nginx
    do_nginx_reload

    release_deploy_lock

    echo ""
    ok "部署完成！"
    echo ""
    echo -e "  ${CYAN}Web UI${NC}:    https://${DOMAIN}"
    echo -e "  ${CYAN}Gateway${NC}:   http://localhost:${GATEWAY_PORT}"
    echo -e "  ${CYAN}Bridge${NC}:    http://localhost:${BRIDGE_PORT}"
    echo ""
}

# ============================================================================
# 仅构建镜像（不启动）
# ============================================================================
do_build() {
    check_docker
    check_env

    echo ""
    log "构建 OpenClaw 镜像（可能需要几分钟）..."
    cd "$PROJECT_ROOT"

    docker compose -f "$COMPOSE_FILE" build --build-arg OPENCLAW_DOCKER_APT_PACKAGES="docker-ce-cli"

    ok "镜像构建完成！"
}

# ============================================================================
# 快速重启（不重建镜像）
# ============================================================================
do_restart() {
    check_docker

    echo ""
    log "快速重启..."
    cd "$PROJECT_ROOT"

    docker compose -f "$COMPOSE_FILE" restart openclaw-gateway

    log "等待服务恢复..."
    sleep 5
    health_check "$HEALTH_URL" 10 3

    ok "重启完成！"
}

# ============================================================================
# 停止服务
# ============================================================================
do_stop() {
    check_docker

    echo ""
    log "停止所有容器..."
    cd "$PROJECT_ROOT"
    docker compose -f "$COMPOSE_FILE" down

    ok "已停止"
}

# ============================================================================
# 查看状态
# ============================================================================
do_status() {
    check_docker

    echo ""
    echo -e "${BOLD}${CYAN}═══ OpenClaw 服务状态 ═══${NC}"
    echo ""

    # 容器状态
    cd "$PROJECT_ROOT"
    docker compose -f "$COMPOSE_FILE" ps 2>/dev/null || warn "容器未运行"

    echo ""

    # Gateway 健康检查
    local gw_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$HEALTH_URL" 2>/dev/null || echo "000")
    if [ "$gw_status" != "000" ]; then
        echo -e "  Gateway:   ${GREEN}● 正常${NC} (HTTP ${gw_status}, 端口 ${GATEWAY_PORT})"
    else
        echo -e "  Gateway:   ${RED}● 异常${NC} (端口 ${GATEWAY_PORT} 不可达)"
    fi

    # Bridge 端口检查（WebSocket 服务，用 TCP 连通性判断）
    if nc -z -w 3 localhost "$BRIDGE_PORT" 2>/dev/null; then
        echo -e "  Bridge:    ${GREEN}● 正常${NC} (端口 ${BRIDGE_PORT} 可达)"
    else
        echo -e "  Bridge:    ${RED}● 异常${NC} (端口 ${BRIDGE_PORT} 不可达)"
    fi

    # HTTPS 检查
    local https_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$HEALTH_URL_HTTPS" 2>/dev/null || echo "000")
    if [ "$https_status" != "000" ]; then
        echo -e "  HTTPS:     ${GREEN}● 正常${NC} (HTTP ${https_status})"
    else
        echo -e "  HTTPS:     ${RED}● 异常${NC} (${DOMAIN} 不可达)"
    fi

    echo ""
}

# ============================================================================
# 查看日志
# ============================================================================
do_logs() {
    check_docker
    cd "$PROJECT_ROOT"
    docker compose -f "$COMPOSE_FILE" logs -f --tail=100
}

do_logs_gateway() {
    check_docker
    cd "$PROJECT_ROOT"
    docker compose -f "$COMPOSE_FILE" logs -f --tail=100 openclaw-gateway
}

# ============================================================================
# Nginx 重载
# ============================================================================
do_nginx_reload() {
    if docker ps --format '{{.Names}}' | grep -q "$NGINX_CONTAINER"; then
        log "重载 Nginx..."
        docker exec "$NGINX_CONTAINER" nginx -s reload 2>/dev/null && ok "Nginx 已重载" || warn "Nginx 重载失败"
    else
        warn "Nginx 容器 ($NGINX_CONTAINER) 未运行，跳过重载"
    fi
}

# ============================================================================
# 清理废弃镜像
# ============================================================================
do_clean() {
    check_docker

    echo ""
    log "清理废弃 Docker 镜像..."

    local before=$(docker images | wc -l)
    docker image prune -f 2>/dev/null
    docker builder prune -f 2>/dev/null || true
    local after=$(docker images | wc -l)

    ok "清理完成（镜像数: ${before} → ${after}）"
}

# ============================================================================
# SSL 证书检查
# ============================================================================
do_ssl_check() {
    echo ""
    log "检查 SSL 证书: ${DOMAIN}"

    local cert_info=$(echo | openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    if [ -n "$cert_info" ]; then
        echo "$cert_info"
        ok "证书信息获取成功"
    else
        err "无法获取证书信息（HTTPS 可能未配置）"
    fi
}

# ============================================================================
# 远程部署（SSH）
# ============================================================================
do_remote_deploy() {
    check_remote_config
    _resolve_ssh_target || exit 1
    acquire_deploy_lock

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  OpenClaw 远程部署（SSH）${NC}"
    echo -e "${BOLD}${CYAN}  目标: ${REMOTE_USER}@${RESOLVED_SSH_HOST}:${RESOLVED_SSH_PORT} → ${REMOTE_PROJECT_DIR}${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""

    log "检查远程目录..."
    remote_ssh "mkdir -p '$REMOTE_PROJECT_DIR'"

    log "同步代码到远程..."
    remote_rsync

    log "远程重建并启动服务（可能需要几分钟）..."
    remote_ssh "cd '$REMOTE_PROJECT_DIR' && docker compose -f docker-compose.yml build --build-arg OPENCLAW_DOCKER_APT_PACKAGES='docker-ce-cli' && docker compose -f docker-compose.yml up -d openclaw-gateway"

    log "远程健康检查..."
    remote_ssh "cd '$REMOTE_PROJECT_DIR' && for i in \$(seq 1 15); do code=\$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 'http://localhost:${GATEWAY_PORT}' 2>/dev/null || echo 000); if [ \"\$code\" != \"000\" ]; then echo 'health ok (HTTP='\$code')'; exit 0; fi; sleep 3; done; exit 1"

    log "尝试重载远程 Nginx..."
    remote_ssh "docker exec '$NGINX_CONTAINER' nginx -s reload >/dev/null 2>&1 || true"

    release_deploy_lock

    echo ""
    ok "远程部署完成！"
    echo ""
    echo -e "  ${CYAN}连接方式${NC}: ${RESOLVED_SSH_HOST}:${RESOLVED_SSH_PORT}"
    echo -e "  ${CYAN}Web UI${NC}:  https://${DOMAIN}"
    echo -e "  ${CYAN}Gateway${NC}: 端口 ${GATEWAY_PORT}"
    echo -e "  ${CYAN}Bridge${NC}:  端口 ${BRIDGE_PORT}"
    echo ""
}

do_remote_deploy_cloud() {
    # 备份当前 REMOTE_* 配置，方便恢复
    local old_REMOTE_HOST="$REMOTE_HOST"
    local old_REMOTE_PORT="$REMOTE_PORT"
    local old_REMOTE_USER="$REMOTE_USER"
    local old_REMOTE_PROJECT_DIR="$REMOTE_PROJECT_DIR"
    local old_REMOTE_SSH_KEY="$REMOTE_SSH_KEY"
    local old_RESOLVED_SSH_HOST="$RESOLVED_SSH_HOST"
    local old_RESOLVED_SSH_PORT="$RESOLVED_SSH_PORT"

    REMOTE_HOST="$CLOUD_REMOTE_HOST"
    REMOTE_PORT="$CLOUD_REMOTE_PORT"
    REMOTE_USER="$CLOUD_REMOTE_USER"
    REMOTE_PROJECT_DIR="$CLOUD_REMOTE_PROJECT_DIR"
    REMOTE_SSH_KEY="$CLOUD_REMOTE_SSH_KEY"
    unset RESOLVED_SSH_HOST RESOLVED_SSH_PORT

    check_remote_config
    _resolve_ssh_target || {
        REMOTE_HOST="$old_REMOTE_HOST"
        REMOTE_PORT="$old_REMOTE_PORT"
        REMOTE_USER="$old_REMOTE_USER"
        REMOTE_PROJECT_DIR="$old_REMOTE_PROJECT_DIR"
        REMOTE_SSH_KEY="$old_REMOTE_SSH_KEY"
        RESOLVED_SSH_HOST="$old_RESOLVED_SSH_HOST"
        RESOLVED_SSH_PORT="$old_RESOLVED_SSH_PORT"
        exit 1
    }
    acquire_deploy_lock

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  OpenClaw 远程部署（云服务器）${NC}"
    echo -e "${BOLD}${CYAN}  目标: ${REMOTE_USER}@${RESOLVED_SSH_HOST}:${RESOLVED_SSH_PORT} → ${REMOTE_PROJECT_DIR}${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""

    log "检查远程目录..."
    remote_ssh "mkdir -p '$REMOTE_PROJECT_DIR'"

    log "同步代码到远程..."
    remote_rsync

    log "远程重建并启动服务（可能需要几分钟）..."
    remote_ssh "cd '$REMOTE_PROJECT_DIR' && docker compose -f docker-compose.yml build --build-arg OPENCLAW_DOCKER_APT_PACKAGES='docker-ce-cli' && docker compose -f docker-compose.yml up -d openclaw-gateway"

    log "远程健康检查..."
    remote_ssh "cd '$REMOTE_PROJECT_DIR' && for i in \$(seq 1 15); do code=\$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 'http://localhost:${GATEWAY_PORT}' 2>/dev/null || echo 000); if [ \"\$code\" != \"000\" ]; then echo 'health ok (HTTP='\$code')'; exit 0; fi; sleep 3; done; exit 1"

    log "尝试重载远程 Nginx..."
    remote_ssh "docker exec '$NGINX_CONTAINER' nginx -s reload >/dev/null 2>&1 || true"

    release_deploy_lock

    echo ""
    ok "远程部署完成（云服务器）！"
    echo ""
    echo -e "  ${CYAN}连接方式${NC}: ${RESOLVED_SSH_HOST}:${RESOLVED_SSH_PORT}"
    echo -e "  ${CYAN}Web UI${NC}:  https://${DOMAIN}"
    echo -e "  ${CYAN}Gateway${NC}: 端口 ${GATEWAY_PORT}"
    echo -e "  ${CYAN}Bridge${NC}:  端口 ${BRIDGE_PORT}"
    echo ""

    # 恢复 REMOTE_* 配置
    REMOTE_HOST="$old_REMOTE_HOST"
    REMOTE_PORT="$old_REMOTE_PORT"
    REMOTE_USER="$old_REMOTE_USER"
    REMOTE_PROJECT_DIR="$old_REMOTE_PROJECT_DIR"
    REMOTE_SSH_KEY="$old_REMOTE_SSH_KEY"
    RESOLVED_SSH_HOST="$old_RESOLVED_SSH_HOST"
    RESOLVED_SSH_PORT="$old_RESOLVED_SSH_PORT"
}

do_remote_status() {
    check_remote_config
    _resolve_ssh_target || exit 1
    echo ""
    log "远程状态: ${REMOTE_USER}@${RESOLVED_SSH_HOST}:${RESOLVED_SSH_PORT} → ${REMOTE_PROJECT_DIR}"
    remote_ssh "cd '$REMOTE_PROJECT_DIR' && docker compose -f docker-compose.yml ps"
}

do_remote_logs() {
    check_remote_config
    _resolve_ssh_target || exit 1
    echo ""
    log "远程日志跟踪: ${REMOTE_USER}@${RESOLVED_SSH_HOST}:${RESOLVED_SSH_PORT} → ${REMOTE_PROJECT_DIR}"
    remote_ssh "cd '$REMOTE_PROJECT_DIR' && docker compose -f docker-compose.yml logs -f --tail=100"
}

# ============================================================================
# 交互式菜单
# ============================================================================
show_menu() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  OpenClaw 部署管理 v1.0${NC}"
    echo -e "${BOLD}${CYAN}  域名: ${DOMAIN}${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}部署命令:${NC}"
    echo -e "    ${GREEN}1${NC}) deploy     一键部署（全量重建）"
    echo -e "    ${GREEN}2${NC}) build      仅构建镜像"
    echo -e "    ${GREEN}3${NC}) restart    快速重启"
    echo ""
    echo -e "  ${BOLD}状态命令:${NC}"
    echo -e "    ${GREEN}4${NC}) status     查看状态"
    echo -e "    ${GREEN}5${NC}) logs       查看日志"
    echo -e "    ${GREEN}6${NC}) health     健康检查"
    echo ""
    echo -e "  ${BOLD}维护命令:${NC}"
    echo -e "    ${GREEN}7${NC}) stop       停止服务"
    echo -e "    ${GREEN}8${NC}) clean      清理废弃镜像"
    echo -e "    ${GREEN}9${NC}) nginx      重载 Nginx"
    echo -e "    ${GREEN}0${NC}) ssl-check  检查 SSL 证书"
    echo ""
    echo -e "  ${BOLD}远程命令:${NC}"
    echo -e "    ${GREEN}a${NC}) remote-deploy  SSH 远程部署"
    echo -e "    ${GREEN}b${NC}) remote-status  SSH 查看远程状态"
    echo -e "    ${GREEN}c${NC}) remote-logs    SSH 查看远程日志"
    echo -e "    ${GREEN}d${NC}) remote-deploy-cloud  SSH 远程部署（云服务器 47.237.80.83）"
    echo ""
    echo -ne "  请选择 [0-9/a-c]: "
    read -r choice

    case "$choice" in
        1|deploy)   do_deploy ;;
        2|build)    do_build ;;
        3|restart)  do_restart ;;
        4|status)   do_status ;;
        5|logs)     do_logs ;;
        6|health)   health_check "$HEALTH_URL" ;;
        7|stop)     do_stop ;;
        8|clean)    do_clean ;;
        9|nginx)    do_nginx_reload ;;
        0|ssl)      do_ssl_check ;;
        a|remote-deploy) do_remote_deploy ;;
        b|remote-status) do_remote_status ;;
        c|remote-logs)   do_remote_logs ;;
        d|remote-deploy-cloud) do_remote_deploy_cloud ;;
        *)          err "无效选择: $choice" ;;
    esac
}

# ============================================================================
# 主入口
# ============================================================================
main() {
    case "${1:-}" in
        deploy|d)       do_deploy ;;
        build|b)        do_build ;;
        restart|r)      do_restart ;;
        stop)           do_stop ;;
        status|s)       do_status ;;
        logs|l)         do_logs ;;
        logs-gw|lg)     do_logs_gateway ;;
        health|h)       health_check "$HEALTH_URL" ;;
        clean|c)        do_clean ;;
        nginx|n)        do_nginx_reload ;;
        ssl-check|ssl)  do_ssl_check ;;
        remote-deploy|rd)  do_remote_deploy ;;
        remote-deploy-cloud|rdc)  do_remote_deploy_cloud ;;
        remote-status|rs)  do_remote_status ;;
        remote-logs|rl)    do_remote_logs ;;
        help|--help|-h)
            echo "用法: $0 <command>"
            echo ""
            echo "部署命令:"
            echo "  deploy, d       一键部署（全量重建）"
            echo "  build, b        仅构建镜像（不启动）"
            echo "  restart, r      快速重启（不重建镜像）"
            echo ""
            echo "状态命令:"
            echo "  status, s       查看容器状态"
            echo "  logs, l         查看所有日志"
            echo "  logs-gw, lg     仅 Gateway 日志"
            echo "  health, h       健康检查"
            echo ""
            echo "维护命令:"
            echo "  stop            停止所有容器"
            echo "  clean, c        清理废弃镜像"
            echo "  nginx, n        重载 Nginx"
            echo "  ssl-check, ssl  检查 SSL 证书"
            echo ""
            echo "远程命令:"
            echo "  remote-deploy, rd  SSH 远程部署（同步代码 + 远程重建）"
            echo "  remote-status, rs  SSH 查看远程容器状态"
            echo "  remote-logs, rl    SSH 查看远程实时日志"
            echo ""
            echo "远程环境变量（可选覆盖）:"
            echo "  REMOTE_HOST, REMOTE_PORT, REMOTE_USER, REMOTE_PROJECT_DIR, REMOTE_SSH_KEY"
            echo ""
            echo "无参数则显示交互式菜单"
            ;;
        "")             show_menu ;;
        *)
            err "未知命令: $1"
            echo "使用 $0 --help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
