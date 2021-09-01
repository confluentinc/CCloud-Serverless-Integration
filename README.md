# Confluent Cloud Lambda Serverless Integration

### Prerequisites
* Java 11 (*_NOTE_* this is the latest version of Java supported by the AWS Lambda)
* Gradle 7.0
* jq
* A user account in [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
* Local installation of [Confluent Cloud](https://docs.confluent.io/ccloud-cli/current/install.html) CLI v1.36.0 or later
* A user account in [AWS](https://aws.amazon.com/)
* Local installation of [AWS CLI](https://aws.amazon.com/cli/) version 2.2.30


### Setup

To run this demo, you'll need a Kafka cluster, a ksqlDB application and two datagen source connectors.  The source connectors will generate two event streams that the ksqlDB will join and write
out to a topic, `user_trades`.  Then an AWS Lambda, using the `user_trades` as an event source will take some additional action and produce results back to the Kafka cluster in Confluent Cloud.
Using a lambda in this way is a proxy for a User Defined Function (UDF) with ksqlDB in Confluent Cloud.

But before you run the demo, you'll need to set up some resources on Confluent Cloud and AWS.  We've provided some scripts in this repository to keep the amount of work you need to do
at a minimum, but you need to the setup portion first.

The following sections provide details for setting up a cluster on Confluent Cloud and creating an AWS Lambda to process events from ksqlDB

### TLDR;

TODO fill out this section with just the commands needed to get up and running 

### Provisioning a Kafka Cluster, ksqlDB application, and datagen source connectors

**_NOTE:_** This part assumes you have already set up an account on [Confluent CLoud](https://confluent.cloud/) and you've installed the [Confluent Cloud CLI](https://docs.confluent.io/ccloud-cli/current/install.html).

To create the Kafka cluster, ksqlDB application, and the datagen sink connectors you'll run this command from the base directory of this repository

```shell
 ./ccloud-build-app.sh
```
           
The [ccloud-build-app script](ccloud-build-app.sh) script performs several tasks which I'll highlight here. If you want to skip the details, once the script complete the next step you'll need to take is specified in the [AWS Lambda and required resources](#create-the-aws-lambda) section.

**_NB: The script performs these steps, the details are here for you to follow along with what's happening while it runs_**

1. It creates a Kafka cluster (with the required ACLs) and a ksqlDB application on Confluent Cloud.  The script waits for the brokers and the ksqlDB application to be in a runnable state before moving on.
Note that the amount of time for the ksqlDB application to get in a runnable state takes a few minutes, but the script will provide the status.
   1. When the cluster is running you'll see some output like this
     ```shell
            ....
            +------------------+------------+------------------+----------+---------------+---------+
            User:312125      | ALLOW      | IDEMPOTENT_WRITE | CLUSTER  | kafka-cluster | LITERAL
            ServiceAccountId | Permission | Operation | Resource |     Name      |  Type
            +------------------+------------+-----------+----------+---------------+---------+
            User:312125      | ALLOW      | DESCRIBE  | CLUSTER  | kafka-cluster | LITERAL
            Set API Key "JOMV3TUYDUP4JKWX" as the active API key for "lkc-jd17p".

            Client configuration file saved to: stack-configs/java-service-account-NNNNNN.config

      ```
      The `NNNN` on the `java-service-account` configuration file contains the credentials created during the cluster and ksqlDB creation process.  You won't have to work with it directly, but the remaining stages of the `ccloud-build-app` script will use it in subsequent steps, that will cover soon.
2. Next, the script will wait for the ksqlDB application to come online, you'll see something like this
   ```shell
      Now waiting up to 720 seconds for the ksqlDB cluster to be UP
   ```
    Once ksqlDB is operational you'll see this line in the console
    ```shell
     Successfully created ksqlDB
    ```  
3. Then the script creates the required topics.  This part goes quickly, and you'll see something similar to this in the console:
    ```shell
      Now creating topics
      Created topic "stocktrade".
      Created topic "stock_users".
      Created topic "user_trades".
      Created topic "trade-settlements".
    ```  
4. The next step the script performs is to create JSON files needed to create datagen connectors on Confluent Cloud and a JSON file for setting up connection credentials so the AWS Lambda 
can use the `user_trades` topic as an event source and produce back to Kafka.  
To create the files, the script executes a [custom task, propsToJson](https://github.com/confluentinc/CCloud-Serverless-Integration/blob/main/build.gradle#L95-L145)
file. 
 The specific files created (ignored by the repository) are
   1. `src/main/resources/stocktrade-dategen.json`
   2. `src/main/resources/user-datagen.json`
   3. `aws-cli/aws-ccloud-creds.json`
 
   You'll see something like this on the console for this step
   ```shell
    Now generating JSON properties needed for creating datagen connectors and AWS secrets manager
    For this the script is using custom gradle task 'propsToJson'
    The JSON properties for the datagen connectors are
    src/main/resources/stocktrade-datagen.json
    src/main/resources/user-datagen.json
    The JSON file for AWS securitymanager is aws-cli/aws-ccloud-creds.json

    BUILD SUCCESSFUL in 929ms
   ```   
   
5. Next the script create the datagen source connectors which create the event streams which drives the demo, you'll see something like this:
   ```shell
    Now creating the stocktrade datagen connector
    Created connector StockTradeDatagen lcc-wq805
    Now creating the user datagen connector
    Created connector UsersDatagen lcc-kd72g
   ```
    The script waits here until both connectors are in a running state:
   ```shell
     Connector src/main/resources/stocktrade-datagen.json (StockTradeDatagen) is RUNNING
     Connector src/main/resources/user-datagen.json (UsersDatagen) is RUNNING
    ```  
6. The final step the script performs is to upload [the sql statements](src/main/resources/stocktrade-statements.sql) for ksqlDB to execute and the following appears on the console
   <details>
   <summary>Click to view sql statements upload results</summary>
   
   ```shell
    Submit KSQL queries for running the AWS Lambda demo from src/main/resources/stocktrade-statements.sql
    CREATE STREAM STOCKTRADE (side varchar,quantity int,symbol varchar,price int,account varchar,userid varchar) with (kafka_topic = 'stocktrade',value_format = 'json');
    [{"@type":"currentStatus","statementText":"CREATE STREAM STOCKTRADE (SIDE STRING, QUANTITY INTEGER, SYMBOL STRING, PRICE INTEGER, ACCOUNT STRING, USERID STRING) WITH (KAFKA_TOPIC='stocktrade', KEY_FORMAT='KAFKA', VALUE_FORMAT='JSON');","commandId":"stream/`STOCKTRADE`/create","commandStatus":{"status":"SUCCESS","message":"Stream created","queryId":null},"commandSequenceNumber":2,"warnings":[]}]

    CREATE TABLE STOCK_USERS (userid varchar primary key, registertime BIGINT, regionid varchar ) with ( kafka_topic = 'stock_users', value_format = 'json');
    [{"@type":"currentStatus","statementText":"CREATE TABLE STOCK_USERS (USERID STRING PRIMARY KEY, REGISTERTIME BIGINT, REGIONID STRING) WITH (KAFKA_TOPIC='stock_users', KEY_FORMAT='KAFKA', VALUE_FORMAT='JSON');","commandId":"table/`STOCK_USERS`/create","commandStatus":{"status":"SUCCESS","message":"Table created","queryId":null},"commandSequenceNumber":4,"warnings":[]}]

    CREATE STREAM USER_TRADES WITH (kafka_topic = 'user_trades' ) AS SELECT s.userid as USERID,u.regionid,quantity,symbol,price,account,side FROM STOCKTRADE s LEFT JOIN STOCK_USERS u on s.USERID = u.userid;
    [{"@type":"currentStatus","statementText":"CREATE STREAM USER_TRADES WITH (KAFKA_TOPIC='user_trades', PARTITIONS=6, REPLICAS=3) AS SELECT\n  S.USERID USERID,\n  U.REGIONID REGIONID,\n  S.QUANTITY QUANTITY,\n  S.SYMBOL SYMBOL,\n  S.PRICE PRICE,\n  S.ACCOUNT ACCOUNT,\n  S.SIDE SIDE\nFROM STOCKTRADE S\nLEFT OUTER JOIN STOCK_USERS U ON ((S.USERID = U.USERID))\nEMIT CHANGES;","commandId":"stream/`USER_TRADES`/create","commandStatus":{"status":"SUCCESS","message":"Created query with ID CSAS_USER_TRADES_5","queryId":"CSAS_USER_TRADES_5"},"commandSequenceNumber":6,"warnings":[]}]
   ``` 
   </details>
 
At this point, you'll have a running Kafka cluster, datagen connectors, and a ksqlDB application performing a join on the two generated event streams.  You can log into the Confluent Cloud Console
and click on `ksqlDB` on the left.  Then click on `Streams` -> `Query USER_TRADES` to observe the results.


### Create the AWS Lambda

To create the AWS Lambda it is assumed that you've already set up [local configuration for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html). 
Then you'll run a script which will set up all the AWS resources and create a Lambda instance for you.

1. In the `aws-cli` directory save the file [configs.orig.sh](aws-cli/configs.orig.sh) as `configs.sh`
```shell
 cat aws-cli/configs.orig.sh > cofigs.sh
```
The project will ignore the `configs.sh` file.  It's used to provide environment 
replacements needed for some AWS commands. Most of the variables are already set, but you'll need to update the `PROFILE` variable with the profile name to use, `default` if you are not sure.
Then update the `BOOTSTRAP_SERVERS` variable with the value contained in the `stack-configs/java-service-account-*.config` file you created in the previous step.  **IMPORTANT! The name for the credentials `CREDS_NAME="CCloudLambdaCredentials"` is hard coded in the Java Lambda code.  I realize this isn't ideal, and I'm working towards making this dynamic, but
in the meantime, DON'T CHANGE THIS VALUE**
 


2. From the root of the repository run 
```shell
 ./gradlew clean build buildZip 
````
3. Run the [aws-create-all](aws-cli/aws-create-all.sh) script in the `aws-cli` directory. Note that the script needs to be run from the `aws-cli` directory
  ```shell
  (cd aws-cli && ./aws-create-all.sh) 
   ````
The script will prompt you to enter `y` or `n` to confirm your choice.  

4. The following AWS components get created:
   1. An AWS Secrets Manger with all the connection info to connect to Confluent Cloud
   2. An AWS Role with an attached policy with all the required permissions for the Lambda to execute properly
   3. Finally, an AWS Lambda instance with an event sources mapped to the Confluent Cloud topic `user_trades` which contains the results of the ksqlDB join

The script output will resemble this:
<details>
<summary> Click to view script output</summary>

```json
  Create the AWS secrets config to hold connection information
{
    "ARN": "arn:aws:secretsmanager:us-west-2:343223495109:secret:CCloudLambdaCredentials-r4ZblI",
    "Name": "CCloudLambdaCredentials",
    "VersionId": "c90d898c-9e5c-4c64-b82d-47dd07fb7b95"
}
Create the role needed for the lambda
{
    "Role": {
        "Path": "/",
        "RoleName": "CCloud-lambda-role",
        "RoleId": "AROAU72NW5HCWTBO5LDHI",
        "Arn": "arn:aws:iam::343223495109:role/CCloud-lambda-role",
        "CreateDate": "2021-08-31T13:52:30+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }
    }
}
Add policy file inline (inline policy means other roles can't reuse the policy by AWS arn)
Waiting for 10 seconds for the role and policy to sync
Create the lambda
{
    "FunctionName": "CCloudLambdaIntegrationFunction",
    "FunctionArn": "arn:aws:lambda:us-west-2:343223495109:function:CCloudLambdaIntegrationFunction",
    "Runtime": "java11",
    "Role": "arn:aws:iam::343223495109:role/CCloud-lambda-role",
    "Handler": "io.confluent.developer.CCloudStockRecordHandler::handleRequest",
    "CodeSize": 35995756,
    "Description": "",
    "Timeout": 600,
    "MemorySize": 512,
    "LastModified": "2021-08-31T13:52:47.006+0000",
    "CodeSha256": "B0RSUj8X9Jk+JlfcmbKoJiDe9tr+fK9H4Vv5gYhAeSk=",
    "Version": "$LATEST",
    "TracingConfig": {
        "Mode": "PassThrough"
    },
    "RevisionId": "afaef24a-b814-4113-8ddd-998a0d9ffc64",
    "State": "Active",
    "LastUpdateStatus": "Successful",
    "PackageType": "Zip"
}
Adding a CCloud topic as an event source
{
    "UUID": "4f3329bc-f439-42b4-8292-6f6e8fa2ff92",
    "StartingPosition": "TRIM_HORIZON",
    "BatchSize": 100,
    "FunctionArn": "arn:aws:lambda:us-west-2:343223495109:function:CCloudLambdaIntegrationFunction",
    "LastModified": "2021-08-31T09:52:48.694000-04:00",
    "LastProcessingResult": "No records processed",
    "State": "Creating",
    "StateTransitionReason": "USER_INITIATED",
    "Topics": [
        "user_trades"
    ],
    "SourceAccessConfigurations": [
        {
            "Type": "BASIC_AUTH",
            "URI": "arn:aws:secretsmanager:us-west-2:343223495109:secret:CCloudLambdaCredentials"
        }
    ],
    "SelfManagedEventSource": {
        "Endpoints": {
            "KAFKA_BOOTSTRAP_SERVERS": [
                "pkc-pgq85.us-west-2.aws.confluent.cloud:9092"
            ]
        }
    }
}
```
</details> 

5. To confirm the lambda is working
   1. Log into the AWS console and select the `Lambda` service
   2. Then `Functions` on the left-hand side menu
   3. Select the `CCloudLambdaIntegrationFunction`
   4. Then select `Monitor` tab.  If there aren't any logs present, wait a few minutes then select a log file and inspect the contents
   
### Run the ksqlDB queries to process Lambda results

Next you'll run a series of queries in the [lambda-processing-statements.sql](src/main/resources/lambda-processing-statements.sql) file so the ksqlDB application can provide some 
analysis of the results from the Lambda. 

To do this first CD back into the base directory of the repository.  
Then run the [ccloud-run-lambda-sql](ccloud-run-lamba-sql.sh) script from the root of the project

```shell
 ./ccloud-run-lambda-sql.sh
```

The results of loading these sql statements will look like (details truncated for clarity)
<details>
<summary>Click to view sql statement upload results</summary>

```shell
 CREATE STREAM TRADE_SETTLEMENT (user varchar, symbol varchar, amount double, disposition varchar, reason varchar, timestamp BIGINT) with (kafka_topic = 'trade-settlements', value_format = 'PROTOBUF', timestamp = 'timestamp');
 [{"@type":"currentStatus","statementText":"CREATE STREAM TRADE_SETTLEMENT....

 CREATE TABLE COMPLETED_PER_MINUTE AS SELECT symbol, count(*) AS num_completed FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second) WHERE disposition like '%Completed%' GROUP BY symbol;
 [{"@type":"currentStatus","statementText":"CREATE TABLE COMPLETED_PER_MINUTE...

 CREATE TABLE PENDING_PER_MINUTE AS SELECT symbol, count(*) AS num_pending FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second) WHERE disposition like '%Pending%' GROUP BY symbol;
 [{"@type":"currentStatus","statementText":"CREATE TABLE PENDING_PER_MINUTE...

 CREATE TABLE FLAGGED_PER_MINUTE AS SELECT symbol, count(*) AS num_flagged FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second) WHERE disposition like '%SEC%' GROUP BY symbol;
 [{"@type":"currentStatus","statementText":"CREATE TABLE FLAGGED_PER_MINUTE...

 CREATE TABLE REJECTED_PER_MINUTE AS SELECT symbol, count(*) AS num_rejected FROM TRADE_SETTLEMENT WINDOW TUMBLING (size 60 second) WHERE disposition like '%Rejected%' GROUP BY symbol;
 [{"@type":"currentStatus","statementText":"CREATE TABLE REJECTED_PER_MINUTE...
 ```
</details>


### Clean Up

Since both the Confluent Cloud and AWS resources cost money, it's important to fully remove all compents in both cloud environments.

#### Remove up all AWS resources
To remove all the AWS components you'll run the [aws-delete-all.sh](aws-cli/aws-delete-all.sh) script.
1. Run this commands to clean up the AWS components
    ```shell 
     (cd aws-cli && ./aws-delete-all.sh) 
    ```  
#### Remove up all Confluent Cloud resources
To remove the Confluent Cloud components do the following:
1. Open a new terminal window and go to the root directory of the repository
2. Copy the numbers from the `stack-configs/java-service-account-NNNNNN.config` file. 
   Then the following commands with the service account number from the file:
```shell
 source ./ccloud_library.sh
 ccloud::destroy_ccloud_stack NNNNNNNN
```
     
    