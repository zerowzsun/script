# 数据库备份脚本

一个简单的数据库备份工具，支持 MySQL、PostgreSQL 和 SQLite，自动将备份文件上传到七牛云存储。

## 功能特性

- 支持 MySQL、PostgreSQL、SQLite 三种数据库
- 自动备份数据库
- 自动上传备份文件到七牛云存储
- 上传成功后自动删除本地备份文件
- 完整的日志记录
- 支持配置文件和命令行参数两种配置方式

## 虚拟环境设置

### Windows 系统

```bash
# 创建虚拟环境
python -m venv venv

# 激活虚拟环境
venv\Scripts\activate
```

### Linux / macOS 系统

```bash
# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate
```

激活虚拟环境后，命令行提示符前会显示 `(venv)`。

## 安装依赖

```bash
pip install -r requirements.txt
```

## 配置方式

### 方式一：使用配置文件

复制 `config.example.json` 为 `config.json`，然后修改配置：

```json
{
  "database": {
    "type": "mysql",
    "host": "127.0.0.1",
    "port": 3306,
    "username": "root",
    "password": "root",
    "database": "root"
  },
  "qiniu": {
    "access_key": "your_access_key",
    "secret_key": "your_secret_key",
    "bucket": "your_bucket_name"
  },
  "backup_dir": "/tmp/db_backups"
}
```

### 方式二：命令行参数

直接通过命令行参数指定配置。

## 使用方法

### 使用默认配置文件

```bash
python back_sql.py
```

### 使用指定配置文件

```bash
python back_sql.py --config-file config.json
```

### 使用命令行参数

```bash
python back_sql.py --db-type mysql --db-host localhost --db-port 3306 --db-user root --db-password password --db-name your_db --qiniu-access-key your_key --qiniu-secret-key your_secret --qiniu-bucket your_bucket
```

## 参数说明

- `--config-file`: 配置文件路径
- `--db-type`: 数据库类型 (mysql/postgresql/sqlite)
- `--db-host`: 数据库主机
- `--db-port`: 数据库端口
- `--db-user`: 数据库用户名
- `--db-password`: 数据库密码
- `--db-name`: 数据库名
- `--qiniu-access-key`: 七牛云 Access Key
- `--qiniu-secret-key`: 七牛云 Secret Key
- `--qiniu-bucket`: 七牛云存储空间名
- `--backup-dir`: 备份文件存储目录