Homebrew PHP PECL 符号链接修复工具

📋 问题背景

在使用 Homebrew 安装的 PHP 8.x（尤其是 8.4）通过 pecl install 安装扩展时，可能会遇到以下错误：

Warning: mkdir(): File exists in System.php on line 294
ERROR: failed to mkdir /opt/homebrew/Cellar/php/8.4.5_1/pecl/20240924

根本原因

这是 Homebrew PHP Formula 的一个已知 Bug。Homebrew 在安装或升级 PHP 时，错误地将 pecl 目录创建为了符号链接（symlink），而非真实目录。PEAR/PECL 安装程序在尝试对符号链接执行 mkdir() 时，PHP 8.x 会抛出 File exists 警告并中断安装流程。

受影响的典型路径：

/opt/homebrew/Cellar/php//pecl → 符号链接
/opt/homebrew/lib/php/pecl → 符号链接

🛠️ 解决方案概述

本工具提供一个自动化 Shell 脚本 fix_pecl_symlink.sh，用于一键检测并修复上述问题。脚本的核心逻辑为：

自动检测当前激活的 PHP 版本及 API 版本号
检查 Cellar 和 lib 两处 pecl 路径是否为符号链接
安全移除符号链接并替换为真实目录
自动设置正确的用户权限与 API 子目录
验证修复结果

📦 文件说明
文件   用途
fix_pecl_symlink.sh   自动检查与修复脚本

README.md   本文档

🚀 快速开始

前置要求

macOS 系统（Apple Silicon 或 Intel 均可）
已安装 Homebrew
已通过 Homebrew 安装 PHP 8.x

使用步骤

赋予执行权限
chmod +x fix_pecl_symlink.sh

运行修复脚本
./fix_pecl_symlink.sh

验证修复成功后，正常安装扩展
pecl install 

提示：脚本全程不需要 sudo，因为 Homebrew PHP 目录归当前用户所有。

⚙️ 脚本特性

自动版本检测：通过 php -r 动态获取版本号和 API 版本号，无需手动指定
模糊版本匹配：兼容 Homebrew 带后缀的版本号（如 8.4.5_1）
双路径修复：同时处理 Cellar 和 /lib/php/pecl，避免遗漏
幂等安全：可重复运行，已修复状态下仅做权限确认，不破坏已有扩展
自动验证：修复完成后立即校验路径类型与子目录完整性
跨架构兼容：使用 brew --prefix 动态定位，同时支持 Apple Silicon (/opt/homebrew) 和 Intel (/usr/local)

⚠️ 注意事项

Homebrew 升级后需重新运行

每次执行 brew upgrade php 后，Formula 可能会重新将目录替换为符号链接。建议在每次 PHP 升级后重新运行此脚本。

已有扩展备份

如果之前在符号链接指向的目标目录中已安装过扩展，脚本移除符号链接时这些文件将不可访问。建议运行前手动备份：

cp -r /opt/homebrew/lib/php/pecl/* ~/pecl_backup/ 2>/dev/null || true

不适用的场景

非 Homebrew 安装的 PHP（如 phpbrew、asdf、官方 pkg 安装包）
Linux 环境
PHP 7.x 及以下版本（该 Bug 主要影响 PHP 8.x）

🔍 手动验证

如需在不运行脚本的情况下确认是否存在此问题：

如果输出以 'l' 开头，说明是符号链接（存在问题）
如果输出以 'd' 开头，说明是真实目录（正常）
ls -ld /opt/homebrew/Cellar/php/*/pecl
ls -ld /opt/homebrew/lib/php/pecl

📎 相关资源

Homebrew/homebrew-core Issues — 可搜索 "pecl symlink" 关注上游修复进度
PEAR Bug Tracker — PEAR System.php mkdir 兼容性问题的上游追踪