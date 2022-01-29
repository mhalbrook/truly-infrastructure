# Volly Terraform Library Module | Load Balancer

**Current Version**: v3.0

This module creates either an Application or Network Load Balancer, Load Balancer Listeners and Target Groups. Either type may be configured with Static IPs. Additionally, when provisioning an Application Load Balancer, a Security Group, with baseline rules, is attached to the Load Balancer and Listener Rules are generated to direct traffic to specific Target Groups.


## Known Issues
The following are known issues within the Load Balancer Library Module. These issues are primarily driven by the behavior of either Terraform or the AWS resources managed by the module.

1. While this module supports both Application and Network Load Balancers, the module cannot always gracefully change the type of an existing Load Balancer.

  * **Cause:** Application and Network Load Balancers are considered different resources within AWS, therefore Terraform must destroy andd re-create the Load Balancer when changing types. 
  * **Workaround:** If the application supported by the Load Balancer may take an outage, it is ok to allow Terraform to destroy and recreate the Load Balancer per it's normal behavior, however, in the event that the Load Balancer may not be destroyed, a new Load Balancer of the correct type should be provisioned alongside the existing Load Balancer. Once workloads are shifted to the new Load Balancer, the old Load Balancer may be destroyed.


2. Once Static IPs are associated with a *Network* Load Balancer, they may not be removed.

  * **Cause:** AWS does not support the removal of Elastic IPs from a running network interface, therefore, the Load Balancer must be destroyed before the Elastic IPs may be disassociated.
  * **Workaround:** In the event that Static IPs are no longer required, a new Load Balancer without Static IP assignments should be provisioned alongside the existing Load Balancer. Once workloads are shifted to the new Load Balancer, the old Load Balancer may be destroyed.


3. Terraform will fail when the *protocol* of a Load Balancer Listener is changed by removing the certificate configuration

  * **Cause:** Certain arguments are considered *optional* within Terraform, meaning that, if the argument is not defined, the default value for that argument will be used. AWS will default to setting the *ssl policy* configuration of Load Balancer Listener to teh existing value, therefore, Terraform will attempt to alter the Listener's *protocol* without changing the *ssl policy*. Since Listeners configured without certificates cannot have an *ssl policy*, Terraform will fail to update the Listener.
  * **Workaround:** To reprovision the Load Balancer Listener with the appropriate *protocol*, first taint the Load Balancer Listener. This will cuase Terraform to destroy and re-create the Listener on the next *apply*.
    * Note that tainting the Listener will cause in the Listener to be *destroyed*, which may result in an application outage. It is best to ensure this action is taken off-hours for Production Load Balancers.


4. Terraform will fail when attempting to replace a Target Group (Target group is currently in use by a listener or a rule).

  * **Cause:** The Target Group is in-use by a Listener Rule or a Default Listener, however, Terraform cannot break this dependency automatically as the Rule or Listener would then have no target, which is not allowed by the AWS API.
    * **Workaround:** Run *Terraform destroy* on the Listener or Listener Rule, which will result in the Listener or Listener Rule and the Target Group being replaced simultaneously. 
        * For example, with Listener Rules, *terraform destroy --target 'module.example.aws_lb_listener_rule.listener_rule[\"examle-listener-rule-name\"]'*
        * For example, with Listener, *terraform destroy --target 'module.example.aws_lb_listener.listener[\"listener-port\"]'*




## USAGE

#### Providers
From a root module, set a provider for the account in which to build the Load Balancer. When calling this Library module, set the provider equal to *aws.account*.


#### Features 

##### Internet-Facing Load Balancer
This module supports configuring either Application or Network Load Balancers for inbound traffic from the internet. To enable this feature, set the *subnet_layer* variable to *public*. 

When provisioning an **Application** Load Balancer for internet access, the Security Group attached to the Load Balancer is configured to allow inbound traffic from the internet for the ports on which the Load Balancer listens, which, by default, will be port 80 (HTTP) and 443 (HTTPS). However, the NACL attached to the Public Subnet of the VPC must also be configured to allow traffic from the internet on the required ports. If the VPC was deployed via Volly's Terraform Library Module, and the default ports are used, the NACL attached to the Public Subnet will already be configured to allow this traffic.

**Network** Load Balancers do not support Security Groups, therefore, the only network consideration, when provisioning this type of Load Balancer, is the NACL attached to the Public Subnet of the VPC.


