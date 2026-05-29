# Script Tool Collection / 脚本工具集

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

日常开发中积累的实用脚本工具合集，涵盖 **macOS 系统运维** 和 **数据备份** 等场景。  
所有脚本均遵循 **即拿即用** 的原则，配置简洁，开箱即用。

## 目录结构

script/
├── Mac/                          # macOS 相关脚本
│   └── Homebrew PHP PECL Symbolic Link Repair Tool/
│       ├── fix_pecl_symlink.sh   # 修复 Homebrew PHP pecl 符号链接 Bug
│       └── readme.md
├── Python/                       # Python 脚本
│   └── Database backup and upload to Qiniu Cloud/
│       ├── back_sql.py           # 数据库备份并上传到七牛云
│       ├── requirements.txt
│       └── readme.md
├── config.example.json           # 配置文件模板
├── .gitignore
└── LICENSE


## 脚本列表

### 1. 修复 Homebrew PHP pecl 符号链接 Bug

- **路径**: `Mac/Homebrew PHP PECL Symbolic Link Repair Tool/fix_pecl_symlink.sh`
- **语言**: Bash
- **适用系统**: macOS（Apple Silicon / Intel）
- **功能**: 自动检测并修复 Homebrew 安装的 PHP 8.x 中 `pecl` 目录因符号链接导致 `mkdir` 失败的问题，将符号链接替换为真实目录并修正权限。
- **快速使用**:
  ```bash
  chmod +x fix_pecl_symlink.sh && ./fix_pecl_symlink.sh
  ```

### 2. 数据库备份并上传到七牛云

- **路径**: `Python/Database backup and upload to Qiniu Cloud/back_sql.py`
- **语言**: Python 3
- **适用系统**: macOS / Linux / Windows
- **功能**: 支持 **MySQL**、**PostgreSQL**、**SQLite** 三种数据库的本地备份，自动上传备份文件到**七牛云存储**，上传完成后自动删除本地临时文件。
- **快速使用**:
  ```bash
  # 1. 安装依赖
  pip install -r requirements.txt

  # 2. 复制配置模板并填入真实信息
  cp config.example.json config.json

  # 3. 运行
  python back_sql.py
  ```

  > 详细说明请参考该目录下的 [readme.md](Python/Database%20backup%20and%20upload%20to%20Qiniu%20Cloud/readme.md)。

## 全局配置

部分脚本会读取根目录下的 `config.json` 作为配置来源。  
请参考 `config.example.json` 创建你的配置文件：

```bash
cp config.example.json config.json
```

> ⚠️ `config.json` 已在 `.gitignore` 中，不会提交到仓库，请放心填写敏感信息。

## 许可证

[MIT](LICENSE) © 2026 zunz