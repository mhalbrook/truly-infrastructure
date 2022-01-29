# Volly Terraform Library Module | Route53 Record

**Current Version**: v3.2

This module creates a DNS Record in an AWS Route53 Hosted Zone. The module may create records in Public or Private Hosted Zone and may be configured to conduct health checks on the created DNS Records.


## Known Issues

This module have no known issues.


## Usage

#### Providers
From a root module, set a provider for the account in which to provision the Route53 Record. When calling this Library module, set the provider equal to *aws.account*.


#### Features 
##### Public and Private Records
The module supports provisioning Route53 Records in either Public or Private Route53 Hosted Zones. By default, a a Public route53 Record is creates. A Private Route53 Record is generated when the *private_zone* variable is set to true.


##### Aliases
The module supports provisioning Route53 Alias Records. Alias Records may be used to target AWS Resources which have Dynamic IP Addresses, such as AWS Load Balancers. Additionally, Alias Records may be a Record Type of either *A* or *CNAME*. This feature is enabled by setting the *alias* variable to *true.

When this feature is enabled, the *zone_id* variable is required. 


##### Complex Routing
The module supports provisioning Route53 with Multivalue, Failover, Weighted or Latency Routing Policies. This feature is enabled by providing a valid Routing policy to the *routing_policy* variable.

  * **Multivalue Routing** = Routing Policy that allows a Route53 Record to return one of many possible Record values at random.
  * **Failover Routing** = Routing Policy with a Primary and Secondary Record Value. If the Primary Record fails a health check, the Secondary Record is returned.
  * **Latency Routing** = Routing Policy with multiple region-specific Record Values. The record that provides the least latency is returned.
  * **Weighted Routing** = Routing Policy with multiple Record Values each provided a *weight*. Traffic is distributed across records based on the *weight* designation.


##### Health Checks
The module supports Health Checks for the Route53 Records, which may be used to handle failures and failovers when configured with a Complex Routing Policy. By default, this feature is enabled when a Complex Routing Policy is provided to the *routing_policy* variable. This feature is disbaled when the *health_check* variable is set to false and/or the *routing_policy* variable is set to *simple*.



#### Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules.  

The following resources are always required when provisioning a Route53 Record:

  * Route53 Hosted Zone




## Example
#### Example with only *required* variables
    module "route53_record" {
      source      = "git::ssh://git@bitbucket.org/v-dso/route-53-record"
      environment   = terraform.workspace
      record_name   = "example.com"
      record_type   = "A"
      record_values = ["32.x.x.x"]

      providers = {
        aws.account = aws.example
      }
    }

#### Example with *all* variables
    module "route53_record" {
      source      = "git::ssh://git@bitbucket.org/v-dso/route-53-record"
      private_zone             = true
      environment            = terraform.workspace
      apex_domain            = "one.example.private"
      record_name            = "one.example.private"
      record_type            = "A"
      record_values          = ["10.x.x.x", "10.x.x.x"]
      alias                  = true
      zone_id                = "Zxxxxxxxxxxxxx"
      ttl                    = 120
      routing_policy         = "failover"
      region                 = ["us-east-1", "us-west-2"]
      weight                 = 75
      health_check           = false 
      health_check_path      = "/healthcheck"
      health_check_threshold = 5 
      request_interval       = 15 

      providers = {
        aws.account = aws.example
      }
    }



## Variables

#### Required Variables
* **environment** *string* = Environment that Private Certificate Authority will support. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **record_name** *string* = Name of the Route 53 Record to be provisioned.
    * for example, *test.example.com*
* **record_type** *string* = The Type of Route 53 Record to be provisioned.
    * Valid options are *A*, *CNAME*, *MX*, *TXT*, *SRV*, or *NS*.
* **record_values** *list* = List of values to be targetted by the Route 53 Record.
    * For example, an IP Address for an A Record, or a Domain Name, for a CNAME Record.


#### Optional Variables

##### Private Record
* **private_zone** *boolean* = Sets whether the Route 53 Record is being provisioned within a Private Hosted Zone
    * Defaults to *false*, creating a Public Route 53 Record.

##### Aliases
* **alias** *boolean* = Sets whether the Route 53 Record is an Alias Record.
    * Alias Records may be used to target AWS Resources which have Dynamic IP Addresses, for example, AWS Load Balancers.
    * Defaults to *false*.
    * When set to *true*, the *zone_id* variable is required.
* **zone_id** *string* = The AWS Zone ID of the resource targetted by the alias record.
    * For example, if targetting an AWS Elastic Load Balancer, the Zone ID of the *Load Balancer* should be provided.

##### Complex Routing
* **routing_policy** = The name of the Routing Policy for the Route 53 Record.
    * Valid options are *simple*, *multivalue*, *latency*, *failover*, or *weighted*.
    * For details on each Complex Routing Type, review the *Complex Routing* Feature Section above. 
    * Defaults to *simple*.
*  **region** *list* = List of AWS Regions with which to associate Latency Routing Records.
    * Only valid when *routing_policy* is set to *latency*.
    * Requires multiple *record_values* to be provided.
    * When configured, requests will be served to the *record_value* that provides the lowest latency.
* **weight** *number* = The percentage of requests to be served by the Primary DNS Record for Weighted Routing Records.
    * Only valid when *routing_policy* is set to *weighted*.
    * The first value in the *record_value* variable is considered the *Primary Record*.

#### Health Checks
* **health_check** *boolean* = Sets whether to evaluate the health of the Route 53 Record Set.
    * Defaults to *true* when a Complex Routing Policy is configured.
* **heath_check_protocol** *string* = The protocol used to conduct health checks of the Route 53 Record Sets.
    * Valid options are *HTTP*, *HTTPS*, *HTTP_STR_MATCH*, *HTTPS_STR_MATCH*, or *TCP*.
    * Defaults to *HTTPS*.
* **health_check_port** *number* = The port used to conduct health checks of the Route 53 Record Sets.
* **health_check_path** *string* = The destination for the health check request of the Route 53 Record set.
    * Defaults to */*.
* **health_check_threshold** *number* = The number of health checks that must be successful or failed before the target is conisdered healthy or unhealthy.
    * Defaults to *3*.
* **health_check_interval** *number* = The amount of time (sec) that Route 53 waits between sending health checks requests.
    * Defaults to *30*.


## Outputs

#### Record Outputs
Record Outputs are presented as lists to ensure outputs are correctly handled when multiple records are created. Lists may include one or many elements.

* **record_name** = List of provisioned Route 53 Record names.
* **record_fqdn** = List of provisioned Route 53 Fully-Qualified Domain Names.
* **record_zone_id** = List of IDs of the Route 53 Hosted Zone in which Records are provisioned.


#### Health Check Outputs
Health Check Outputs are presented as lists to ensure outputs are correctly handled when health checks are not created. Lists may include none or many elements.

* **health_check_id** = List of IDs of the configured Route 53 Health Checks.
* **health_check_name** = List of friendly names of the configured Route 53 Health Checks.

