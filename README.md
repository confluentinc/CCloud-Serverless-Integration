# Confluent Cloud Lambda Serverless Integration

### Prerequisites
* Java 11
* Gradle
* A user account in [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
* Local installation of [Confluent Cloud](https://docs.confluent.io/ccloud-cli/current/install.html) CLI v1.36.0 or later
* A user account in [AWS](https://aws.amazon.com/)
* Local installation of [AWS CLI](https://aws.amazon.com/cli/) version 2.2.30


### Setup

The following sections provide details for setting up a cluster on Confluent Cloud and creating an AWS Lambda to process events from ksqlDB

#### Set up a Kafka Cluster

* Create a cluster on [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
  * Select a _**Basic**_ cluster type
    * Make sure to select AWS  _**us-west-2**_ for the region and _**Single zone**_ availability
    * After cluster is set up click on Java in the "Set up client" panel.
      * Click on "Create Kafka cluster API key" and save the username and secret in a local file
      * Clock on "Create Schema Registry API key" and save the credentials to local file
      * Then click the `Copy` link to copy the properties file containing all the required credentials and save in a file named `confluent.properties` in the `src/main/resources` directory of the code repository.  You'll need the entries in this file later when you set up the AWS Lambda.  After saving the properties file, click on the name of your cluster at the top of the page.
  * Click on _**Topics**_ 
    * Follow the links to create three topics `stocktrade`, `stock_users`, and `user_trades`
  * Click on _**Connectors**_ 
    * Scroll down and locate and click on "Datagen Source"
      * Update the name to "Stocktrades Generator"
      * Select the topic `stocktrades` from the dropdown
      * Choose JSON for the output format
      * Select `STOCK_TRADES` in "Datagen Details"
      * Put `1000` for the max interval between messages
      * Enter `1` for the number of tasks
      * Follow links to complete the process
    * Repeat the process for another Datagen connector
        * Update the name to "User Generator"
        * Select the topic `stock_users` from the dropdown
        * Choose JSON for the output format
        * Select `USERS` in "Datagen Details"
        * Put `1000` for the max interval between messages
        * Enter `1` for the number of tasks
        * Follow links to complete the process
  * Go back to main cluster page
  * Click on _**ksqlDB**_ on the left
    * Click on "Create application myself" - note that it takes a couple of minutes for ksqlDB to get fully initializes
      * Once ksqlDB is up and running copy the `sql` statements from `src/main/resources/stocktrade-users.sql` one at a time and paste them into the editor. 
      
#### Create an AWS Lambda

To create the AWS Lambda it is assumed that you've already set up [local configuration for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html). 
You'll run a series of scripts containing AWS commands to set up everything you need to get an AWS Lambda running. But before you do that there are a couple of minor steps you need
to take to get your environment ready to run the scripts.

1. From the root of the project run `./gradlew propsToJson`.  This task takes the properties file you created earlier and creates a JSON file 
that you'll use when you run a script which executes AWS `secretsmanager` command.
2. In the `aws-cli` directory save the file `configs.orig.sh` as `configs.sh`.  The project will ignore the `configs.sh` file.  It's used to provide environment 
replacements needed for some AWS commands.

     
    