##### Static IPs
This module supports configuring either Application or Network Load Balancers with Static IPs, however, the configuration of static IPs is different for each type of Load Balancer. This feature is enabled for either Load Balancer type by setting the *enable_static_ip* variable to *true*.

###### Application Load Balancer
AWS does not support attaching Elastic IPs to Application Load Balancers, however, static IPs may be associated with an Application Load Balancer via AWS Global Accelerator. AWS Global Accelerator provisions a *global* endpoint with static IPs that may listen on specific ports and forward traffic to an endpoint group. When this feature is enabled, a Global Accelerator is provisioned to listen on the relevant ports and direct traffic to the Application Load Balancer.

###### Network Load Balancer
When enabling this feature for Network Load Balancers, two Elastic IPs are provisioned, one of each subnet in which the Load Balancer resides. These Elastic IPs are then attached to the Network Load Balancer.


##### Custom Listeners
This module supports configuring either Application or Network Load Balancers with multiple listeners on different ports. This feature is enabled by providing a valid Listener configuration to the *listeners* variable. 

The *listeners* variable requires a map where the *key* is the port on which the Load Balancer listens and the *values* set the configuration of the Listener. The map must include the following arguments:

  * **target_group_name** = The name of the Target Group to which the Load Balancer will forward traffic by default.
  * **certificate_arns** = A list of SSL Certificate ARNs to be attached to the listener. 
    * When provisioning a Network Load Balancer, this argument may be set to *[]* to configure a Listener without a certificate

###### Application Load Balancer
By default, Application Load Balancers are configured with two listeners; one listening on port 80 and one listening on port 443. In most cases this is sufficient, however, the module allows for the configuration of customized listeners in the event that the Load Balancer must listen on an abnormal port. 

  * When provisioning an Application Load Balancer with custom Listeners, a default rule will be created to forward traffic to the specified Target Group.
    * Application Load Balancers support Listener Rules, which may be configured to forward traffic to additional Target Groups. Review the **listener rules** feature section below for more details.
  * When provisioning an Application Load Balancer with custom Listeners, at least one Certificate ARN must be provided for each listener. 
    * Wwhen provisioning an Application Load Balancer **without** custom listeners, a list of Certificate ARNs should be provided to the *certificate_arns* variable. Review the *certificates* feature section below for more details.

###### Network Load Balancer
When provisioning a Network Load Balancer, the *listeners* variable is required as no Listeners are provisioned by default. 

  * Network Load Balancers do not support Listener Rules, therefore all traffic received by the Listener will be forwarded to the specified Target Group.
  * Network Load Balancers may be configured without a certificate by setting the *certificate_arn* variable to *[]*. 
    * When at least one certificate is configured for a Listener, that Listener's protocol will be set to TLS, allowing decryption to be off-loaded to the Load Balancer. 
    * When no certificates are configured for a Listener, that Listener's protocol will be set to TCP, requiring decryption to be handled by the endpoints within the associated target Group. 


##### Multiple Target Groups
This module supports provisioning multiple Target Groups to which the load Balancer will direct traffic. This feature is enabled by providing more than one valid configuration to the *target_groups* variable.

The *target_groups* variable requires a map where the *key* is the desired friendly name of the Target Group and the *values* set the configuration of the Target Group. The map must include the following arguments:

  * **port** = The port on which the targets will receive traffic. Note that the port **does not** have to align to any port on which the Load Balancer listens.
  * **protocol** = The protocol used to deliver traffic to the targets. Not that the protocol **does not** have to align to the protocol used by the Load Balancer, however, it is common that it does.
  * **type** = The type of endpoints that can be registered to the Target Group (i.e. *instance* or *ip*).
  * **health_check_path** = The path to the *health check file* hosted on the targets. This argument is ignores when provisioning a Target Group using the *TCP* protocol as health check paths are not supported by the *TCP* protocol.
  * **health_check_protocol** = Protocol to be used when delivering health check reuqests to targets.

The module will automatically prepend the provided Target Group Name with the full name of the Load Balancer.


##### Listener Rules
This module supports configuring one, or many, Listener Rules per Application Load Balancer Listener. AWS does not support Listener Rules for Newtork Load Balancers. This feature is enabled by providing a valid configuration to the *listener_rules* variable.

