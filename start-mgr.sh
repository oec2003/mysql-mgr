#!/bin/bash

# 等待所有MySQL实例启动完成
sleep 30

# 在主节点上引导组并启动组复制
docker exec mysql-master mysql -uroot -prootpassword -e "
  CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
  SET GLOBAL group_replication_bootstrap_group=ON;
  START GROUP_REPLICATION;
  SET GLOBAL group_replication_bootstrap_group=OFF;
  SELECT * FROM performance_schema.replication_group_members;"

# 等待主节点组复制启动完成
sleep 20

# 在从节点上启动组复制
docker exec mysql-slave-1 mysql -uroot -prootpassword -e "
  CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
  START GROUP_REPLICATION;
  SELECT * FROM performance_schema.replication_group_members;"

docker exec mysql-slave-2 mysql -uroot -prootpassword -e "
  CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';
  START GROUP_REPLICATION;
  SELECT * FROM performance_schema.replication_group_members;"

# 检查MGR状态
sleep 5
echo "检查MGR集群状态:"
docker exec mysql-master mysql -uroot -prootpassword -e "SELECT * FROM performance_schema.replication_group_members;"