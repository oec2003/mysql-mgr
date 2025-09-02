-- 配置 ProxySQL 的 MySQL Group Replication 监控

-- 配置监控用户（需要在MySQL服务器上先创建这个用户）
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_password';

-- 配置监控间隔
UPDATE global_variables SET variable_value='2000' WHERE variable_name='mysql-monitor_connect_interval';
UPDATE global_variables SET variable_value='2000' WHERE variable_name='mysql-monitor_ping_interval';
UPDATE global_variables SET variable_value='1000' WHERE variable_name='mysql-monitor_read_only_interval';

-- 启用 Group Replication 监控
UPDATE global_variables SET variable_value='true' WHERE variable_name='mysql-monitor_enabled';

-- 加载变量到运行时
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;

-- 添加 Group Replication 主机组配置
INSERT INTO mysql_group_replication_hostgroups (writer_hostgroup, backup_writer_hostgroup, reader_hostgroup, offline_hostgroup, active, max_writers, writer_is_also_reader, max_transactions_behind, comment) VALUES
(0, 4, 1, 3, 1, 1, 0, 100, 'MGR cluster');

-- 加载主机组配置
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

-- 显示监控状态
SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 10;
SELECT * FROM monitor.mysql_server_ping_log ORDER BY time_start_us DESC LIMIT 10;
SELECT * FROM monitor.mysql_server_read_only_log ORDER BY time_start_us DESC LIMIT 10;
