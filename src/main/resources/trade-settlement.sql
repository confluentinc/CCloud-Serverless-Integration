
CREATE STREAM TRADE_SETTLEMENT (
      user varchar,
      symbol varchar,
      amount double,
      disposition varchar,
      reason varchar,
      timestamp BIGINT
    ) with (
        kafka_topic = 'trade-settlements',
        value_format = 'PROTOBUF',
        timestamp = 'timestamp' 
    );

CREATE TABLE COMPLETED_PER_MINUTE AS
   SELECT
       symbol,
       count(*) AS num_completed
 FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second)
 WHERE disposition like '%Completed%'
 GROUP BY symbol;


CREATE TABLE PENDING_PER_MINUTE AS
SELECT
    symbol,
    count(*) AS num_pending
FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second)
WHERE disposition like '%Pending%'
GROUP BY symbol;

CREATE TABLE FLAGGED_PER_MINUTE AS
SELECT
    symbol,
    count(*) AS num_flagged
FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second)
WHERE disposition like '%SEC%'
GROUP BY symbol;

CREATE TABLE REJECTED_PER_MINUTE AS
SELECT
    symbol,
    count(*) AS num_rejected
FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second)
WHERE disposition like '%Rejected%'
GROUP BY symbol;