
# Terraform Module | Truly-Clojure-Test Infrastructure
current Version: 1.0.0

## Table of Contents

    Description
        * AWS Resources
        * Requirements
    Usage
        * Deploying the Infrastructure
            * Creating the Terraform Back-End
                * Updating the Terraform Back-End Configurations
            * Deploying the Core Infrastructure
                * Logging Resources
                * Route53 Hosted Zone
                * Certificate
                * VPC
            * Deploying the Service Infrastructure
            * Building the Container Image
        * Testing
            * Testing the Application
            * Updating the Message
        * Tear Down


## Description
This module deploys the infrastructure that hosts the truly-clojure-test service. 

### AWS Resources Provisioned:

    * S3 Bucket & KMS Key (for ALB Access Logs)
    * Route53 Public Hosted Zone
    * Public SSL Certificate
    * VPC
    * Route53 Record
    * Application Load Balancer & Target Group
    * ECS Cluster
    * ECS Fargate Service
    * Systems Manager Parameter (for storing container environment variable)
    * Elastic Container Registry Repository & KMS Key
    * CodeBuild Project 
    * CloudWatch Log Group for Application Logs
    * Various IAM Roles and Policies (to support service permissions)

### Requirements:
    * Terraform v.0.14.11 *(newer version may also be compatible)
        * installation instructions can be found [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).
    * AWS CLI
        * Installation instructions can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
        * AWS CLI configuration instructions can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html).
        * The Terraform module assumes the use of the *Default* AWS Profile, however, instructions for using a custom profile are provided throughout.
    * AWS Account and IAM User
        * The IAM User must have permission to perform all actions required by the module. Given the number of required actions it may be simplest to provide the IAM user with the AdministratorAccess Policy, even if only temporarily.
    * Registered, Public Domain
        * This is not an actual requirement, however, without a registered domain, you will not be able to connect to the application over https and will instead need to connect via port 80 (http) to the domain of the Application Load Balancer that serves the application.

## Usage

### Deploying the Infrastructure
This module leverages the TerraServices module where the overall infrastructure is broken into multiple modules with references using Terraform Remote State. This lessens maintenance and allows teams to make small configuration changes quickly with less risk. With this structure, the initial infrastructure deployment is broken into steps with a specific order.


#### Creating the Terraform Back-End
In order for Terraform to leverage the TerraServices module, an S3 Backend must be used to store the generated State Files of each module. Additionally, a DynamoDB Table is required to ensure that state files are locked while Terraform provisions resources. 

To provision the Terraform Back-End resources:

* **Note: if the AWS Account you are working in already has an IAM Alias, comment out lines 4 -7 in *main.tf* as the first resource provisions an alias, which is used to standardize naming conventions in subsequent modules.**

1. Navigate to the *backend* directory in your terminal
3. Open the **variables.tf** file and update the default value of the *account_alias* and *bucket_name* variables to the desired AWS Account Alias and S3 Bucket name, respectively.
2. Run the following commands:

                terraform workspace new leveraged
                terraform init
                terraform apply

3. Note the *backend_bucket_name* output displayed after *terraform apply* completes, this will be used in the next section to update the Terraform Back-End configuration. the output will look similar to this:

                Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

                Outputs:

                backend_bucket_name = "us-east-1-halbromr-terraform-state-backend"



##### Updating the Terraform Back-End Configurations
Now that the Terraform Back-end resources are provisioned, the **backend.tf** file in each Terraform Module must be updated to specify that State Files are to be stored within the newly created Terraform Back-End S3 Bucket.

To update the Back-End configuration, open the **backend.tf** in each module, then change the value of the *bucket* argument to the *backend_bucket_name Output* received after running *terraform apply* in the previous section.

Finally, navigate to the *services/truly* directory and open the **data.tf** file, then change the value of the *bucket* argument to the *backend_bucket_name Output* received after running *terraform apply* in the previous section.

* **Note: All modules assume the use of the *Default* AWS Profile for authentication. To use a Custom Profile, replace *default* with the name of the Custom profile in the *profile* argument. Additionally, change the same argument within the *providers.tf* file of each module as well as in the *data.tf* file of the *services/truly* module.**



#### Deploying the Core Infrastructure
Core resources are infrastructure components that may be leveraged by multiple services. These resources are deployed first as the Services are dependent upon them.

