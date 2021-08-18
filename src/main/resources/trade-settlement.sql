-- noinspection SqlDialectInspectionForFile
-- noinspection SqlNoDataSourceInspectionForFile

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
