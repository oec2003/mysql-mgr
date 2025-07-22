#!/bin/bash

# 测试MGR集群功能的脚本

echo "===== 测试数据复制功能 ====="
# 在主节点上创建测试表并插入数据
docker exec mysql-master mysql -uroot -prootpassword -e "
  CREATE DATABASE IF NOT EXISTS testdb;
  USE testdb;
  CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY, name VARCHAR(50), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
  INSERT INTO test_table (id, name) VALUES (1, 'Test from master');
  SELECT * FROM test_table;"

# 等待数据复制
sleep 5

# 在从节点上查询数据
echo "\n在从节点1上查询数据:"
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "USE testdb; SELECT * FROM test_table;"

echo "\n在从节点2上查询数据:"
docker exec mysql-slave-2 mysql -uroot -prootpassword -e "USE testdb; SELECT * FROM test_table;"

echo "\n===== 测试写入分离功能 ====="
# 尝试在从节点上写入数据（应该会失败，因为是单主模式）
echo "尝试在从节点上写入数据（应该会失败）:"
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "USE testdb; INSERT INTO test_table (id, name) VALUES (2, 'Test from slave');"

echo "\n===== 测试主从切换功能 ====="
# 获取当前主节点信息
echo "当前主节点信息:"
docker exec mysql-master mysql -uroot -prootpassword -e "SELECT member_id, member_host, member_role FROM performance_schema.replication_group_members;"

# 停止当前主节点
echo "\n停止当前主节点..."
docker stop mysql-master

# 等待新主节点选举
sleep 20

# 查看新的主节点信息
echo "\n新的主节点信息:"
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "SELECT member_id, member_host, member_role FROM performance_schema.replication_group_members;"

# 在新主节点上写入数据
echo "\n在新主节点上写入数据:"
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "USE testdb; INSERT INTO test_table (id, name) VALUES (3, 'Test after failover'); SELECT * FROM test_table;"

# 在另一个从节点上查询数据
echo "\n在另一个从节点上查询数据:"
docker exec mysql-slave-2 mysql -uroot -prootpassword -e "USE testdb; SELECT * FROM test_table;"

# 重启之前的主节点
echo "\n重启之前的主节点..."
docker start mysql-master
sleep 30

# 查看集群状态
echo "\n集群最终状态:"
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "SELECT member_id, member_host, member_role FROM performance_schema.replication_group_members;"

# 在重启的节点上查询数据
echo "\n在重启的节点上查询数据:"
docker exec mysql-master mysql -uroot -prootpassword -e "USE testdb; SELECT * FROM test_table;"