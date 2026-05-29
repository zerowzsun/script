#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Homebrew PHP PECL 符号链接修复工具 v2.0
# 
# 用法:
#   ./fix_pecl_symlink.sh fix      # 升级PHP后运行，临时解除符号链接
#   ./fix_pecl_symlink.sh restore  # pecl install 完成后运行，恢复符号链接
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# -------------------- 环境检测 --------------------
detect_php_env() {
    if ! command -v php &>/dev/null; then
        error "未找到 php 命令，请确认已安装 Homebrew PHP"
        exit 1
    fi

    PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION.".".PHP_RELEASE_VERSION;')
    PHP_API=$(php -r 'echo PHP_API_VERSION;')
    BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")

    # Homebrew 版本号可能带后缀如 8.4.5_1，需模糊匹配
    CELLAR_PHP_DIR=$(find "${BREW_PREFIX}/Cellar/php" -maxdepth 1 -type d -name "${PHP_VERSION}*" 2>/dev/null | head -1)

    if [[ -z "${CELLAR_PHP_DIR}" ]]; then
        error "未在 ${BREW_PREFIX}/Cellar/php 中找到 PHP ${PHP_VERSION} 的安装目录"
        exit 1
    fi

    CELLAR_PECL="${CELLAR_PHP_DIR}/pecl"
    LIB_PECL="${BREW_PREFIX}/lib/php/pecl"

    info "PHP 版本:     ${PHP_VERSION}"
    info "PHP API:      ${PHP_API}"
    info "Cellar PECL:  ${CELLAR_PECL}"
    info "Lib PECL:     ${LIB_PECL}"
    echo ""
}

# -------------------- fix 模式 --------------------
do_fix() {
    info "=== 模式: FIX (临时解除符号链接) ==="
    echo ""

    local changed=0

    # 处理 /lib/php/pecl
    if [[ -L "${LIB_PECL}" ]]; then
        warn "${LIB_PECL} 是符号链接，正在替换为真实目录..."
        rm -f "${LIB_PECL}"
        mkdir -p "${LIB_PECL}/${PHP_API}"
        success "已创建真实目录: ${LIB_PECL}/${PHP_API}"
        changed=1
    elif [[ -d "${LIB_PECL}" ]]; then
        success "${LIB_PECL} 已是真实目录，跳过"
        # 确保 API 子目录存在
        mkdir -p "${LIB_PECL}/${PHP_API}"
    else
        mkdir -p "${LIB_PECL}/${PHP_API}"
        success "已创建目录: ${LIB_PECL}/${PHP_API}"
        changed=1
    fi

    # 处理 Cellar pecl
    if [[ -L "${CELLAR_PECL}" ]]; then
        warn "${CELLAR_PECL} 是符号链接，正在替换为真实目录..."
        rm -f "${CELLAR_PECL}"
        mkdir -p "${CELLAR_PECL}/${PHP_API}"
        success "已创建真实目录: ${CELLAR_PECL}/${PHP_API}"
        changed=1
    elif [[ -d "${CELLAR_PECL}" ]]; then
        success "${CELLAR_PECL} 已是真实目录，跳过"
        mkdir -p "${CELLAR_PECL}/${PHP_API}"
    else
        mkdir -p "${CELLAR_PECL}/${PHP_API}"
        success "已创建目录: ${CELLAR_PECL}/${PHP_API}"
        changed=1
    fi

    echo ""
    if [[ ${changed} -eq 1 ]]; then
        success "修复完成！现在可以安全运行:"
        echo -e "  ${CYAN}pecl install -f <扩展名>${NC}"
        echo ""
        warn "⚠️  安装完所有扩展后，请务必运行:"
        echo -e "  ${CYAN}$0 restore${NC}"
    else
        success "路径状态正常，无需修复"
    fi
}

# -------------------- restore 模式 --------------------
do_restore() {
    info "=== 模式: RESTORE (恢复符号链接) ==="
    echo ""

    # 检查 Cellar 中是否有已安装的扩展
    local has_extensions=0
    if [[ -d "${CELLAR_PECL}/${PHP_API}" ]]; then
        local so_count
        so_count=$(find "${CELLAR_PECL}/${PHP_API}" -name "*.so" 2>/dev/null | wc -l | tr -d ' ')
        if [[ ${so_count} -gt 0 ]]; then
            has_extensions=1
            info "在 Cellar 中发现 ${so_count} 个已安装的 .so 文件"
        fi
    fi

    if [[ ${has_extensions} -eq 0 ]]; then
        warn "Cellar PECL 目录中没有发现任何 .so 文件"
        warn "请先运行 'pecl install -f <扩展名>' 安装扩展后再执行 restore"
        echo ""
        read -rp "是否仍要强制恢复符号链接？(y/N) " confirm
        if [[ "${confirm}" != [yY] ]]; then
            info "已取消操作"
            exit 0
        fi
    fi

    # 删除 /lib/php/pecl 真实目录，重建指向 Cellar 的符号链接
    if [[ -d "${LIB_PECL}" && ! -L "${LIB_PECL}" ]]; then
        info "移除独立目录: ${LIB_PECL}"
        rm -rf "${LIB_PECL}"
    elif [[ -L "${LIB_PECL}" ]]; then
        info "符号链接已存在，先移除旧链接"
        rm -f "${LIB_PECL}"
    fi

    ln -s "${CELLAR_PECL}" "${LIB_PECL}"
    success "已恢复符号链接: ${LIB_PECL} -> ${CELLAR_PECL}"

    # 验证
    echo ""
    info "验证结果:"
    if [[ -L "${LIB_PECL}" ]]; then
        local target
        target=$(readlink "${LIB_PECL}")
        success "符号链接目标: ${target}"
    else
        error "符号链接恢复失败！"
        exit 1
    fi

    # 检查 redis.so 等常见扩展是否可访问
    if [[ -f "${LIB_PECL}/${PHP_API}/redis.so" ]]; then
        success "redis.so 可通过符号链接正常访问 ✅"
    fi

    echo ""
    success "恢复完成！请验证 PHP 扩展加载:"
    echo -e "  ${CYAN}php -m | grep redis${NC}"
}

# -------------------- 主入口 --------------------
usage() {
    echo "用法: $0 <fix|restore>"
    echo ""
    echo "  fix      升级 PHP 后运行，将 pecl 符号链接替换为真实目录"
    echo "           使 pecl install 不再触发 mkdir(): File exists 错误"
    echo ""
    echo "  restore  pecl install 完成后运行，恢复 /lib/php/pecl 符号链接"
    echo "           使 PHP 运行时能正确找到 Cellar 中的 .so 文件"
    echo ""
    echo "典型工作流:"
    echo "  brew upgrade php"
    echo "  $0 fix"
    echo "  pecl install -f redis"
    echo "  pecl install -f xdebug"
    echo "  $0 restore"
    echo "  php -m | grep -E 'redis|xdebug'"
}

main() {
    local cmd="${1:-}"

    if [[ -z "${cmd}" ]]; then
        usage
        exit 1
    fi

    detect_php_env

    case "${cmd}" in
        fix)     do_fix ;;
        restore) do_restore ;;
        *)
            error "未知命令: ${cmd}"
            usage
            exit 1
            ;;
    esac
}

main "$@"