##### Logging Resources
This module will deploy an encrypted S3 Bucket that can be used to store Access Log files from S3 and ALBs. Additionally, a KMS Key is provisioned for use in making secure connections to running Fargate services and shipping those session logs to CloudWatch. This allows users to interact with the Docker Container running on Fargate even though there is no host to connect to.

To provision the Logging resources:
1. Navigate to the *core/logging* directory in your terminal
2. Run the following commands:

                terraform workspace new leveraged
                terraform init
                terraform apply


##### Route53 Hosted Zone
In order to reach the service via a Public Domain, a Route53 Hosted Zone must be provisioned. This module will provision a Route53 Hosted Zone and output the Name Servers, which can be used to configure the domain.

* **Note: this module may be skipped if you do not have a domain with which to associate the Hosted Zone. If this module is skipped, the *certificates* module should also be skipped.**

* **Note: if you are using a domain that is not registered with AWS Route53, ensure the hosted zone is configured as a sub-domain (i.e. sub.example.com *not* example.com).** 

To provision the Route53 Hosted Zone:
1. Navigate to the *core/hosted_zones* directory in your terminal.
2. Open the *variables.tf* file
3. Update the default value of the *domain* variable to the name of the domain on which the service(s) will run.
4. Run the following commands:

                terraform workspace new leveraged
                terraform init
                terraform apply

5. Note the *name_server_record_values* output displayed after *terraform apply* completes, this will be used in the next section to update the Domain Name Servers. the output will look similar to this:

                Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

                Outputs:

                name_server_record_values = [
                toset([
                    "ns-1019.awsdns-63.net",
                    "ns-1044.awsdns-02.org",
                    "ns-1677.awsdns-17.co.uk",
                    "ns-169.awsdns-21.com",
                ]),
                ]

**If you are connecting the Hosted Zone to a Domain registered with AWS Route53:**

6. Connect the Domain to the Hosted Zone by running the following command:

                aws route53domains update-domain-nameservers --domain-name {{domain}} --nameservers Name={{ns1}} Name={{ns2}} Name={{ns3}} Name={{ns4}} 

where {{domain}} is the name of the domain being updated and {{ns1}} - {{ns4}} are the values of the *name_server_record_values* Output received after running *terraform apply* in the previous step.

* **Note: the above AWS CLI command assumes the use of the *Default* AWS Profile for authentication. To use a Custom Profile, add *--profile {{custom-profile}}* to the command where {{custom_profile}} is the name of the name of the Custom Profile.**

**If you are *NOT* connecting the Hosted Zone to a Domain registered with AWS Route53:** 

6. Create a new **NS** DNS Record in the DNS Zone associated with your domain and set the record value to the *name_server_record_values* Output received after running *terraform apply* in the previous step. 
    * Consult online documentation for you DNS Provider for instructions on how to do this.


##### Certificate
In order to make an https connection to the service, a certificate must be provisioned and attached to the ALB that serves requests to the Fargate Service. This module will provision and validate a certificate, using the Hosted Zone provisioned in the previous section.

To provision the certificate:
1. Navigate to the *core/certificates* directory in your terminal.
2. Open the *variables.tf* file
3. Update the default value of the *truly_domain* variable to the name of the domain you wish to use when connecting to the service.
    * This should be the apex domain or a sub-domain of the Hosted Zone zone provisioned in the previous step.
4. Run the following commands:

                terraform workspace new leveraged
                terraform init
                terraform apply


##### VPC
The Fargate Service must be run inside a Virtual Private Cloud. This module will deploy a 3-tiered VPC with the required NACL Rules and Routes.

To provision the VPC:
1. Navigate to the *core/vpc* directory in your terminal.
4. Run the following commands:

                terraform workspace new truly
                terraform init
                terraform apply



#### Deploying the Service Infrastructure
This module will deploy the resources required to build and run the service on ECS Fargate. A DNS Record will be provisioned and pointed at the ALB, which will load balance the ECS Fargate Service that runs the containerized application. Additionally, An AWS CodeBuild Project and Elastic Container Registry Repository will be provisioned to allow us to build and store the Docker Image.

To provision the service:
1. Navigate to the *service/truly* directory in your terminal.
2. Run the following commands:

                terraform workspace new truly
                terraform init
                terraform apply

**If the **Hosted Zone** and **Certificates** sections were skipped:**
 
