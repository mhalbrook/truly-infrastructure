# Volly Terraform Library Module | S3 Bucket

**Current Version**: v3.2

This module creates a private, KMS-Encrypted, S3 Bucket. The S3 Bucket may be configured with custom Lifecycle Rules, Bucket Policies, or CORS Rules. Additionally, the module may be configures to provision an additional S3 Bucket with a Replication Rule to sync data between the two S3 Buckets. Finally, the bucket may be configured to capture Elastic Load Balancer and S3 Access Logs.

## Known Issues
The following are known issues within the S3 Library Module. These issues are primarily driven by the behavior of either Terraform or the AWS resources managed by the module.

1. Terraform fails to provision a new S3 Bucket with replication.

  * **Cause:** Terraform requires replication configurations to be set within the S3 Bucket resource block. This creates a cycle issue where neither S3 Buckets may be completely provisioned as they both are dependent on the other S3 Bucket in order to complete their replication configuration. 
  * **Workaround:** Re-apply the Terrafomr module following the error. By the time the module is re-applied, the S3 Buckets will be in an *available* state and the configurations will be applied appropriately. Additionally, you may apply the module *without* replication, then configure replication and re-apply the module.


## USAGE

#### Providers
From a root module, set a provider for the account in which to build the S3 Bucket. When calling this Library module, set the provider equal to *aws.account*.
Additionally, set a provider for an additional AWS Region within the same AWS Account and, when calling this Library module, set the provider equal to *aws.replication*. This provider allows the module to configure an additional S3 Bucket for oject replication. If a replication S3 Bucket is not being provisioned, this provider is still required, however, the provider will not be used to provision any resources, therefore, any valid provider may be used.



#### Features 

##### Replication
This module supports provisioning a second S3 Bucket with a Replication Rule to sync data between the two S3 Buckets. This feature is enabled when the *replicate_bucket* variable is set to *true*. 

When replication is enabled, the *kms_key_arn_replication* variable is required. 


##### Custom Bucket Policies
This module supports the configuration of a custom Bucket Policy for the provisioned S3 Bucket. This feature is enabled when a valid JSON Bucket Policy is provided to the *bucket_policy* variable.

This feature is not available when the S3 Bucket is configured to capture Access Logs from S3 Buckets or Elastic Load Balancers (i.e. the Logging Bucket feature is enabled).


##### Lifecycle Rules
This module supports the configuration of custom Lifecycle Rules to automate transitioning and/or expiring objects within the bucket. This feature is enabled when a valid Lifecycle Rule configuration is provided to the *lifecycle_rules* variable.

The *lifecycle_rules* variable requires a map where the *key* is the friendly name of the Lifecyce Rule and the *values* set the configuration of the rule. The map must include the following arguments:

  * **prefix** = The prefix (path) to which the Lifecycle Rule applies (i.e. if set to *example*, the rule will apply only to objects within the *example* directory.)
      * When rule applies to all objects, this argument is set to null.
  * **expiration** = The number of days, after which, an object should be permanently deleted from the S3 Bucket.
  * **noncurrent_version_expiration** = The number of days, after which, a non-current version of an object should be permanently deleted from the S3 Bucket.
  * **transitions** = A map of transitions for objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
      * If a transition is not required, set this argument to *{}*.
  * **noncurrent_version_transitions** = A map of transitions for non-current versions of objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
      * If a non-current version transition is not required, set this argument to *{}*.


##### Logging Bucket
This module supports configuring the S3 Bucket to capture Elastic Load Balancer and S3 Access Logs. By default, each AWS Account created by Volly's **New Organization Account** Terraform Lobrary module contains a default S3 Bucket for Elastic Load Balancer and S3 Access Logs, however, in some specific cases, an additional bucket may need provisioning for this purpose.

This feature is enabled when the *is_logging_bucket* variable is set to *true*.


