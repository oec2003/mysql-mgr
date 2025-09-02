#!/bin/bash

echo "===== 启动 MySQL MGR + ProxySQL 集群 ====="

# 启动 docker-compose
echo "启动所有服务..."
docker-compose up -d

echo "等待 MySQL 实例启动完成..."
sleep 30

# 检查 MySQL 服务状态
echo "检查 MySQL 服务状态..."
for service in mysql-master mysql-slave-1 mysql-slave-2; do
    echo "检查 $service..."
    docker exec $service mysqladmin ping -uroot -prootpassword --silent
    if [ $? -eq 0 ]; then
        echo "✓ $service 已启动"
    else
        echo "✗ $service 启动失败"
        exit 1
    fi
done

# 在主节点上引导组并启动组复制
echo "配置 MySQL Group Replication..."
docker exec mysql-master mysql -uroot -prootpassword -e "
  CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
  SET GLOBAL group_replication_bootstrap_group=ON;
  START GROUP_REPLICATION;
  SET GLOBAL group_replication_bootstrap_group=OFF;
  SELECT * FROM performance_schema.replication_group_members;"

# 等待主节点组复制启动完成
echo "等待主节点 MGR 启动完成..."
sleep 20

# 在从节点上启动组复制
echo "启动从节点 MGR..."
for slave in mysql-slave-1 mysql-slave-2; do
    echo "配置 $slave..."
    docker exec $slave mysql -uroot -prootpassword -e "
      CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
      START GROUP_REPLICATION;"
done

# 等待所有节点加入集群
echo "等待所有节点加入 MGR 集群..."
sleep 15

# 检查MGR状态
echo "检查 MGR 集群状态:"
docker exec mysql-master mysql -uroot -prootpassword -e "SELECT * FROM performance_schema.replication_group_members;"

# 等待 ProxySQL 启动
echo "等待 ProxySQL 启动..."
sleep 10

# 检查 ProxySQL 状态
echo "检查 ProxySQL 状态..."
docker exec proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "SELECT @@version_comment LIMIT 1;"
if [ $? -eq 0 ]; then
    echo "✓ ProxySQL 已启动"
else
    echo "✗ ProxySQL 启动失败"
    exit 1
fi

# 配置 ProxySQL
echo "配置 ProxySQL..."
docker exec proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin < /etc/proxysql/init-proxysql.sql

# 等待配置生效
sleep 5

# 配置监控参数
echo "配置 ProxySQL 监控参数..."
docker exec proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_password';
UPDATE global_variables SET variable_value='2000' WHERE variable_name='mysql-monitor_connect_interval';
UPDATE global_variables SET variable_value='1000' WHERE variable_name='mysql-monitor_ping_interval';
UPDATE global_variables SET variable_value='1000' WHERE variable_name='mysql-monitor_read_only_interval';
UPDATE global_variables SET variable_value='true' WHERE variable_name='mysql-monitor_enabled';
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;"

# 配置 MGR 监控
echo "配置 ProxySQL MGR 监控..."
docker exec proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin < /etc/proxysql/setup-mgr-monitoring.sql

# 验证 ProxySQL 配置
echo "验证 ProxySQL 配置..."
docker exec proxysql mysql -h127.0.0.1 -P6032 -uradmin -pradmin -e "
SELECT hostgroup_id, hostname, port, status, weight FROM mysql_servers ORDER BY hostgroup_id, hostname;
SELECT username, default_hostgroup, max_connections, active FROM mysql_users;
SELECT rule_id, match_pattern, destination_hostgroup, apply FROM mysql_query_rules WHERE active=1 ORDER BY rule_id;"

echo ""
echo "===== 集群启动完成 ====="
echo "MySQL MGR 集群端口:"
echo "  - mysql-master:  3306"
echo "  - mysql-slave-1: 3307"
echo "  - mysql-slave-2: 3308"
echo ""
echo "ProxySQL 连接信息:"
echo "  - MySQL 接口:  localhost:6033"
echo "  - 管理接口:    localhost:6032"
echo "  - Web 界面:    http://localhost:6080"
echo ""
echo "连接示例:"
echo "  mysql -h127.0.0.1 -P6033 -uroot -prootpassword"
echo "  mysql -h127.0.0.1 -P6033 -uapp_user -papp_password"
echo ""
echo "管理 ProxySQL:"
echo "  mysql -h127.0.0.1 -P6032 -uradmin -pradmin"
