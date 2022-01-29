# Volly Terraform Library Module | CodeBuild Project

**Current Version**: v3.1

This module creates a CodeBuild Project for building Volly and third-party applications. 


## Known Issues
There are no known issues with this module.


## USAGE

#### Providers
From a root module, set a provider for the account in which to provision the Transit Gateway. When calling this Library module, set the provider equal to *aws.account*.



#### Features 

##### Custom Build Spec
This module supports provisioning a CodeBuild project with a Custom Build Spec. This feature is enabled by providing a valid JSON-encoded or YAML-encoded Build Spec to the *buildspec* variable.

By default a standard Build Spec document is used. This BuildSpec is valid for most ECS container deployment patterns.


##### Environment Variables
This module supports provisioning a CodeBuild project with Environment Variables. This feature is enabled by providing a valid map of Environment Variable *keys* and *values* to the *environment_variables* variable.

By default, the CodeBuild Project is provisioned with the *required* environment variables for the Standard BuildSpec document.


##### Artifacts
This module supports provisioning a CodeBuild project that generates and stores Artifacts as part of the build. This feature is enabled by providing a valid value to the *artifacts_type* variable.

In addition to the *artifacts_type* variable, which sets the CodeBuild Project to store Artifacts in **S3** or **CodePipeline**, the following variables may be used to customize Artifact behavior **when the *artifacts_type* is set to S3**:

  * artifacts_location *(required when artifacts_type is set to *S3*)*:
    * Sets the S3 Bucket and Path to which Artifacts are stored.
  * artifacts namespace:
    * Sets the namespace to include in the path to which Artifacts are stored. For example, when set to *BUILD_ID*, the CodeBuild BuildId will be inserted into the artifacts_location.
  * artifacts_zip_package:
    * Sets whether to zip the final Artifacts package before uploading to the specified location.
  * artifacts_override_name: 
    * Sets whether to allow the CodeBuild BuildSpec to set the location and/or name of the Artifact package.
    * This may be useful when generating a unique artifacts_location based on CodeBuild variables.


##### Environment Type
This module supports provisioning a CodeBuild Project that uses a specific Environment Type for builds. This feature is enabled by providing a valid Environment Type to the *environment_type* variable.

By default, the Environment Type is set to *LINUX_CONTAINER*.


##### Compute Type
This module supports provisioning a CodeBuild Project that uses a specific Compute Type for builds. This feature is enabled by providing a valid Compute Type to the *compute_type* variable.

The default Compute Type is determined by the Environment Type Selected. Additionally, certain Environment Types require a specific Compute Type, therefore the module will override the Compute Type settings. Below are the default Compute Type settings.

  * When Environment Type is *LINUX_CONTAINER*, the default Compute Type is *BUILD_GENERAL1_SMALL*.
  * When the Environment Type is *LINUX_GPU_CONTAINER*, the module will force a Compute Type of *BUILD_GENERAL1_LARGE* as that is the only valid Compute Type for the Environment Type.
  * When the Environment Type is set to any other value, the default Compute Type is *Build_GENERAL1_MEDIUM*.


##### Caches
This module supports provisioning a CodeBuild Project with custom Cache settings. This feature is enabled by providing a valid Cache Type to the *cache_type* variable. 

When the Cache Type is set to *LOCAL*, the *cache_modes* variable is required. Additionally, when the Cache Type is set to *S3*, the *cache_location* variable is required.

By default, the Cache Type is set to *NO_CACHE*.


##### Build Server Image
This module supports provisioning a CodeBuild Project that uses a specific image for the server on which the source code is built. This feature is enabled by providing a valid Image Identifier to the *image_id* variable.

By default, the CodeBuild Project is configured to use the *aws/codebuild/amazonlinux2-x86_64-standard:3.0* image, which fits majority of linux-based build requirements. 


##### Custom Timeout
This module supports provisioning a CodeBuild Project with a custom timeout. By default, CodeBuild Projects timeout within 1 hour, however, this timeout can be adjusted by providing a valid number to the *timeout* variable.

It is not recommended that the Timeout be configured to exceed 1 hour, however, in some cases it may be beneficial to set a shorter timeout.



#### Dependencies
The module has no dependencies.



## Example
#### Example with only *required* variables
        module "codebuild" {
          source          = "git::ssh://git@bitbucket.org/v-dso/codebuild-project?ref=v2.2"
          environment     = "prod"
          project         = "volly-example-project"
          service_name    = "example"
          kms_key_arn     = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

          providers = {
            aws.account = aws.example
          }
        }

#### Example with *all* variables
        module "codebuild" {
          source                  = "git::ssh://git@bitbucket.org/v-dso/codebuild-project?ref=v2.2"
          environment             = "prod"
          project                 = "volly-example-project"
          service_name            = "example"
          kms_key_arn             = "arn:aws:kms:us-east-1:xxxxxxxxxxxx:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          environment_type        = "WINDOWS_CONTAINER"
          compute_type            = "BUILD_GENERAL1_2XLARGE"
          cache_type              = "S3"
          cache_mode              = "LOCAL_SOURCE_CACHE"
          cache_location          = "volly-example=bucket-name"
          image_id                = "aws/codebuild/standard:1.0"
          privileged_mode         = false
          build_timeout           = 30
          buildspec               = data.buildspec.json
          artifacts_type          = "S3"
          artifacts_location      = "example-artifacts-bucket-name/artifacts/"
          artifacts_namespace     = "BUILD_ID"
          artifacts_override_name = true 
          artifacts_zip_package   = false
          environment_variables   = {
              example  = example,
              example2 = example2
          }

          providers = {
            aws.account = aws.example
          }
        }



