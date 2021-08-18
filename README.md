# Confluent Cloud Lambda Serverless Integration

### Prerequisites
* Java 11
* Gradle
* A user account in [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
* Local installation of [Confluent Cloud](https://docs.confluent.io/ccloud-cli/current/install.html) CLI v1.36.0 or later
* A user account in AWS

* Log into AWS console and select the IAM service 
  * Create a policy using `src/main/resources/lambda-and-security-manager-policy.json` as an example
  * Create a role i.e. `my-lambda-role` and add the policy you just created to it.  This step is necessary as you'll assign a role to your lambda function and the policy file establishes the permissions of what your lambda function is allowed to do.  For more information take a look at [Policies and Permissions](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).  
  
* Now select the Lambda service in the AWS console
  * Click on `Create function`
  * Give the function a name
  * Select the runtime
  * Click on `Change default execution role` and select `Use an existing role` and add the role you created in the previous step

### Background
This contains some notes from my experience with setting up an AWS Lambda to trigger off of a CCloud topic. For the initial effort, I used my own AWS account because at the time there were Confluent restrictions on creating and updating policy files. Cire-eng has pushed an update lifting this restriction but I have not tried it out.  At some point, it will probably be easier to use the Confluent federated AWS account which will allow for easier sharing of required resources.


### Setup
Here’s a non-comprehensive list of steps that can help speed up the process of getting set up.  I’m assuming here the reader already has an AWS account, installed the AWS CLI tool (brew install awscli), and has AWS credentials installed on your laptop.

When creating CCloud clusters, AWS resources, etc it’s important to make sure that everything is in the same availability zone - us-west 2

* Create 2 S3 buckets.  You’ll use one for uploading your lambda code packaged as a zip file and the other for storing results from the lambda (the output bucket is optional).  There’s a build.gradle file sent to the serverless working group slack channel that lists all the required dependencies and a function to create the zip file.
* Log into the AWS console and click on the IAM service.  From there create a new role, skip setting permissions for now and just click through to complete the role creation.
* While still in the IAM section now create a policy by clicking on Policies on the left, click the “Create Policy” button on the right, then click the “JSON” tab.  Find the lambda-key-manager-policy.json file attached in the slack channel, update the s3:GetObject and s3:PutObject sections in the JSON to match the bucket names used in step one then copy the entire policy file into the JSON editing area replacing any initial text. Save and name the policy
* Go back to the “Roles” section and click on the role you just created.  Click on the “Attach Policies” button and attach the policy you just created.
* Create a CCloud cluster, save the API key and secrete.
* From the AWS console select the “Secrets Manager” service.  Follow the steps outlined in https://docs.aws.amazon.com/secretsmanager/latest/userguide/tutorials_basic.html to set up a secrets manager.  Note that it’s best to use the JSON tab when adding your CCloud credentials.  Make sure to use the format of username: API KEY and password: SECRET when creating the JSON from the CCloud credentials.
* Create your lambda - the java source I used initially is in the slack channel ( https://github.com/confluentinc/CCloud-Serverless-Integration )
* Create a trigger for the lambda and use the secrets configuration, the bootstrap servers config and select BASIC_AUTH
AWS command for uploading lambda source zip - aws s3 --profile billb --region us-west-2 cp CCloudLambdaFunction/build/distributions/CCloudLambdaFunction.zip s3://bbejeck-confluent-source Update the profile and path and zip file name as needed
