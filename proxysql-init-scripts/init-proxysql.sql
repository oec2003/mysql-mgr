-- ProxySQL 初始化脚本

-- 删除默认配置并重新配置
DELETE FROM mysql_servers;
DELETE FROM mysql_users;
DELETE FROM mysql_query_rules;
DELETE FROM mysql_replication_hostgroups;

-- 添加 MySQL 服务器
INSERT INTO mysql_servers(hostgroup_id,hostname,port,weight,status,comment) VALUES
(0,'mysql-master',3306,1000,'ONLINE','MySQL Master'),
(1,'mysql-slave-1',3306,900,'ONLINE','MySQL Slave 1'),
(1,'mysql-slave-2',3306,900,'ONLINE','MySQL Slave 2');

-- 配置复制主机组（用于读写分离）
INSERT INTO mysql_replication_hostgroups (writer_hostgroup,reader_hostgroup,comment,check_type) VALUES
(0,1,'MGR Cluster','read_only');

-- 添加用户
INSERT INTO mysql_users(username,password,default_hostgroup,max_connections,active) VALUES
('root','rootpassword',0,1000,1),
('app_user','app_password',0,200,1);

-- 配置查询路由规则
INSERT INTO mysql_query_rules (rule_id,active,match_pattern,destination_hostgroup,apply,comment) VALUES
(1,1,'^SELECT.*FOR UPDATE$',0,1,'SELECT FOR UPDATE to writer'),
(2,1,'^SELECT.*LOCK IN SHARE MODE$',0,1,'SELECT LOCK IN SHARE MODE to writer'),
(3,1,'^SELECT',1,1,'SELECT to reader'),
(4,1,'^INSERT|^UPDATE|^DELETE|^REPLACE|^CREATE|^DROP|^ALTER|^TRUNCATE|^BEGIN|^START|^COMMIT|^ROLLBACK',0,1,'DML/DDL to writer'),
(5,1,'^SHOW\s+(MASTER|SLAVE)\s+STATUS',0,1,'SHOW STATUS to writer'),
(6,1,'^SHOW\s+PROCESSLIST',0,1,'SHOW PROCESSLIST to writer');

-- 加载配置到运行时
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
LOAD MYSQL VARIABLES TO RUNTIME;
LOAD ADMIN VARIABLES TO RUNTIME;

-- 保存配置到磁盘
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL USERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
SAVE MYSQL VARIABLES TO DISK;
SAVE ADMIN VARIABLES TO DISK;

-- 显示配置状态
SELECT * FROM mysql_servers ORDER BY hostgroup_id, hostname;
SELECT * FROM mysql_users;
SELECT * FROM mysql_query_rules ORDER BY rule_id;
SELECT * FROM mysql_replication_hostgroups;
