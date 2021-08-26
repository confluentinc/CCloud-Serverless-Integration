# Confluent Cloud Lambda Serverless Integration

### Prerequisites
* Java 11
* Gradle 7.0
* jq
* A user account in [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
* Local installation of [Confluent Cloud](https://docs.confluent.io/ccloud-cli/current/install.html) CLI v1.36.0 or later
* A user account in [AWS](https://aws.amazon.com/)
* Local installation of [AWS CLI](https://aws.amazon.com/cli/) version 2.2.30


### Setup

The following sections provide details for setting up a cluster on Confluent Cloud and creating an AWS Lambda to process events from ksqlDB

#### Provision a new ccloud-stack on Confluent Cloud

This part assumes you have already set-up an account on [Confluent CLoud](https://confluent.cloud/) and you've installed the [Confluent Cloud CLI](https://docs.confluent.io/ccloud-cli/current/install.html). We're going to use the `ccloud-stack` utility to get everything set-up to work along with the workshop.

A copy of the [ccloud_library.sh](https://github.com/confluentinc/examples/blob/latest/utils/ccloud_library.sh) is included in this repo and let's run this command now:

```
source ./ccloud_library.sh
```

Then let's create the stack of Confluent Cloud resources, note that we're passing in `true` so that a ksqlDB application is created as well:

```
CLUSTER_CLOUD=aws
CLUSTER_REGION=us-west-2
ccloud::create_ccloud_stack true
```

NOTE: Make sure you destroy all resources when the workshop concludes.

The `create` command generates a local config file, `java-service-account-NNNNN.config` when it completes. The `NNNNN` represents the service account id.  Take a quick look at the file:

```
cat stack-configs/java-service-account-*.config
```

You should see something like this:

```
# ENVIRONMENT ID: <ENVIRONMENT ID>
# SERVICE ACCOUNT ID: <SERVICE ACCOUNT ID>
# KAFKA CLUSTER ID: <KAFKA CLUSTER ID>
# SCHEMA REGISTRY CLUSTER ID: <SCHEMA REGISTRY CLUSTER ID>
# ------------------------------
ssl.endpoint.identification.algorithm=https
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
bootstrap.servers=<BROKER ENDPOINT>
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<API KEY>" password="<API SECRET>";
basic.auth.credentials.source=USER_INFO
schema.registry.basic.auth.user.info=<SR API KEY>:<SR API SECRET>
schema.registry.url=https://<SR ENDPOINT>
```

We'll use these properties for connecting to CCloud from your AWS Lambda, but we'll get to that in just a minute.

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

     
    