## Variables

#### Required Variables
* **environment** *string* = Environment that the Code Build Project will support. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **project** *string* = Friendly name of the project the Code Build Project supports. 
    * Provided value is used to establish a name for the Code Build Project.
      * Code Build Project name is generated by appending the *service_name* to the *project*
* **service_name** *string* = Friendly name for the service teh Code Build Project supports.
    * The module will automatically prepend the provided value with the Project Name when naming resources.    
* **kms_key_arn** *string* = ARN of the KMS Key used to encrpyt the artifacts produced by the Code Build Project.



#### Optional Variables

##### Custom Build Spec
* **buildspec** *object* = JSON-encoded or YAML-Encoded Build Spec document for the CodeBuild Project.


##### Environment Variables
* **environment_variables** *map* = Map of Environment Variable keys and values to pass to the CodeBuild Project. 

##### Artifacts
* **artifacts_type** *string* = Type of artifacts to output from CodeBuild. 
    * Valid options are *NO_ARTIFACTS*, *S3*, or *CODEPIPELINE*.
    * When set to *S3*, *artifacts_location* is required.
* **artifacts_location** *string* = The S3 Bucket and Path to which Artifacts are stored.
    * Only valid when *artifacts_type* is set to *S3*.
    * Required when *artifacts_type* is set to *S3*.
* **artifacts_namespace** *string* = The namespace to include in the path to which Artifacts are stored. 
    * Only valid when *artifacts_type* is set to *S3*.
    * Valid options are *BUILD_ID* or *NONE*.
    * Defaults to *NONE*.
    * When set to *BUILD_ID*, the CodeBuild BuildId will be inserted into the artifacts_location.
* **artifacts_zip_package** *boolean* = Sets whether to zip the final Artifacts package before uploading to the specified location.
    * Only valid when *artifacts_type* is set to *S3*.
    * Defaults to *true*.
* **artifacts_override_name** *boolean* = Sets whether to allow the CodeBuild BuildSpec to set the location and/or name of the Artifact package.
    * Only valid when *artifacts_type* is set to *S3*.
    * Defaults to *false*.
    * This may be useful when generating a unique artifacts_location based on CodeBuild variables


##### Environment Type
* **environment_type** *string* = The type of environment to be used when performing the build process.
    * Valid options are *LINUX_CONTAINER*, *LINUX_GPU_CONTAINER*, *WINDOWS_SERVER_2019_CONTAINER*, or *ARM_CONTAINER*.
    * Defaults to *LINUX_CONTAINER*.


##### Compute Type
* **compute_type** *string* = The type of compute to be used when performing the build process.
    * Valid options are *BUILD_GENERAL1_SMALL*, *BUILD_GENERAL1_MEDIUM*, *BUILD_GENERAL1_LARGE*, or *BUILD_GENERAL1_2XLARGE*.
    * Defaults are as follows:
        * When Environment Type is *LINUX_CONTAINER*, the default Compute Type is *BUILD_GENERAL1_SMALL*.
        * When the Environment Type is *LINUX_GPU_CONTAINER*, the module will force a Compute Type of *BUILD_GENERAL1_LARGE* as that is the only valid Compute Type for the Environment Type.
        * When the Environment Type is set to any other value, the default Compute Type is *Build_GENERAL1_MEDIUM*.


##### Caches
* **cache_type** *string* = Type of Cache to be used by the CodeBuild Project when performing the build process.
    * Valid options are *NO_CACHE*, *LOCAL*, or *S3*.
    * Defaults to *NO_CACHE*.
* **cache_mode** *string* = Settings used by the CodeBuild Project to store and reuse dependencies when performing the build process.
    * Valid options are *LOCAL_SOURCE_CACHE*, *LOCAL_DOCKER_LAYER_CACHE*, or *LOCAL_CUSTOM_CACHE*
    * Only valid when *cache_type* is set to *LOCAL*.
* **cache_location** *string* = Name of the S3 Bucket used by the CodeBuild Project to store and reuse dependencies when performing the build process.
    * Only valid when *cache_type* is set to *S3*.
    * A Prefix may be appended to the S3 Bucket location to specify a specific directory location to be used by the CodeBuild Project.


##### Build Server Image
* **image_id** *string* = ID of the Machine Image for the server on which the source code is built.
    * Valid options are listed in the [AWS Documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html).
    * Defaults to *aws/codebuild/amazonlinux2-x86_64-standard:3.0*.


##### Custom Timeout
* **timeout** *number* = Amount of time that the CodeBuild Project may attempt to run without success before timing out.
    * Defaults to 1 (hour).



## Outputs

##### CodeBuild Project Outputs
* **project_name** = Friendly name of the CodeBuild Project.
* **project_arn** = ARN of the CodeBuild Project.
* **project_id** = ID of the CodeBuild Project.


##### IAM Role Outputs
* **codebuild_role_name** = Friendly name of the IAM Role used by CodeBuild to run the build process.
* **codebuild_role_arn** = ARN of the IAM Role used by CodeBuild to run the build process.
* **codebuild_role_id** = ID of the IAM Role used by CodeBuild to run the build process.
* **codebuild_role_unique_id** = Unique identifier of the IAM Role used by CodeBuild to run the build process.