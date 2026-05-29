#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数据库备份并上传到七牛云存储脚本
该脚本用于定期备份数据库并将备份文件上传到七牛云存储，然后删除本地备份文件
"""

import os
import sys
import subprocess
import logging
import time
from datetime import datetime
import qiniu
import argparse


class DatabaseBackupUploader:
    def __init__(self, config):
        """
        初始化备份上传器
        
        Args:
            config (dict): 包含配置信息的字典
        """
        self.db_config = config['database']
        self.qiniu_config = config['qiniu']
        # 兼容 Windows 系统的路径
        if os.name == 'nt':
            self.backup_dir = config.get('backup_dir', 'C:\\Temp\\db_backups')
        else:
            self.backup_dir = config.get('backup_dir', '/tmp/db_backups')
        
        # 创建备份目录
        try:
            os.makedirs(self.backup_dir, exist_ok=True)
        except Exception as e:
            # 尝试使用当前目录作为备份目录
            self.backup_dir = os.path.dirname(os.path.abspath(__file__))
            os.makedirs(self.backup_dir, exist_ok=True)
        
        # 设置日志
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(self.backup_dir, 'backup.log')),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)

    def backup_database(self):
        """
        执行数据库备份
        
        Returns:
            str: 备份文件路径，如果备份失败则返回None
        """
        try:
            db_type = self.db_config['type'].lower()
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            if db_type == 'mysql':
                backup_filename = f"mysql_{self.db_config['database']}_{timestamp}.sql"
                backup_path = os.path.join(self.backup_dir, backup_filename)
                
                # 构建mysqldump命令
                # 尝试找到 mysqldump 可执行文件
                mysqldump_path = 'mysqldump'  # 默认在 PATH 中
                
                # 在 Windows 系统上，尝试常见的 MySQL 安装路径
                if os.name == 'nt':
                    common_paths = [
                        'C:\\Program Files\\MySQL\\MySQL Server 8.4\\bin\\mysqldump.exe',
                        'C:\\Program Files (x86)\\MySQL\\MySQL Server 8.4\\bin\\mysqldump.exe',
                        'C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysqldump.exe',
                        'C:\\Program Files (x86)\\MySQL\\MySQL Server 8.0\\bin\\mysqldump.exe',
                        'C:\\Program Files\\MySQL\\MySQL Server 5.7\\bin\\mysqldump.exe',
                        'C:\\Program Files (x86)\\MySQL\\MySQL Server 5.7\\bin\\mysqldump.exe'
                    ]
                    for path in common_paths:
                        if os.path.exists(path):
                            mysqldump_path = path
                            break
                
                cmd = [
                    mysqldump_path,
                    '-h', self.db_config['host'],
                    '-P', str(self.db_config['port']),
                    '-u', self.db_config['username'],
                    f"-p{self.db_config['password']}",
                    '--single-transaction',
                    '--routines',
                    '--triggers',
                    '--events',
                    self.db_config['database']
                ]
                
                self.logger.info(f"开始备份MySQL数据库: {self.db_config['database']}")
                with open(backup_path, 'w', encoding='utf-8') as f:
                    result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True)
                    
                if result.returncode != 0:
                    self.logger.error(f"MySQL备份失败: {result.stderr}")
                    return None
                    
            elif db_type == 'postgresql':
                backup_filename = f"postgres_{self.db_config['database']}_{timestamp}.sql"
                backup_path = os.path.join(self.backup_dir, backup_filename)
                
                # 设置环境变量
                env = os.environ.copy()
                env['PGPASSWORD'] = self.db_config['password']
                
                # 构建pg_dump命令
                cmd = [
                    'pg_dump',
                    '-h', self.db_config['host'],
                    '-p', str(self.db_config['port']),
                    '-U', self.db_config['username'],
                    '-d', self.db_config['database'],
                    '-Fc'  # 使用自定义格式，也可以使用'-Fp'输出纯文本SQL
                ]
                
                self.logger.info(f"开始备份PostgreSQL数据库: {self.db_config['database']}")
                with open(backup_path, 'wb') as f:
                    result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, 
                                          env=env, text=False)
                    
                if result.returncode != 0:
                    self.logger.error(f"PostgreSQL备份失败: {result.stderr}")
                    return None
                    
            elif db_type == 'sqlite':
                backup_filename = f"sqlite_{os.path.basename(self.db_config['database'])}_{timestamp}.db"
                backup_path = os.path.join(self.backup_dir, backup_filename)
                
                self.logger.info(f"开始备份SQLite数据库: {self.db_config['database']}")
                # 直接复制SQLite数据库文件
                import shutil
                shutil.copy2(self.db_config['database'], backup_path)
                
            else:
                self.logger.error(f"不支持的数据库类型: {db_type}")
                return None
            
            file_size = os.path.getsize(backup_path)
            self.logger.info(f"数据库备份完成: {backup_path}, 文件大小: {file_size} bytes")
            return backup_path
            
        except Exception as e:
            self.logger.error(f"数据库备份过程中发生错误: {str(e)}")
            return None

    def upload_to_qiniu(self, local_file_path):
        """
        上传文件到七牛云存储
        
        Args:
            local_file_path (str): 本地文件路径
            
        Returns:
            bool: 上传成功返回True，否则返回False
        """
        try:
            # 初始化认证
            q = qiniu.Auth(
                self.qiniu_config['access_key'],
                self.qiniu_config['secret_key']
            )
            
            # 生成上传token
            bucket_name = self.qiniu_config['bucket']
            filename = os.path.basename(local_file_path)
            
            # 获取文件夹前缀配置
            prefix = self.qiniu_config.get('prefix', '').strip()
            if prefix and not prefix.endswith('/'):
                prefix = prefix + '/'  # 确保前缀以/结尾
            
            key = prefix + filename  # 使用前缀+文件名作为key
            
            token = q.upload_token(bucket_name, key, 3600)
            
            # 上传文件
            ret, info = qiniu.put_file(token, key, local_file_path)
            
            if ret is not None and ret.get('key') == key:
                self.logger.info(f"文件上传成功: {local_file_path} -> {key}")
                return True
            else:
                self.logger.error(f"文件上传失败: {info}")
                return False
                
        except Exception as e:
            self.logger.error(f"上传到七牛云时发生错误: {str(e)}")
            return False

    def delete_local_file(self, file_path):
        """
        删除本地文件
        
        Args:
            file_path (str): 要删除的文件路径
            
        Returns:
            bool: 删除成功返回True，否则返回False
        """
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                self.logger.info(f"本地文件已删除: {file_path}")
                return True
            else:
                self.logger.warning(f"文件不存在，无法删除: {file_path}")
                return False
        except Exception as e:
            self.logger.error(f"删除本地文件时发生错误: {str(e)}")
            return False

    def run_backup_and_upload(self):
        """
        执行完整的备份和上传流程
        """
        self.logger.info("开始执行数据库备份和上传流程")
        
        # 1. 备份数据库
        backup_file = self.backup_database()
        if not backup_file:
            self.logger.error("数据库备份失败，终止流程")
            return False
        
        # 2. 上传到七牛云
        upload_success = self.upload_to_qiniu(backup_file)
        if not upload_success:
            self.logger.error("上传到七牛云失败，保留本地备份文件")
            return False
        
        # 3. 删除本地文件
        self.delete_local_file(backup_file)
        
        self.logger.info("数据库备份和上传流程完成")
        return True


def main():
    # 默认配置
    default_config = {
        'database': {
            'type': 'mysql',  # 支持 mysql, postgresql, sqlite
            'host': 'localhost',
            'port': 3306,
            'username': 'root',
            'password': 'password',
            'database': 'your_database_name'
        },
        'qiniu': {
            'access_key': 'your_access_key',
            'secret_key': 'your_secret_key',
            'bucket': 'your_bucket_name',
            'prefix': ''  # 七牛云空间中的文件夹前缀，例如：db_backups/
        },
        'backup_dir': '/tmp/db_backups'
    }
    
    parser = argparse.ArgumentParser(description='数据库备份并上传到七牛云存储')
    parser.add_argument('--config-file', type=str, help='配置文件路径 (JSON格式)')
    parser.add_argument('--db-type', type=str, choices=['mysql', 'postgresql', 'sqlite'], 
                       default=default_config['database']['type'], help='数据库类型')
    parser.add_argument('--db-host', type=str, default=default_config['database']['host'], 
                       help='数据库主机')
    parser.add_argument('--db-port', type=int, default=default_config['database']['port'], 
                       help='数据库端口')
    parser.add_argument('--db-user', type=str, default=default_config['database']['username'], 
                       help='数据库用户名')
    parser.add_argument('--db-password', type=str, default=default_config['database']['password'], 
                       help='数据库密码')
    parser.add_argument('--db-name', type=str, default=default_config['database']['database'], 
                       help='数据库名')
    parser.add_argument('--qiniu-access-key', type=str, 
                       default=default_config['qiniu']['access_key'], help='七牛云Access Key')
    parser.add_argument('--qiniu-secret-key', type=str, 
                       default=default_config['qiniu']['secret_key'], help='七牛云Secret Key')
    parser.add_argument('--qiniu-bucket', type=str, 
                       default=default_config['qiniu']['bucket'], help='七牛云存储空间名')
    parser.add_argument('--qiniu-prefix', type=str, 
                       default=default_config['qiniu']['prefix'], help='七牛云空间文件夹前缀')
    parser.add_argument('--backup-dir', type=str, 
                       default=default_config['backup_dir'], help='备份文件存储目录')
    
    args = parser.parse_args()
    
    # 如果指定了配置文件，则从文件加载配置
    if args.config_file:
        import json
        with open(args.config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
    else:
        # 使用命令行参数构建配置
        config = {
            'database': {
                'type': args.db_type,
                'host': args.db_host,
                'port': args.db_port,
                'username': args.db_user,
                'password': args.db_password,
                'database': args.db_name
            },
            'qiniu': {
                'access_key': args.qiniu_access_key,
                'secret_key': args.qiniu_secret_key,
                'bucket': args.qiniu_bucket,
                'prefix': args.qiniu_prefix
            },
            'backup_dir': args.backup_dir
        }
    
    # 创建备份上传器实例并执行
    uploader = DatabaseBackupUploader(config)
    success = uploader.run_backup_and_upload()
    
    # 根据结果设置退出码
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    # 当在脚本所在目录执行时，默认使用同目录下的 config.json
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_config_file = os.path.join(script_dir, 'config.json')
    
    # 如果没有指定配置文件，且默认配置文件存在，则使用默认配置文件
    if len(sys.argv) == 1 and os.path.exists(default_config_file):
        sys.argv.extend(['--config-file', default_config_file])
    
    main()