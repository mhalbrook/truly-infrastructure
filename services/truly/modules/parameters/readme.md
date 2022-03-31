# Volly Terraform Library Module | Systems Manager Parameter

**Current Version**: v2.2

This module creates a Systems Manager (ssm) Parameter Store Parameter. The module may be used to provision *standard* or *advanced* parameters with or without encryption. Additionally, parameter values may configured to be validated against regular expressions.


## Known Issues
There are no known issues with this module.


## USAGE

#### Providers
From a root module, set a provider for the account in which to provision the SSM Parameter. When calling this Library module, set the provider equal to *aws.account*.


#### Features 

##### Encryption
This module supports provisioning an SSM Parameter that is encrypted with an AWS KMS Key. This feature is enabled by providing a valid KMS Key ID to the *kms_key_id* variable.

###### Advanced Tier
This module supports provisioning an SSM Parameter with the *Advanced* tier. This feature is enabled when the *tier* variable is set top *Advanced*.

By default, an SSM Parameter with the *Standard* tier is provisioned, which is able to handle parameter values that are less than 10,000 characters and under 4KB in size.


##### Value Validation
This module supports configuring the SSM Parameter to validate the parameter value against a regular expression. This feature is enabled by providing a valid regular expression to the *allowed_pattern* variable.


###### Store AMI IDs
This module supports provisioning an SSM Parameter that is used to store an Amazon Machine Image (AMI) ID. this feature is enabled when the *store_ami_id* variable is set to *true*. 

When enabled, AWS will verify that the SSM Parameter value is a valid AMI prior to saving the parameter. 




#### Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules. 

The following resources are required when provisioning SSM Parameters that are encrypted:

  * KMS Key


## Example
#### Example with only *required* variables
    module "ssm_parameter" {
        source        = "git::ssh://git@bitbucket.org/v-dso/ssm-parameter-store"
        environment   = "prod"
        service_name  = "volly-example-service"
        name          = "example/parameter"
        value         = "example-value"

        providers = {
            aws.account = aws.example
        }
    }

#### Example with *all* variables
    module "ssm_parameter" {
        source                    = "git::ssh://git@bitbucket.org/v-dso/ssm-parameter-store"
        environment               = "prod"
        service_name              = "volly-example-service"
        name                      = "example/parameter"
        description               = "Example parameter description"
        value                     = "example-value"
        tier                      = "Advanced"
        kms_key_arn               = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        allowed_pattern           = ".*"
        store_ami_id              = true

        providers = {
            aws.account = aws.example
        }
    }




## Variables

#### Required Variables
* **environment** *string* = Environment that the SSM Parameter supports. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **service_name** *string* = Friendly Name of the service the SSM Parameter supports.
* **name** *string* = Friendly name of the SSM Parameter.
* **value** *string* = Value to be stored by the SSM Parameter.


#### Optional Variables
* **description** *string* = "Description of what the SSM Parameter stores and how it is used"

##### Encryption
* **kms_key_arn** *string* = ARN of the KMS Key used to encrypt the SSM Parameter.

###### Advanced Tier
* **tier** *string* = Sets the *Tier* of the SSM Parameter.
    * Valid options are *Standard* or *Advanced*.
    * Defaults to *standard*.
        * Standard supports up to 10,000 characters and 4KB.
        * Standard does not support Parameter Policies.
    * *Advanced* tier supports:
        * 100,000 characters and 8KB.
        * Parameter Policies.


##### Value Validation
* **allowed_pattern** *string* = Regular expression used to validate the value of the SSM Parameter.


###### Store AMI IDs
* **store_ami_id** *boolean* = Sets whether the SSM Parameter is used to store an AMI ID.
    * Defaults to *false*.


## Outputs

#### ECR Repository Outputs
* **ssm_name** = Friendly name of the SSM Parameter.
* **ssm_arn** = ARN of the SSM Parameter.
* **ssm_type** = The Type of SSM Parameter provisioned (*String*, *SecureString*).
* **ssm_value** = Value of the SSM Parameter.