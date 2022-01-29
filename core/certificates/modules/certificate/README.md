# Volly Terraform Library Module | AWS Certificate Manager Certificate

**Current Version**: v4.0

This module creates an Certificate within the AWS Certififcate Manager Service. Additionally, when creating a Public Certificate, DNS records are created within the Hosted Zone that manages DNS of the domain for which the Certificate is issued. This allows for automated validation of the provisioned certificate.



## USAGE

#### Providers
From a root module, set a provider for the account in which to provision the Certificate. When calling this Library module, set the provider equal to *aws.account*.
Additionally, set a provider for the volly-networking account and, when calling this Library module, set the provider equal to *aws.networking*. This provider allows the module to configure DNS records, in the volly-network account, for autoamted Certificate validation.


#### Features 

##### Public or Private Certificate
The module supports provisioning either Public or Private certificates. By default, a Public Certificate is provisioned. A Private Certificate is generated when a valid Private Certificate Authority ARN is provided to the *certificate_authority_arn* variable.


##### Subject Alternative Names
The module supports provisioning certificates that cover additional domain names, known as *Subject Alternative Names*. For example, if a Certificate is issued for *example.com*, connections to that domain may use the certificate, however, connections to *one.example.com* will fail. If a Certificate is issue for *example.com* with a Subject Alternative Name of *one.example.com*, both connections from the above example may use the certificate.

This feature is enabled by providing a valid list of Subject Alternative Names to the *subject_alternative_names* variable.


##### Certificate Validation
The module support autmated validation of Public Certificates via DNS records. In most cases, the module will create validation records in the appropriate Hosted Zone for automated validation. However, in the case that a Certificate is provisioned for a *subdomain* that has been *delegated* to its own Hosted Zone, the validation records created by default may not be appropriately configured. This is due to the fact that the module will default to creating validation records within the root Hosted Zone while DNS will resolve to the delegated Hosted Zone.

The module supports the above configuration by allowing the domain name of the appropriate Hosted Zone to be provided to the *validation_domain* variable. For example, if a Certificate is provisioned for *one.example.com*, which is delegated to its own Hosted Zone, a value of *one.example.com* may be provided to the *validation_domain* variable, which will result in the module provisioning validation DNS records within the delegated Hsoted Zone. If a value is not provided to the *validation_domain* variable, the validation DNS records will be provisioned within the Hosted Zone associated with *example.com*.

Finally, the module supports customizing the TTL of the validation DNS records. It is not recommended to adjust the default configuration, however, it may be neccessary while troubleshooting.



#### Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules.  

The following resources are required when provisioning a Public Certificate:

  * Route53 Hosted Zone

The following resources are required when provisioning a Private Certificate:

  * Private Certificate Authority




## Example
### Public Certificate
#### Example with only *required* variables
    module "certificate" {
      source      = "git::ssh://git@bitbucket.org/v-dso/acm-certificate"
      environment = "prod"
      domain_name = "example.com"

      providers = {
        aws.account    = aws.example
        aws.networking = aws.example
      }
    }

#### Example with *all* variables
    module "certificate" {
      source                    = "git::ssh://git@bitbucket.org/v-dso/acm-certificate"
      environment               = "prod"
      domain_name               = "one.example.com"
      apex_domain               = "one.example.com
      subject_alternative_names = ["test.one.example.com", "two.example.com"]

      providers = {
        aws.account    = aws.example
        aws.networking = aws.example
      }
    }


### Private Certificate
#### Example with only *required* variables
    module "certificate" {
      source                    = "git::ssh://git@bitbucket.org/v-dso/acm-certificate"
      environment               = "prod"
      domain_name               = "example.private"
      certificate_authority_arn = "arn:aws:acm-pca:us-east-1:xxxxxxxxxxxx:certificate-authority/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

      providers = {
        aws.account    = aws.example
        aws.networking = aws.example
      }
    }

#### Example with *all* variables
    module "certificate" {
      source                    = "git::ssh://git@bitbucket.org/v-dso/acm-certificate"
      environment               = "prod"
      domain_name               = "example.private"
      certificate_authority_arn = "arn:aws:acm-pca:us-east-1:xxxxxxxxxxxx:certificate-authority/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      subject_alternative_names = ["test.example.private", "one.example.private"]

      providers = {
        aws.account    = aws.example
        aws.networking = aws.example
      }
    }


## Variables

#### Required Variables
* **environment** *string* = Environment that the Certificate supports. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **domain_name** *string* = Fully-Qualified Domain Name for which the Certificate is issued. 

#### Optional Variables
##### Private Certificate
* **certificate_authority_arn** *string* = ARN of the Private Certificate Authority used to sign the Private Certificate.

##### Subject Alternative Names
* **subject_alternative_names** *string* = List of additional Domain Names to be covered by the issued Certificate.

##### Certificate Validation
* **validation_domain** *string* = Domain Name associated with the Hosted Zone in which DNS records are created to validate the issued Certificate.
    * Only valid for Public Certificates



## Outputs

#### Certificate Outputs
* **arn** = ARN of the issued Certificate.
* **id** = ID of the issued Certificate.
* **domain_name** = Domain Name assocaited with the issued Certificate.
* **domain_validation_options** = Set of objects that may be used to generate the DNS records required to validate the issued Certificate.

#### Validation Outputs
* **domain_validation_options** = Set of objects that may be used to generate the DNS records required to validate the issued Certificate.
* **validation_domain** = The domain associated with the Hosted Zone in which DNS records are created to validate the issued Certificate.
    * This output can be usefull in troubleshooting the validation behavior of root modules
* **validation_records** = A Map of the validation records created within the *validation_domain* Hosted Zone.
    * This output can be usefull in troubleshooting the validation behavior of root modules