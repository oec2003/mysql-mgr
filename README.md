# MySQL MGR 单主模式 Docker 部署指南

本指南介绍如何使用 Docker Compose 部署 MySQL Group Replication (MGR) 单主模式集群。

## 环境要求

- Docker 19.03+
- Docker Compose 1.27+
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间

## 文件结构

```
./
├── docker-compose.yml          # Docker Compose 配置文件
├── mysql-init-scripts/         # MySQL 初始化脚本目录
│   ├── 01-create-replication-user.sql  # 创建复制用户脚本
│   └── 02-install-plugin.sql   # 安装组复制插件脚本
└── start-mgr.sh               # 启动 MGR 的脚本
```

## 快速开始

### 1. 启动 MySQL 容器

```bash
# 确保脚本有执行权限
chmod +x start-mgr.sh

# 启动 Docker 容器
docker-compose up -d
```

### 2. 启动 MGR 集群

等待所有 MySQL 容器启动完成后（约 30 秒），运行以下命令启动 MGR：

```bash
./start-mgr.sh
```

## 集群信息

- **主节点**：mysql-master (端口: 3306)
- **从节点1**：mysql-slave-1 (端口: 3307)
- **从节点2**：mysql-slave-2 (端口: 3308)
- **组复制端口**：33061, 33062, 33063
- **组名**：aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee

## 连接到 MySQL 实例

```bash
# 连接到主节点
mysql -h127.0.0.1 -P3306 -uroot -prootpassword

# 连接到从节点1
mysql -h127.0.0.1 -P3307 -uroot -prootpassword

# 连接到从节点2
mysql -h127.0.0.1 -P3308 -uroot -prootpassword
```

## 验证 MGR 状态

连接到任意节点后，执行以下 SQL 查询来验证 MGR 状态：

```sql
SELECT * FROM performance_schema.replication_group_members;
```

正常情况下，应该看到三个节点都处于 ONLINE 状态，其中一个节点的 `MEMBER_ROLE` 为 PRIMARY，其他两个为 SECONDARY。

## 测试主从切换

要测试主从切换，可以停止当前的主节点：

```bash
docker stop mysql-master
```

然后查看集群状态，应该会看到一个新的主节点被自动选举出来：

```bash
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "SELECT * FROM performance_schema.replication_group_members;"
```

## 清理环境

```bash
docker-compose down -v
```

## 注意事项

1. 生产环境中，应该使用更安全的密码，并避免在脚本中明文存储密码。
2. 生产环境中，应该配置适当的资源限制和监控。
3. 本配置使用了固定的组名，生产环境中应该使用随机生成的 UUID。
4. 本配置未启用 SSL，生产环境中应该启用 SSL 加密通信。
5. 本配置未配置自动备份，生产环境中应该配置定期备份。

## 故障排查

1. 如果容器无法启动，检查 Docker 日志：
   ```bash
   docker-compose logs
   ```

2. 如果 MGR 无法启动，检查 MySQL 错误日志：
   ```bash
   docker exec mysql-master cat /var/log/mysql/error.log
   ```

3. 如果节点无法加入组，确保网络连接正常，并检查组复制配置是否正确。

4. 如果需要重新初始化集群，请先清理环境，然后重新启动容器和 MGR。
