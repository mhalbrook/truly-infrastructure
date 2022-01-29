# Volly Terraform Library Module | KMS Key

**Current Version**: v3.1

This module creates a KMS Key for encryption fo AWS Resources. The module may be configured to create an identical KMS key in a secondary AWS Region. Additionally, the module support configuring a custom Key Policy for the KMS Key.


## Known Issues
There are no known issues with this module.


## USAGE

#### Providers
From a root module, set a provider for the account in which to build the KMS Key. When calling this Library module, set the provider equal to *aws.account*.
Additionally, set a provider for an additional AWS Region within the same AWS Account and, when calling this Library module, set the provider equal to *aws.secondary*. This provider allows the module to provision an additional KMS Key in the other AWS Region. If a multi-region key is not being provisioned, this provider is still required, however, the provider will not be used to provision any resources, therefore, any valid provider may be used.



#### Features 

##### Multi-Region
This module supports provisioning a second KMS Key in another AWS Region. This feature is enabled when the *multi_region* variable is set to *true*. 


##### Custom Key Policy
This module supports the configuration of a custom Key Policy for the provisioned KMS Key. This feature is enabled when a valid JSON KMS Key Policy is provided to the *key_policy* variable.

This feature is not available when the KMS Key is configured to encrypt S3 Buckets that capture Access Logs from Elastic Load Balancers or S3 Buckets (i.e. the Logging Key feature is enabled)


##### Logging Key
This module supports configuring the KMS Key to be used for encryption fo S3 Buckets which collect Access Logs from Elastic Load Balancers and/or S3 Buckets. This feature is enabled when the *is_logging_key* variable is set to *true*. By default, each AWS Account created by Volly's **New Organization Account** Terraform Library module contains a default KMS Key for Elastic Load Balancer and S3 Access Logs, however, in some specific cases, an additional KMS Key may need provisioning for this purpose.

When enabled, a Key Policy enabling log collection functions is attached to the KMS Key. This policy overrides any Custom Key Policy provided to the module.



#### Dependencies
This module has no dependencies.



## Example
#### Example with only *required* variables
        module "kms" {
          source      = "git::ssh://git@bitbucket.org/v-dso/kms"
          environment = "prod"
          service     = "example-service"
          suffix      = "es"

          providers = {
            aws.account     = aws.east
            aws.secondary   = aws.west
          }
        }

#### Example with *all* variables
        module "kms" {
          source         = "git::ssh://git@bitbucket.org/v-dso/kms"
          environment    = "prod"
          service        = "example-service"
          suffix         = "es"
          multi_region   = true 
          key_policy     = data.aws_iam_policy_document.key_policy.json
          is_logging_key = true

          providers = {
            aws.account     = aws.east
            aws.secondary   = aws.west
          }
        }       



## Variables

#### Required Variables
* **environment** *string* = Environment that the KMS Key will support. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **service** *string* = Friendly name of the service or resource that the KMS Key will be used to encrypt.
    * The module will use this value to create a human-readable description of the KMS Key
* **suffix** *string* = Abbreviation of the service or resource that the KMS Key will be used to encrypt.


#### Optional Variables

##### Multi-Region 
* **multi_region** *boolean* = Sets whether to create an identical KMS Key in another AWS Region.
    * Defaults to *false*.

##### Custom Key Policy
* **key_policy** *string* = JSON-formatted Key Policy to apply to the KMS Key.    
    * This argument is ignored when *is_logging_key* is set to *true*.

##### Logging Key
* **is_logging_key** = Sets whether the KMS Key is used to encrypt S3 Buckets that collect Access Logs from Load Balancers and/or S3 Buckets.
    * Defaults to *false*.


## Outputs

##### KMS Key Outputs
KMS Key Outputs are presented as Maps to allow for simplified output referencing when multi-region keys are provisioned. In all cases, the map *key* is the AWS Region in which the KMS Key has been provisioned.

For example, if the module provisions two KMS Keys, one in us-east-1 and another in us-west-2, the arn of the KSM Key in the East region may be referenced via *module.example.key_arn["us-east-1"]*, while the KMS Key in the West region may be referenced via *module.example.key_arn["us-west-2"]*.

* **key_name** = Friendly name of the KMS Key.
* **key_alias** = Alias of the KMS Key.
    * All KMS Key Aliases begin with *alias/*.
* **key_arn** = ARN of the KMS Key.
* **key_id** = Name of the KMS Key.