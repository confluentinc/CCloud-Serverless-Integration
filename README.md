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

#### Provisioning a Kafka Cluster, ksqlDB application, and datagen source connectors

*_NOTE_*: This part assumes you have already set up an account on [Confluent CLoud](https://confluent.cloud/) and you've installed the [Confluent Cloud CLI](https://docs.confluent.io/ccloud-cli/current/install.html).

To create the Kafka cluster, ksqlDB application, and the datagen sink connectors you'll run this command from the base directory of this repository

```shell
 ./ccloud-build-app.sh
```
           
The [ccloud-build-app script](ccloud-build-app.sh) script performs several tasks which I'll highlight here. If you want to skip the details, once the script complete the next step you'll need to take is specified in the [AWS Lambda and required resources](#create-the-aws-lambda) section.
*_PLEASE NOTE: the script performs these steps, the details are here for you to follow along with what's happening while it runs_*

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
To create the files, the script executes a [custom task, propsToJson](https://github.com/confluentinc/CCloud-Serverless-Integration/blob/final-automation-changes-readme-updates/build.gradle#L95-L145)
file. 
 The specific files created (ignored by the repository) are
   1. `src/main/resources/stocktrade-dategen.json`
   2. `src/main/resources/user-datagen.json`
   3. `aws-cli/aws-ccloud-creds.json`

Now that we have the cloud stack resources in place from project root run `./gradlew propsToJson` this will create the following:

* JSON properties file, `aws-cli/aws-ccloud-creds.json` (git ignores this file) for creating an AWS secret containing credentials for connecting to Confluent Cloud
* Two JSON files for creating Datagen source connectors needed for the demo
  * `src/main/resources/stocktrade-datagen.json` used to generate stock trade date
  * `src/main/resources/user-datagen.json` used to generate users
  * ksqlDB will join the users to a stock trade by user-id and those results are written to a topic which will be the event source for the lambda

Your next steps are to create the needed topics and then start the datagen source connectors:
1. Run this command to create the topics `for topic in stocktrade stock_users user_trades trade-settlements; do ccloud kafka topic create $topic; done`
2. Start the stocktrade datagen with `ccloud connector create --config src/main/resources/stocktrade-datagen.json`
3. Start the users datagen with `ccloud connector create --config src/main/resources/user-datagen.json`

After a few minutes confirm the connectors are running with `ccloud connector list`

Then navigate to Confluent Cloud click on ksqlDB then `Editor` then copy the contents of `src/main/resources/stocktrade-users.sql` ksqlDB will run this query to create an 
event stream of user-stocktrades which will trigger the AWS Lambda into action

#### Create the AWS Lambda

To create the AWS Lambda it is assumed that you've already set up [local configuration for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html). 
Then you'll run a script which will set up all the AWS resources and create a Lambda instance for you.

1. In the `aws-cli` directory save the file `configs.orig.sh` as `configs.sh`.  The project will ignore the `configs.sh` file.  It's used to provide environment 
replacements needed for some AWS commands. Most of the variables are already set, but you'll need to update the `PROFILE` variable with the profile name to use, `default` if you are not sure.
Then update the `BOOTSTRAP_SERVERS` variable with the value contained in the `stack-configs/java-service-account-*.config` file you created in the previous step.

2. Once you've confirmed that both Datagen source connectors are running and the ksqlDB join is working take the following steps
   1. From the root of the repository run `./gradlew clean build buildZip` 
   2. CD into the `aws-cli` directory
   3. Run `./aws-create-all.sh` The script will prompt you to enter `y` or `n` to confirm your choice.  The script will then create the following resources
      1. An AWS Secrets Manger with all the connection info to connect to Confluent Cloud
      2. An AWS Role with an attached policy with all the required permissions for the Lambda to execute properly
      3. Finally, an AWS Lambda instance with an event sources mapped to the Confluent Cloud topic `user_trades` which contains the results of the ksqlDB join
      4. Log into your AWS account and confirm all of these have been created properly

     
    