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

#### Set up a Kafka Cluster

* Create a cluster on [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
  * Select a _**Basic**_ cluster type
    * Make sure to select AWS  _**us-west-2**_ for the region and _**Single zone**_ availability
    * After cluster is set up click on Java in the "Set up client" panel.
      * Click on "Create Kafka cluster API key" and save the username and secret in a local file
      * Clock on "Create Schema Registry API key" and save the credentials to local file
      * Then click the `Copy` link to copy the properties file containing all the required credentials and save in a file named `confluent.properties` in the `src/main/resources` directory of the code repository.  You'll need the entries in this file later when you set up the AWS Lambda.  After saving the properties file, click on the name of your cluster at the top of the page.
      * Go back to the code repo and from project root run `./gradlew propsToJson` this will create
        * JSON properties for creating an AWS secret containing credentials for connecting to Confluent Cloud
        * JSON properties for creating Datagen source connectors needed for the demo
        
TODO - Instructions for setting up with `ccloud-stack`

#### Create an AWS Lambda

To create the AWS Lambda it is assumed that you've already set up [local configuration for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html). 
You'll run a series of scripts containing AWS commands to set up everything you need to get an AWS Lambda running. But before you do that there are a couple of minor steps you need
to take to get your environment ready to run the scripts.

1. In the `aws-cli` directory save the file `configs.orig.sh` as `configs.sh`.  The project will ignore the `configs.sh` file.  It's used to provide environment 
replacements needed for some AWS commands. Most of the variables are already set, but you'll need to update the `PROFILE` variable with the profile to use, `default` if you are not sure.
Then update the `BOOTSTRAP_SERVERS` variable with the value contained in the `src/main/resources/confluent.properties` file you created in the previous step.

2. Once you've confirmed that both Datagen source connectors are running and the ksqlDB join is working take the following steps
   1. From the root of the repository run `./gradlew clean build buildZip` 
   2. CD into the `aws-cli` directory
   3. Run `./aws-create-all.sh` The script will prompt you to enter `y` or `n` at a few steps.  Your first time through you should enter `y` for each one

     
    