### 📖 Homebrew PHP PECL 符号链接修复工具

解决 macOS Apple Silicon 环境下，通过 Homebrew 管理 PHP 时执行 `pecl install` 触发 `mkdir(): File exists` 错误，以及修复后扩展无法加载的完整自动化工具。

#### 🎯 解决的问题

Homebrew 安装的 PHP 存在一个长期未修复的路径机制缺陷：

1.  **写入阶段报错**：`/opt/homebrew/lib/php/pecl` 是指向 Cellar 的符号链接，PECL 在编译安装扩展时对该符号链接执行 `mkdir()` 创建 API 版本子目录会失败
2.  **读取阶段断裂**：若简单将符号链接替换为真实目录来绕过上述错误，会导致 PECL 将 `.so` 文件安装到 Cellar 中，而 PHP 运行时仍在 `/lib/php/pecl` 下查找，造成 `Unable to load dynamic library` 警告

本工具通过 **fix → install → restore** 三阶段工作流，同时解决这两个互斥问题。

#### ⚡ 快速开始

```bash
# 下载并赋予执行权限
curl -fsSL https://raw.githubusercontent.com/zerowzsun/script/refs/heads/master/Mac/Homebrew%20PHP%20PECL%20Symbolic%20Link%20Repair%20Tool/fix_pecl_symlink.sh -o fix_pecl_symlink.sh
chmod +x fix_pecl_symlink.sh

# 完整修复流程（以 redis 和 xdebug 为例）
./fix_pecl_symlink.sh fix              # ① 临时解除符号链接
pecl install -f redis                  # ② 强制安装扩展
pecl install -f xdebug                 #    （可连续安装多个）
./fix_pecl_symlink.sh restore          # ③ 恢复符号链接
php -m | grep -E 'redis|xdebug'        # ④ 验证
```

#### 🔧 命令说明

| 命令 | 用途 | 执行时机 |
| :--- | :--- | :--- |
| `./fix_pecl_symlink.sh fix` | 将 pecl 符号链接替换为真实目录，绕过 mkdir Bug | `brew upgrade php` 之后、`pecl install` 之前 |
| `./fix_pecl_symlink.sh restore` | 重建 `/lib/php/pecl` → Cellar 的符号链接 | 所有 `pecl install` 完成之后 |

> **⚠️ 重要提示**：`fix` 和 `restore` 必须成对使用。仅执行 `fix` 而不执行 `restore` 会导致已安装的扩展在 PHP 运行时不可用。

#### 🔄 典型场景

##### 场景一：升级 PHP 后重装扩展

```bash
brew upgrade php
./fix_pecl_symlink.sh fix

# 从备份清单批量重装
cat ~/pecl_extensions_backup.txt | xargs -I {} pecl install -f {}

./fix_pecl_symlink.sh restore
php -m   # 确认所有扩展正常加载
```

##### 场景二：首次安装新扩展

```bash
./fix_pecl_symlink.sh fix
pecl install -f mongodb
./fix_pecl_symlink.sh restore
php --ri mongodb   # 验证扩展信息
```

##### 场景三：不确定当前状态

直接运行 `fix` 即可，脚本会自动检测当前路径状态：
- 若已是真实目录 → 跳过，提示无需修复
- 若是符号链接 → 执行替换
- 若目录不存在 → 自动创建

#### 🛡️ 安全机制

-   **restore 前自动扫描**：检测 Cellar 中是否存在 `.so` 文件，防止在扩展未安装时误恢复空目录链接
-   **交互式确认**：当未发现已安装扩展时，restore 会暂停并要求用户确认，避免意外操作
-   **幂等设计**：重复执行同一命令不会产生副作用或破坏现有配置
-   **非侵入式**：不修改任何 `php.ini` 或 PECL 注册表，仅操作文件系统层面的路径映射

#### 📋 环境要求

-   macOS (Apple Silicon / Intel)
-   Homebrew 安装的 PHP 8.x
-   Bash 4.0+（macOS 自带或 `brew install bash`）

#### ❓ FAQ

**Q: 为什么不能用 `pecl install` 而是必须用 `pecl install -f`？**
A: 因为 PECL 注册表中仍记录着旧版本的安装信息，即使 `.so` 文件已丢失，普通 install 也会认为"已安装"而跳过编译。`-f` 参数强制忽略注册表重新编译。

**Q: restore 之后再次运行 fix 会丢失已安装的扩展吗？**
A: 不会。fix 仅替换 `/lib/php/pecl` 的路径类型，Cellar 中的 `.so` 文件始终不受影响。

**Q: 支持多版本 PHP 共存吗？**
A: 支持。脚本通过 `php -r` 动态获取当前活跃 PHP 的版本号和 API 版本，自动定位对应的 Cellar 目录，与 `brew link php@8.x` 切换的版本保持一致。