3. Note the *load_balancer_domain_name* Output received after running *terraform apply* in the previous step. This is the domain that will be used to connect to the application in the *Testing the Application* and *Updating the Message* sections. the output will look similar to this:

                Apply complete! Resources: 43 added, 0 changed, 0 destroyed.

                Outputs:

                load_balancer_domain_name = "truly-clojure-demo-alb-xxxxxxxxxxxx.us-east-1.elb.amazonaws.com"


### Building the Container Image
Now that the supporting infrastructure is in place, we can use AWS CodeBuild to build and push the container image to AWS Elastic Container Registry (ECR). Once in ECR, the Fargate service will be able to pull and run the image.

To build the image, run the following command from your terminal:
* **Note: the below AWS CLI command assumes the use of the *Default* AWS Profile for authentication. To use a Custom Profile, add *--profile {{custom-profile}}* to the command where {{custom_profile}} is the name of the name of the Custom profile.**

                aws codebuild start-build --project-name truly-clojure-demo --region us-east-1 --query 'build.id'
    
    The CLI will output the ID of the build, which can be used with the below CLI command to periodically check the status of the build:

                aws codebuild batch-get-builds --ids {{build_id}} --region us-east-1 --query 'builds[*].currentPhase' 

    When the build is complete, the following output will be presented:

                [
                    "COMPLETED"
                ]

    You can then run the following command to verify that the ECS Fargate service is running:

                aws ecs wait services-stable --cluster truly-clojure-demo --services truly-clojure-demo --region us-east-1

    The command will not present an output until the ECS Fargate Task reaches a Running State. If a considerable amount of time has passed between deploying the service and completing the initial build, there may be a delay in Fargate attempting to launch the task. In this instance, the following command can be run to expedite the initial deployment:

                aws ecs update-service --cluster truly-clojure-demo --service truly-clojure-demo --force-new-deployment --region us-east-1 


### Testing

### Testing the Application
Once the container build has completed and Fargate has successfully launched the service, test the application by navigating to the domain that was configured in Step 3 of the **Certificate Section** in the browser of your choice. 

If the **Certificate Section** was skipped, navigate to the *load_balancer_domain_name* Output received after running *terraform apply* in the **Deploying the Service Section**.

The following text should be printed in the browser:

                {"message": "Hello Truly!"}

*If the message is not presented, verify that all Terraform Modules have been deployed and that the Fargate Tasks are running.*


### Updating the Message
By default, the application will print the message "Hello Truly!". this message is passed to the application via a Systems Manager Parameter. We can update the parameter to present a new message and redeploy the Fargate Service without making any adjustments to the application code or the Docker commands that initialize the container.

* **Note: the below AWS CLI commands assume the use of the *Default* AWS Profile for authentication. To use a Custom Profile, add *--profile {{custom-profile}}* to the command where {{custom_profile}} is the name of the name of the Custom profile.

To update the message, run the following command from your terminal:

                aws ssm put-parameter --name "/appconfig/MESSAGE" --value "{{Your Message}}" --overwrite --region us-east-1

*where {{your message}} is the message that you would like the application to present.*

Then, re-deploy the Fargate Service by running the following command:

                aws ecs update-service --cluster truly-clojure-demo --service truly-clojure-demo --force-new-deployment --region us-east-1 

You can then run the following command to verify that the ECS Fargate service deployment has completed:

                aws ecs wait services-stable --cluster truly-clojure-demo --services truly-clojure-demo --region us-east-1

* **Note: The command will not present an output until the deployment has completed.**

Once the deployment has completed, refresh the page in your browser to verify that the message has been updated.



### Tear Down
Once the application functionality has been verified, the Terraform Modules may be destroyed. 

To destroy the infrastructure, run the following commands in each module in the reverse order in which they were applied (i.e. starting with *service/truly* and ending with *backend*)

* **Note: if you wish to destroy, then re-deploy the infrastructure, do not destroy the *core/logging* or *backend* modules. These modules provision S3 Buckets, which exist in a global namespace, therefore, it may take up tot 24 hours for the S3 Bucket names to become available again after destruction.**

commands for *services/truly* and *core/vpc*:

                terraform destroy
                terraform workspace select default
                terraform workspace delete truly

commands for all other modules:

                terraform destroy
                terraform workspace select default
                terraform workspace delete leveraged