##### Custom CORS Rules
This module supports configuring a custom CORS Rule for the S3 Bucket, allowing the S3 Bucket to server Cross-Origin requests when configured as an AWS CloudFront Ditribution Origin. This feature is enabled when a valid value is provided to *any* of the following variables:
    * **allowed_headers** = A List of headers that are allowed when making requests to the S3 Bucket.
    * **allowed_methods** = A List of methods (GET, PUT, POST, etc) that are allowed when making requests to the S3 Bucket.
    * **allowed_origins** = A List of origins that are allowed to make cross-domain requests to the S3 Bucket.
    * **expose_headers** = A List of headers to allow in responses to requests to the S3 Bucket.


##### CloudTrail Logging
This module supports enabling CloudTrail logs for the provisioned S3 Bucket(s) Data Events. This feature is enabled when the *enable_cloudtrail* variable is set to *true*. 

By default, all S3 Management Events are captured and logged by Volly's *Organization* Trail. However, in some cases, it may be neccessary for S3 *Data* Events to be captured by CloudTrail.



#### Dependencies
The following resources are always required for the module:
    * KMS Key (used to encrpyt the bucket)

If creating an S3 Bucket with Replicaiton enabled, the following resources are required prior to deployment of this module:
    * KMS Key (used to encrypt the replication bucket)



## Example
#### Example with only *required* variables
        module "s3" {
          source              = "git::ssh://git@bitbucket.org/v-dso/s3"
          environment         = "prod"
          bucket_name         = "example"
          kms_key_arn         = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          data_classification = "internal confidential"

          providers = {
            aws.account       = aws.east
            aws.replication   = aws.west
          }
        }

#### Example with *all* variables
        module "s3" {
          source                  = "git::ssh://git@bitbucket.org/v-dso/s3"
          project                 = "volly-example-project"
          environment             = "prod"
          bucket_name             = "example"
          kms_key_arn             = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          data_classification     = "internal confidential"
          replicate_bucket        = true 
          kms_key_arn_replication = "arn:aws:kms:us-west-2:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          bucket_policy           = data.aws_iam_policy_document.bucket_policy.json
          allowed_headers         = ["Example"]
          allowed_methods         = ["GET", "HEAD"]
          allowed_origins         = ["https://example.com", "https://one.example.com"]
          expose_headers          = ["Example"]
          max_age_seconds         = 5000
          enable_cloudtrail       = true
          lifecycle_rules         = {
            example-lifecycle-rule = {
              prefix                        = "example"
              expiration                    = 365
              noncurrent_version_expiration = 180
              transitions = {
                90 = "GLACIER"
              }
              noncurrent_version_transitions = {
                90 = "GLACIER"
              }
            }   
          }

          providers = {
            aws.account       = aws.east
            aws.replication   = aws.west
          }
        }



## Variables

#### Required Variables
* **environment** *string* = Environment that the S3 Bucket will support. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **bucket_name** *string* = Friendly name for the S3 Bucket.
    * The module will automatically append the *bucket_name* to the AWS Region and Account Name to generate the full name of the S3 Bucket. (i.e. *example* may become *us-east-1-vollly-account-example*)
* **kms_key_arn** *string* = ARN of the KMS Key used to encrpyt the S3 Bucket.
* **data_classification** *string* = Volly data classification of data stored within the S3 Bucket. 
    * Valid options are 'public', 'strategic', 'internal confidential' or 'client confidential'.
    * Defined value will be set as a tag on the S3 Bucket (i.e. *data classification:confidential*).


#### Optional Variables
* **project** *string* = Friendly name of the project the S3 Bucket supports. 
    * Enables override of naming conventions when the S3 Bucket supports a project within and AWS Acocunt that is not named after that project. For example, Volly Marketing Portal is deployed to the Volly CRM AWS Account. To better-align the names of the Volly Marketing Portal S3 Buckets, the *project* variable could be set to *volly-mp*.
* **tags** *map(string)* = A map of additional tags to add to the resources provisioned by the module.


##### Replication
* **replicate_bucket** *boolean* = Sets whether to provision a secondary S3 Bucket and configure a Replication Rule to sync objects beween the two S3 Buckets.
    * Defaults to *false*.
    * When set to *true*, the *kms_key_arn_replication* variable is required.
