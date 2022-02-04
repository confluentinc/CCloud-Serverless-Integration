CREATE STREAM STOCKTRADE (side varchar,quantity int,symbol varchar,price int,account varchar,userid varchar) with (kafka_topic = 'stocktrade',value_format = 'JSON');
CREATE TABLE users (userid varchar primary key, registertime BIGINT, regionid varchar ) with ( kafka_topic = 'users', value_format = 'JSON');
CREATE STREAM USER_TRADES WITH (kafka_topic = 'user_trades', value_format = 'AVRO' ) AS SELECT s.userid as USERID,u.regionid,quantity,symbol,price,account,side FROM STOCKTRADE s LEFT JOIN users u on s.USERID = u.userid;