The *listener_rules* variable requires a map where the *key* is a friendly name for the Listener Rule and the *values* set the configuration of the Listener Rule. The map must include the following arguments:
    * **priority** = the prioritization of the Listener Rule. When a request matches the condition of multiple Listener Rules, the action of the highest-priority Listener Rule will be applied.
    * **listener_port** = The port associated with the Load Balancer Listener to which the Listener Rule should be associated.
    * **target_group_name** = The Friendly Name of the Target Group that the Load Balancer will forward traffic to when the condition of the Listener Rule is met.
    * **host_header** = A list of domain names to match against requests to determine if the Listener Rule action should be applied (i.e. if the host_header is set to example.com, requests to this domain will be subject to the Listener Rule)
    * **path_pattern** = A list of paths to match against requests to determine if the Listener Rule action should be applied (i.e. if the path_pattern is set to */example/*, requests to *example.com/example* will be subject to the Listener Rule)
    * **https_header** = A map of Header Names and Values to match against requests to determine if the Listener Rule action should be applied (i.e. if the http_header is set to {example = value}, requests containing that value within the request header will be subject to the Listener Rule)


##### Certificates 
This module supports configuring Load Balancer Listeners with the HTTPS (Application Load Balancers) or TLS (Network Load Balancers) by associating certificates with the Load Balancer Listeners. This feature is enabled in various ways depending on the Load Balancer Type and configuration.

###### Application Load Balancers
To ensure that Volly applications remain in-compliance with Client requirements that all traffic remain encrypted in-transit, this module does not support configuring HTTP Listeners for Application Load Balancers, except for the default HTTP Listener, which redirects traffic to the default HTTPS Listener. Therefore, at least one certificate must be configured for each Load Balancer Listener.

  * When provisioning an Application Load Balancer with *default* Listeners, certificates are configured by providing a list of valid certificate ARNs to the *certificate_arns* variable. 

  * When provisioning an Application Load Balancer with *custom* Listeners, certificates are configured by providing a list of valid certificate ARNs to the *certificate_arns* argument within the *listeners* variable. For more details on provisioing *custom* Listeners, review the **Custom Listeners** feature section above.

###### Network Load Balancers
This module supports configuring either TLS or TCP Listeners for Network Load Balancers. TLC listeners allow encryption to be off-loaded to the Load Balancer, similar to the behavior of HTTPS Listener configured for Application Load Balancers. TCP Listeners forward encrypted traffic to targets, which must be configured with the appropriate certificates required to decrypt the requests. Note that, while *Listeners* may be configured to use the TCP Protocol, Target Groups can only be configured to use the *TLS* protocol to ensure that Volly applications remain in-compliance with Client requirements that all traffic remain encrypted in-transit.

  * A TLS Listener is provisioned when a list of one or more valid certificate ARN(s) are provided to the providing a list of valid certificate ARNs to the *certificate_arns* argument within the *listeners* variable.

  * A TCP Listener is provisioned when the *certificate_arns* argument within the *listeners* variable is set to *[]*.


##### Health Checks
This module supports customizing the Health Check configuration of Target Groups. This feature allows the Load Balancer to be appropriately tuned to detect changes in the health of endpoints targetted by the Load Balancer. Some Health Check configurations are only supported by Application Load Balancers, which other configurations are supported by either Application or Network Load Balancers.

###### Configurations Applicable to All Load Balancer Types

  * **health_check_healthy_threshold** = The number of consecutive successful health checks required before considering an *unhealthy* target as *healthy*.
  * **health_check_unhealthy_threshold** = The number of consecutive unsuccessful health checks required before considering a *healthy* target as *unhealthy*.
  * **health_check_interval** = The approximate amount of time, in seconds, between health checks of an individual target.

###### Configurations Applicable to Application Load Balancers

  * **health_check_timeout** = The amount of time, in seconds, in which the Load Balancer waits for a response to a health check request before considering the health check as unsuccessful.
  * **health_check_matcher** = HTTP response codes that the Load Balancer should consider as successful responses to health check requests (i.e. 200).


##### Service Discovery
The module supports registering the Load Balancer with an AWS Cloud Map Namespace for Service Discovery. When registered, the Load Balancer is discoverable by other services via DNS or API lookup of the Cloud Map Service. This feature is enabled by providing a valid Cloud Map Namespace ID to the *namespace_id* variable. The provided Namespace must exist in the AWS Account in which the Load Balancer is provisioned.

When Service Discovery is enabled within the module, the *service_discovery_name* variable is required. The value provided to the *service_discovery_name* variable will be configured as the name of the service within the Cloud Map Namespace. For example, if the Load Balancer is being registered to a Namespace of *example.private* and the *service_discovery_name* variable is set to *balancer*, then the Load Balancer would be discoverable at *balancer.example.private*.



##### Load Balancing Algorithms
This module supports customizing the Load Balancing Algorithm used when delivering requests to targets. By default, the algorithm is set to *Round-Robin*, however, the algorithm may be change to *Least Outstanding Request* by setting the *load_balancing_algorithm* variable to *least_outstanding_requests*.

  * **round_robin** = The Load Balancer will deliver requests to targets in a consistent order.
  * **least_outstanding_requests** = The Load Balancer will deliver requests to whichever target has the least amount of active connections.


##### Sticky Sessions 
This module supports configuring Sticky Sessions within Target Groups. Sticky Sessions ensure that requests sent by the same client are delivered to the same endpoint within a Target Group for a specified period of time. This feature is enabled by providing a number value to the *sticky_session_duration* variable. The value provided will be configured as the amount of time, in seconds, that requests should be delivered to the same target within the Target Group.

It is not reccommended to configure Sticky Sessions for a Load Balancer's Target Groups, however, this configuration may be neccessary when Load Balancing an application that cannot manage application sessions across multiple endpoints.


##### Deletion Protection
This module supports configuring Load Balancers to protect against accidental deletion. By default, Deletion Protection is **enabled**. This feature may be disabled by setting the *enable_deletion_protection* variable to false.

It is not recommended to disable deletion protection, however, disabling this feature may be helpful when testing configuration of a new Load Balancer, where the configuration may need to be altered numerous times, requiring peridic deletion and recreation of the Load Balancer. Additionally, this feature should be disabled prior to destroying an existing Load Balancer.


##### Deregistration Delay
This module supports customizing the Deregistration Delay of targets within Target Groups. This feature is enabled by providing a number value to the *deregistration_delay* variable. The value provided sets the amount of time, in seconds, to retain a target within a Target Group after that target has been deregistered. Setting this value appropriately helps ensure that the application and Load Balancer have enough time to close any open connections prior to a target beceoming unreachable due to deregistration. By default, the Deregistration Delay is set to *120 (2 minutes)*. 

Altering the default Deregistration Delay is not reccommended, however, it may be useful when testing changes that may result in numerous targets being deregistered and re-registered.

 

#### Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules.  

The following resources are always required for the module:
    * VPC

The following resources are required when provisioning an Application Load Balancer, or a Network Load Balancer with a TLS Listener:
    * AWS Certificate Manager Certificate

The following resources are required when provisioning a Load Balancer with Service Discovery:
    * AWS Cloud Map Namespace



## Example
### Application Load Balancer
#### Example with only *required* variables
    module "load_balancer" {
      source             = "git::ssh://git@bitbucket.org/v-dso/load-balancer"
      load_balancer_type = "application"
      project            = "volly-example-project"
      environment        = "prod"
      vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
      subnet_layer       = "public"
      service_name       = "example"
      certificate_arns   = ["arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"]
      target_groups      = {
        example = {
          port                  = 8000 
          protocol              = "HTTPS"
          type                  = "instance"
          health_check_path     = "/healthcheck.html"
          health_check_protocol = "HTTPS"
        }
      }

      providers = {
        aws.account = aws.example
      }
    }

#### Example with *all* variables
    module "load_balancer" {
      source                           = "git::ssh://git@bitbucket.org/v-dso/load-balancer"
      load_balancer_type               = "application"
      project                          = "volly-example-project"
      environment                      = "prod"
      vpc_id                           = "vpc-xxxxxxxxxxxxxxxxx"
      subnet_layer                     = "public"
      namespace_id                     = "ns-xxxxxxxxxxxxxxxx" 
      service_discovery_name           = "balancer"
      service_name                     = "example"
      certificate_arns                 = ["arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"]
      enable_static_ips                = true
      load_balancing_algorithm         = "least_outstanding_requests"
      sticky_session_duration          = 3600 
      deregistration_delay             = 300
      enable_deletion_protection       = false
      health_check_healthy_threshold   = 3
      health_check_unhealthy_threshold = 3
      health_check_interval            = 15
      health_check_timeout             = 10
      health_check_matcher             = "200,403"
      listeners                        = {
        443 = {
          target_group_name = "example01"
          certificate_arns  = ["arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"]
        },
        5000 = {
          target_group_name = "example02"
          certificate_arns  = [
            "arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", 
            "arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", 
          ]
        }
      }
      target_groups                    = {
        example01 = {
          port                  = 8000 
          protocol              = "HTTPS"
          type                  = "instance"
          health_check_path     = "/healthcheck.html"
          health_check_protocol = "HTTPS"
        },
        example02 = {
          port                  = 9000 
          protocol              = "HTTPS"
          type                  = "ip"
          health_check_path     = "/healthcheck.html"
          health_check_protocol = "HTTPS"
        }
      }
      listener_rules = {
        example-rule-1 = {
          priority          = 1
          listener_port     = 443
          target_group_name = "example01"
          host_header       = ["example.com", "one.example.com"]
          path_pattern      = ["/hello/"]
          http_header       = {
              example = ["values"]
          }
        },
        example-rule-2 = {
          priority          = 2
          listener_port     = 5000
          target_group_name = "example02"
          host_header       = ["two.example.com"]
          path_pattern      = []
          http_header       = {}
        }
      }

      providers = {
        aws.account = aws.example
      }
    }


### Network Load Balancer
#### Example with only *required* variables
    module "load_balancer" {
      source             = "git::ssh://git@bitbucket.org/v-dso/load-balancer"
      load_balancer_type = "network"
      project            = "volly-example-project"
      environment        = "prod"
      vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
      subnet_layer       = "private"
      service_name       = "example"
      listeners          = {
        5000 = {
          target_group_name = "example"
          certificate_arns = [] 
        }
      }
      target_groups      = {
        example = {
          port                  = 8000 
          protocol              = "TCP"
          type                  = "instance"
          health_check_path     = ""
          health_check_protocol = "TCP"
        }
      }

      providers = {
        aws.account = aws.example
      }
    }

#### Example with *all* variables
    module "load_balancer" {
      source                           = "git::ssh://git@bitbucket.org/v-dso/load-balancer"
      load_balancer_type               = "network"
      project                          = "volly-example-project"
      environment                      = "prod"
      vpc_id                           = "vpc-xxxxxxxxxxxxxxxxx"
      subnet_layer                     = "private"
      namespace_id                     = "ns-xxxxxxxxxxxxxxxx" 
      service_discovery_name           = "balancer"
      service_name                     = "example"
      enable_static_ips                = true
      load_balancing_algorithm         = "least_outstanding_requests"
      sticky_session_duration          = 3600 
      deregistration_delay             = 300
      enable_deletion_protection       = false
      health_check_healthy_threshold   = 3
      health_check_unhealthy_threshold = 3
      health_check_interval            = 10
      listeners                        = {
        5000 = {
          target_group_name = "example01"
          certificate_arns = [
            "arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", 
            "arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", 
          ] 
        },
        6000 = {
          target_group_name = "example02"
          certificate_arns = ["arn:aws:acm:us-east-1:xxxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"] 
        }
      }
      target_groups                    = {
        example01 = {
          port                  = 8000 
          protocol              = "TLS"
          type                  = "instance"
          health_check_path     = ""
          health_check_protocol = "HTTPS"
        },
        example02 = {
          port                  = 8000 
          protocol              = "TLS"
          type                  = "ip"
          health_check_path     = ""
          health_check_protocol = "TCP"
        }
      }

      providers = {
        aws.account = aws.example
      }
    }



## Variables

#### Required Variables
* **environment** *string* = Environment that the Load Balancer supports. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **load_balancer_type** *string* = Type of Load Balancer to provision.
    * Valid options are *network* or *application*.
* **project** *string* = Friendly name of the project the Load Balancer supports. 
    * Provided value is used to establish a name for the Load Balancer.
      * Load Balancer name is generated by appending the *environment* and an abreviation of the Load Balancer type to the *project*
* **vpc_id** *string* = ID of the VPC in which to provision the Load Balancer.
* **subnet_layer** *string* = The subnet layer in which to provision the Load Balancer.
    * Valid options are *public*, *private*, or *data*.
    * Defaults to *private*.
* **service_name** *string* = Friendly name of the service that the Load Balancer supports.
    * The module will automatically prepend the provided value with the Project Name when naming resources.     
* **target_groups** *map* = Map of configuration of Target Groups to which the Load Balancer will forward requests.
    * When set, the following arguments must be set within the map:

        * **port** *number* = The port on which the Target Group listens.
        * **protocol** *string* = The protocol of requests received by the Target Group.
            * Valid options for Network Load Balancers are *HTTPS*, *TCP*, or *TLS*.
            * Valid option for Application Load Balancers is *HTTPS*.
        * **type** *string* = Type of endpoints that will be registered to the target group. 
            * Valid options are *instance*, for EC2 Instance, or *ip*. 
        * **health_check_path** *string* = Path to the endpoint used to check the health of the service running on on teh targets within the Target Group.
            * If protocol is not set to *HTTPS*, set this argument to *""*.


#### Required Variables for Application Load Balancers
* **certificate_arns** *list* = List of AWS Certificate Manager Certificate ARNs to be attached to the Load Balancer.
    * If configuring an Application Load Balancer with custom Listeners, set the Certificate ARNs within the Listener argument and ignore this variable.


#### Required Variables for Network Load Balancers
* **listeners** *map* = Map of configuration of Load Balancer Listeners.
    * Allows for the configuration of multiple Listeners where the *port* on which the Listener receives traffic is set as the map's *key*.
    * The following arguments must be set within the map:

        * **target_group_name** *string* = Friendly name of the Target group to which the Listener will forward requests.
        * **certificate_arns** *list* = List of AWS Certificate Manager Certificate ARNs to be attached to the Listener.


#### Optional Variables

##### Static IPs
* **enable_static_ips** *boolean* = Sets whether to configure the Load Balancer to be assocaited with Static IP Addresses.
    * Defaults to *false*.


##### Custom Listeners (Application load Balancers)
* **listeners** *map* = Map of configuration of Load Balancer Listeners.
    * Allows for the configuration of multiple Listeners where the *port* on which the Listener receives traffic is set as the map's *key*.
    * The following arguments must be set within the map:

        * **target_group_name** *string* = Friendly name of the Target group to which the Listener will forward requests.
        * **certificate_arns** *list* = List of AWS Certificate Manager Certificate ARNs to be attached to the Listener.


##### Listener Rules (Application Load Balancers)
* **listener_rules** *map* = Map of configuration of Load Balancer Listener Rules.
    * Allows for the configuration fo multiple Listener Rules.
    * The following arguments must be set within the map:
          * **priority** = the prioritization of the Listener Rule. 
              * When a request matches the condition of multiple Listener Rules, the action of the highest-priority Listener Rule will be applied.
          * **listener_port** = The port associated with the Load Balancer Listener to which the Listener Rule should be associated.
          * **target_group_name** = The Friendly Name of the Target Group that the Load Balancer will forward traffic to when the condition of the Listener Rule is met.
          * **host_header** = A list of domain names to match against requests to determine if the Listener Rule action should be applied.
              * For example, if the host_header is set to example.com, requests to this domain will be subject to the Listener Rule.
          * **path_pattern** = A list of paths to match against requests to determine if the Listener Rule action should be applied.
              * For example, if the path_pattern is set to */example/*, requests to *example.com/example* will be subject to the Listener Rule.
          * **https_header** = A map of Header Names and Values to match against requests to determine if the Listener Rule action should be applied.
              * For example, if the http_header is set to {example = value}, requests containing that value within the request header will be subject to the Listener Rule)


##### Health Checks
###### Configurations Applicable to All Load Balancer Types
* **health_check_healthy_threshold** *number* = The number of consecutive successful health checks required before considering an *unhealthy* target as *healthy*.
* **health_check_unhealthy_threshold** *number* = The number of consecutive unsuccessful health checks required before considering a *healthy* target as *unhealthy*.
* **health_check_interval** *number* = The approximate amount of time, in seconds, between health checks of an individual target.
    * When creating a Network Load Balancer with TCP Target Groups, the interval must be set to *10* or *30*.

###### Configurations Applicable to Application Load Balancers
* **health_check_timeout** *number* = The amount of time, in seconds, in which the Load Balancer waits for a response to a health check request before considering the health check as unsuccessful.
* **health_check_matcher** *string* = HTTP response codes that the Load Balancer should consider as successful responses to health check requests (i.e. 200).


##### Service Discovery
* **namespace_id** *string* = "ID of the Cloud Map Namespace to which the Load Balancer is registered.
* **service_discovery_name** *string* = Name, under which, the Load Balancer is registered to the Cloud Map Namespace.


##### Load Balancing Algorithms
* **load_balancing_algorithm** *string* = The Load Balancing Algorithm used when delivering requests to targets.
    * Valid options are *rount-robin* or *least_outstanding_requests*.
    * Defaults to *round_robin*.


##### Sticky Sessions 
* **sticky_session_duration** *number* = The amount of time, in seconds, that requests should be delivered to the same target within the Target Groups assocaited with the Load Balancer.
    * Sticky Sessions may not be configured with Target Groups are provisioned with the TCP Protocol.


##### Deletion Protection
* **enable_deletion_protection** *boolean* = Sets whether to protect the Load Balancer from accidental deletion.
    * Defaults to *true*


##### Deregistration Delay
* **deregistration_delay** *number* = The amount of time, in seconds, to retain a target within a Target Group after that target has been deregistered.
    * Defaults to *120 seconds*.



## Outputs

##### Load Balancer Outputs
* **load_balancer_dns_name** = AWS DNS Name of the Load Balancer.
* **load_balancer_arn** = ARN of the Load Balancer.
* **load_balancer_zone_id** = ID of the zone in whith the Load Balancer is provisioned.


##### Load Balancer Listener Outputs
* **load_balancer_listener_id** = List of IDs of the Listeners associated with the Load Balancer.
    * Excludes HTTP listener when provisioning an Application Load Balancer *without* custom Listeners.
* **load_balancer_listener_arn** = List of ARNs of the Listeners associated with the Load Balancer.
    * Excludes HTTP listener when provisioning an Application Load Balancer *without* custom Listeners.
* **load_balancer_http_listener_id** = List of ID of the HTTP Listener associated with the Load Balancer.
    * Only relevant when provisioning an Application Load Balancer *without* custom Listeners.
    * Output is presented as a list to ensure proper handling when HTTP Listener is not provisioned.
* **load_balancer_http_listener_arn** = List of ARN of the HTTP Listener associated with the Load Balancer.
    * Only relevant when provisioning an Application Load Balancer *without* custom Listeners.
    * Output is presented as a list to ensure proper handling when HTTP Listener is not provisioned.


##### Target Group Outputs
* **target_group_names** = List of friendly names of the Target Groups associated with the Load Balancer.
* **target_group_arns** = List of ARNs of the Target Groups associated with the Load Balancer.
* **target_group_ids** = List of IDs of the Target Groups associated with the Load Balancer.


##### Security Group Outputs
Security Group Outputs are presented as lists to ensure outputs are correctly handled when a Security Groups is not provisioned. In all cases, lists only include one element.
* **load_balancer_security_group_name** = Friendly name of the Security Group attached to the Load Balancer.
* **load_balancer_security_group_arn** = ARN of the Security Group attached to the Load Balancer.
* **load_balancer_security_group_id** = ID of the Security Group attached to the Load Balancer.


##### Elastic IP Outputs (Network Load Balancer Static IPs)
* **elastic_ip_allocation_ids** = List of Allocation IDs representing the allocation of the Elastic IPs for use with instances inside a VPC.
* **elastic_ip_ids** = List of IDs of the Elastic IPs associated to the Load Balancer.
* **elastic_ip_public_ips** = List of Public IPs associated to the Load Balancer.
* **elastic_ip_private_ips** = List of Private IPs associated to the Load Balancer.


##### Global Accelerator Outputs (Application Load Balancer Static IPs)
Global Accelerator Outputs are presented as lists to ensure outputs are correctly handled when a Global Accelerator Listener is not provisioned. In all cases, lists only include one element.
* **accelerator_id** = ID of the Global Accelerator associated with the Load Balancer.
* **accelerator_name** = Friendly name of the Global Accelerator associated with the Load Balancer.
* **accelerator_dns_name** = AWS DNS Name of the Global Accelerator associated with the Load Balancer.
* **accelerator_hosted_zone_id** = ID of the Hosted Zone in which the Global Accelerator associated with the Load Balancer is registered.
* **accelerator_ip_sets** = Map of the IP Details for the IP Addresses associated with the Load Balancer via the Global Accelerator.


###### Global Accelerator Listener Outputs
* *8accelerator_listener_id** = ID of the Global Accelerator Listener.
* *8accelerator_listener_arn** = ARN of the Global Accelerator Listener.


###### Global Accelerator Endpoint Group Outputs
* **accelerator_endpoint_group_id** = ID of the Global Accelerator Endpoint Group.
* **accelerator_endpoint_group_id** = ARN of the Global Accelerator Endpoint Group.