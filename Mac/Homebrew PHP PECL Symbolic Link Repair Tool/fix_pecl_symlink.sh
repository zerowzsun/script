#!/bin/bash
# =============================================================================
# 脚本名称: fix_pecl_symlink.sh
# 描述:     自动检测并修复 Homebrew PHP 8.x pecl 符号链接导致的 mkdir 失败问题
# 适用环境: macOS + Homebrew (Apple Silicon /opt/homebrew 或 Intel /usr/local)
# 用法:     chmod +x fix_pecl_symlink.sh && ./fix_pecl_symlink.sh
# =============================================================================

set -euo pipefail

# ------------------------- 颜色输出定义 -------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ------------------------- 前置检查 -------------------------
if [[ "$(uname)" != "Darwin" ]]; then
    error "此脚本仅适用于 macOS 系统"
fi

if ! command -v brew &>/dev/null; then
    error "未检测到 Homebrew，请先安装: https://brew.sh"
fi

if ! command -v php &>/dev/null; then
    error "未检测到 PHP，请先运行: brew install php"
fi

# ------------------------- 获取 PHP 信息 -------------------------
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_API=$(php -r 'echo PHP_API_VERSION;')
BREW_PREFIX=$(brew --prefix)

# 定位 Cellar 中的 PHP 路径
PHP_CELLAR_DIR="${BREW_PREFIX}/Cellar/php/${PHP_VERSION}"

# 如果精确版本目录不存在，尝试模糊匹配（如 8.4.5_1）
if [[ ! -d "$PHP_CELLAR_DIR" ]]; then
    PHP_CELLAR_DIR=$(find "${BREW_PREFIX}/Cellar/php" -maxdepth 1 -type d -name "${PHP_VERSION}*" | head -n1)
fi

if [[ -z "$PHP_CELLAR_DIR" || ! -d "$PHP_CELLAR_DIR" ]]; then
    error "无法在 Cellar 中找到 PHP ${PHP_VERSION} 的安装目录"
fi

PECL_CELLAR="${PHP_CELLAR_DIR}/pecl"
PECL_LIB="${BREW_PREFIX}/lib/php/pecl"
CURRENT_USER=$(whoami)

info "PHP 版本:    ${PHP_VERSION}"
info "PHP API:     ${PHP_API}"
info "Cellar 路径: ${PHP_CELLAR_DIR}"
info "用户:        ${CURRENT_USER}"
echo ""

# ------------------------- 核心修复函数 -------------------------
fix_pecl_path() {
    local target_path="$1"
    local label="$2"

    if [[ ! -e "$target_path" ]]; then
        info "[${label}] 路径不存在，正在创建真实目录..."
        mkdir -p "${target_path}/${PHP_API}"
        chown -R "${CURRENT_USER}:admin" "$target_path"
        chmod -R u+rwx "$target_path"
        success "[${label}] 已创建: ${target_path}/${PHP_API}"
        return 0
    fi

    if [[ -L "$target_path" ]]; then
        warn "[${label}] 检测到符号链接: $(readlink "$target_path")"
        info "[${label}] 正在移除符号链接并替换为真实目录..."

        rm -f "$target_path"
        mkdir -p "${target_path}/${PHP_API}"
        chown -R "${CURRENT_USER}:admin" "$target_path"
        chmod -R u+rwx "$target_path"

        success "[${label}] 已修复为真实目录: ${target_path}/${PHP_API}"
        return 0
    fi

    if [[ -d "$target_path" ]]; then
        # 已经是真实目录，检查权限和子目录
        if [[ ! -d "${target_path}/${PHP_API}" ]]; then
            mkdir -p "${target_path}/${PHP_API}"
        fi
        chown -R "${CURRENT_USER}:admin" "$target_path"
        chmod -R u+rwx "$target_path"
        success "[${label}] 已是真实目录，权限已确认 ✓"
        return 0
    fi

    warn "[${label}] 路径存在但不是目录也不是符号链接，请手动检查: ${target_path}"
    return 1
}

# ------------------------- 执行修复 -------------------------
echo "========================================="
echo "  PECL 符号链接 Bug 自动修复工具"
echo "========================================="
echo ""

HAS_ERROR=0

fix_pecl_path "$PECL_CELLAR" "Cellar" || HAS_ERROR=1
echo ""
fix_pecl_path "$PECL_LIB"    "Lib"    || HAS_ERROR=1

echo ""
echo "========================================="

# ------------------------- 验证结果 -------------------------
info "验证修复结果..."
VERIFY_PASS=true

for check_path in "$PECL_CELLAR" "$PECL_LIB"; do
    if [[ -L "$check_path" ]]; then
        error "验证失败: ${check_path} 仍然是符号链接！"
        VERIFY_PASS=false
    elif [[ ! -d "${check_path}/${PHP_API}" ]]; then
        warn "验证警告: ${check_path}/${PHP_API} 目录不存在"
        VERIFY_PASS=false
    fi
done

if $VERIFY_PASS; then
    success "所有检查通过！现在可以正常运行 pecl install 了"
    echo ""
    info "测试命令: pecl install <扩展名>"
else
    warn "部分检查未通过，请查看上方日志手动处理"
fi

echo "========================================="
exit $HAS_ERROR