* **kms_key_arn_replication** *string* = RN of the KMS Key used to encrpyt the secondary S3 Bucket.


##### Custom Bucket Policies
* **bucket_policy** *string* = JSON-formatted Bucket Policy to apply to the S3 Bucket.
    * This argument is ignored when *is_logging_bucket* is set to *true*.


##### Lifecycle Rules
* **lifecycle_rules** *map* = Map of the Lifecycle Rule configurations to be allied to the S3 Bucket.
    * Allows for the configuration fo multiple Lifecycle Rules.
    * The following arguments must be set within the map:
        * **prefix** = The prefix (path) to which the Lifecycle Rule applies (i.e. if set to *example*, the rule will apply only to objects within the *example* directory.)
            * When rule applies to all objects, this argument is set to null.
        * **expiration** = The number of days, after which, an object should be permanently deleted from the S3 Bucket.
        * **noncurrent_version_expiration** = The number of days, after which, a non-current version of an object should be permanently deleted from the S3 Bucket.
        * **transitions** = A map of transitions for objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
            * If a transition is not required, set this argument to *{}*.
        * **noncurrent_version_transitions** = A map of transitions for non-current versions of objects governed by the Lifecycle Rule, where each *key* is the number of days, after which, the transition should take place and the *value* is the *Storage Class* to which objects should be transitioned.
            * If a non-current version transition is not required, set this argument to *{}*.

##### Logging Bucket
* **is_logging_bucket** *boolean* = Sets whether to configure the S3 Bucket to be able to capture Access Logs from Elastic Load Balancers and/or S3 Buckets.

##### Custom CORS Rules
* **allowed_headers** *list* = List of headers that are allowed when making requests to the S3 Bucket.
* **allowed_methods** *list* = List of methods (GET, PUT, POST, etc) that are allowed when making requests to the S3 Bucket.
* **allowed_origins** *list* = List of origins that are allowed to make cross-domain requests to the S3 Bucket.
* **expose_headers** *list* = List of headers to allow in responses to requests to the S3 Bucket.
* **max_age_seconds** *number* = The amount of time (seconds) that browsers can cache the response for a preflight request via CORS policy

##### Cloudtrail Logging
* **enable_cloudtrail** *boolean* = Sets whether to create an AWS CloudTrail Trail for S3 Events.
    * Defaults to *false*.
    * When enabled, a CloudTrail Trail is provisioned to capture Object-Level Data Events related to the provisioned S3 Bucket.


## Outputs

##### Bucket Outputs
Bucket Outputs are presented as Maps to allow for simplified output referencing when replicaiton is enables. In all cases, the map *key* is the AWS Region in which the bucket has been provisioned.

For example, if the module provisons two S3 Buckets, one in us-east-1 and another in us-west-2, the arn of the S3 Bucket in the East region may be referenced via *module.example.bucket_arn["us-east-1"]*, while the S3 Bucket in the West region may be referenced via *module.example.bucket_arn["us-west-2"]*.

* **bucket_name** = Friendly name of the S3 Bucket.
* **bucket_arn** = ARN of the S3 Bucket.
* **bucket_id** = Name of the S3 bucket.
* **bucket_domain_name** = Domain name of the S3 bucket
* **bucket_hosted_zone_id** = Route 53 Hosted Zone ID of the S3 bucket.
* **bucket_regional_domain_name** = Domain name with Region Name of the S3 bucket.

##### Replication Role Outputs
Replication Role Outputs are presented as lists to ensure outputs are correctly handled when replicaiton is not enabled. In all cases, lists only include one element.

* **bucket_replication_role_name** = Name of the IAM Role used for replicating objects between buckets.
* **bucket_replication_role_arn** = ARN of the IAM Role used for replicating objects between buckets.
* **bucket_replication_role_id**  = ID of the IAM Role used for replicating objects between buckets.
* **bucket_replication_role_unique_id** = Unique ID of the IAM Role used for replicating objects between buckets.
