# Volly Terraform Library Module | VPC

**Current Version**: v3.0

This module creates an AWS VPC with four network layers: Public, Private, Data, and Transit. Each subnet is configured with default routes and NACL Rules required for all Volly VPCs. Additionally, the module automatically attaches the VPC's Transit Layer Subnets with Volly's Transit Gateway for VPC inter-connectivity and configures the VPC to deliver Flow Logs to an AWS CloudWatch Log Group.

Finally, the VPC is configured to enable private connectivity between the VPC and AWS Services via VPC Endpoints. VPC Endpoints are configured for the following services:

    * S3
    * DynamoDB
    * Cloudwatch 
    * EC2
    * Autoscaling 
    * EBS
    * ECR
    * ECS
    * AppMesh
    * Private Certificate Authority



## Known Issues
There are no known issues with this module.



## USAGE

#### Providers
From a root module, set a provider for the account in which to build the App Mesh. When calling this Library module, set the provider equal to *aws.account*.


#### Features 

##### Domain Join
The module supports configuring the VPC with connectivity to the network where the Volly Domain Controllers are hosted, simplifying network configuration of applications with instances that must be joined to Volly's Domain. This feature is enabled by setting the *domain_join* variable to *true*.

While this feature configures the VPC's network for Domain Controller connectivity, the network where the Volly Domain Controllers are hosted is not configured by this module, therefore, updates to NACLs and/or Routes within that network may be required.


##### Internet Connectivity
By default, the module configures the VPC to allow inbound internet connections to the VPC's Public Subnet. However, the VPC may be configured to disable internet access, generating a VPC that can only be accessed from Volly's Campus Network. This feature may be useful for creating VPCs that hosts services used by Volly employees, but not by clients or other external stakeholders.

Internet access is disabled by setting the *internet_enabled* variable to false. By default, this variable is set to true.


##### Transit Gateway Attachments
Volly maintains a centralized Transit Gateway which enables connectivity between VPCs. The centralized Transit Gateway is shared with all AWS Accounts within the Volly AWS Organization, however, a Transit Gateway may need to be provisioned or shared if using this module with an AWS Account that is not a part of the Volly AWS Organization. 

It is rare that a Volly VPC requires connectivity via a Transit Gateway other than the centralized transit Gateway referenced in the above paragraph. It is more appropriate to share the centralized Transit Gateway with a new AWS Account than to provision an additional Transit Gateway.


##### Multiple Availability Zones
This module supports configuring multiple Availability Zones within the VPC. When additional Availability Zones are configured, the module generates a Public, Private, Data, and Transit Subnet within each additional Availability Zone with default Routes and NACL Rules. 

By default, the module will provision a VPC with **two** Availability Zones. Additional Availability Zones may be added by setting the *availability_zone_count* variable to a number greater than *two*.


##### Application Connectivity
This module supports configuring NACL rules to allow connectivity between the VPC's Public and Private Subnets in order to enable connectivity between the Public Layer and applications that will run within the VPC. This feature is enabled by provide a valid list of ports to the *application_ports* variable.

When enabled, outbound rules will be generated within the Public Subnet's NACL to allow connectivity to the Private Subnets on the specified ports. Additionally, inbound rules will be generated within the Private Subnet's NACL to allow connectivity from the Public Subnets on the specified ports.


##### Database Connectivity
This module supports configuring NACL rules to allow connectivity between the VPC's Private and Data Subnets in order to enable connectivity between application instances and databases instances that will run within the VPC. This feature is enabled by provide a valid list of ports to the *database_ports* variable.

When enabled, a outbound rules will be generated within the Private Subnet's NACL to allow connectivity to the Data Subnets on the specified ports. Additionally, inbound rules will be generated within the Data Subnet's NACL to allow connectivity from the Private Subnets on the specified ports.


##### ICMP 
This module supports configuring NACL rules to allow ICMP (ping) connectivity from Volly Campus and Local networks. This feature is enabled when the *enable_icmp* variable is set to *true*. 

Note that, in order to establish ICMP connections, ICMP must be enabled for the VPC **AND** instances within the VPC must be configured to accept ICMP connections.


#### Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules. 

The following resources are always required for the module:

  * Transit Gateway



## Example
#### Example with only *required* variables
    module "vpc" {
      source      = "git::ssh://git@bitbucket.org/v-dso/vpc"
      vpc_name    = "example-vpc-name"
      vpc_cidr    = "10.1.0.0/16"
      environment = "prod"

      providers = {
        aws.account = aws.cicd
      }
    }

#### Example with *all* variables
    module "vpc" {
      source                  = "git::ssh://git@bitbucket.org/v-dso/vpc"
      vpc_name                = "example-vpc-name"
      vpc_cidr                = "10.1.0.0/16"
      environment             = "prod"
      availability_zone_count = 3
      domain_join             = true
      domain_name             = "example.local"
      application_ports       = [8000, 9000]
      database_ports          = [1433, 3306]
      enable_icmp             = true

      providers = {
        aws.account = aws.cicd
      }
    }



## Variables

#### Required Variables
* **environment** *string* = Environment that the Virtual Gateway supports. 
    * Valid options are 'cit', 'uat', 'prod', or 'core'.
* **vpc_name** *string* = Friendly name for the VPC.
    * The full name of the VPC is created dynamically by appending the *environment* to the *vpc_name*.
* **vpc_cidr** *string* = CIDR of the VPC.
    * The VPC CIDR should utilize a subnet no smaller than 255.255.254.0 (/23) as the module generates subnets with 255.255.0.0 (/24) subnet masks.
      * It is recommended that the VPC CIDR utilize a 255.255.255.0 (/16) subnet mask.


#### Optional Variables

##### Domain Join
* **domain_join* *boolean* = Sets whether to create Routes and NACL Rules for access to the network where the Volly Active Directory instances are hosted.
    * Defaults to *false*.
    * When set to *true*, Private and Data subnets are configured with Routes to the Volly Domain Controllers and NACL Rules allowing inbound and outbound connections to/from the Volly Domain Controllers.
* **domain_name** *string* = The name of the Domain to which hosts within the VPC are joined.
    * Defaults to *loyaltyexpress.local*.
* **domain_ips** *list* = List of IPs of the Domain Controllers to which hosts within the VPC are joined.
    * Defaults to the IPs of the *loyaltyexpress.local* Domain Controllers.

##### Multiple Availability Zones
* **availability_zone_count** *number* = Sets the number of Availability Zones to provision within the VPC.
    * Defaults to *two*.

##### Application and Database Connectivity
* **database_ports** *list(number)* = A list of ports on which the databases running within the VPC listen.
* **application_ports** *list(number)* = A list of ports on which the applications running within the Private Subnet of the VPC listen.

##### ICMP
* **enable_icmp** *boolean* = Sets whether to generate NACL rules allowing ICMP traffic from Volly Campus and Local networks.
    * Defaults to *false*




## Outputs
#### VPC Outputs
* **vpc_name** = Friendly name of the VPC.
* **vpc_arn** = ARN of the VPC.
* **vpc_id** = ID of the VPC.
* **vpc_cidr** = CIDR Notation of the VPC.
* **availability_zones** = Name of the Availability Zones in which VPC resources are provisioned.


#### Internet Gateway Outputs
Internet Gateway Outputs are presented as lists to ensure outputs are correctly handled when no Internet Gateway is attached to the VPC. In all cases, lists only include one element.

* **internet_gateway_arn** = ARN of the Internet Gateway attached to the VPC.
* **internet_gateway_id** = ID of the Internet Gateway attached to the VPC.

#### NAT Gateway Outputs
NAT Gateway Outputs are presented as lists as the module always provisions at least two NAT Gateways. List may include two or more elements, depending on how many Availability Zones are configured within the VPC.

* **nat_gateway_ids** = List of the IDs of NAT Gateways provisioned in the Public Subnets of the VPC.
* **nat_gateway_public_ips** = List of the Public IPv4 Addresses associated with the NAT Gateways.
* **nat_gateway_private_ips** = List of the Private IPv4 Addresses associated with the NAT Gateways.

#### Transit Gateway Outputs

* **transit_gateway_id** = ID of the Transit Gateway to which the VPC is attached.


#### Subnet Outputs
Subnet Outputs are presented as Maps where each key corresponds to a Subnet Layer (Public, Private, Data, or Transit) and the values are lists of attributes. Each list may include two or more elements, depending on how many Availability Zones are configured within the VPC.

* **subnet_ids** = Map of Lists of the IDs of the Subnets provisioned within the VPC.
* **subnet_cidrs** = Map of Lists of the CIDR Notation of the Subnets provisioned within the VPC.

##### Example
The below example illustrates how the Subnet Outputs are configured as well as an example Local Block that references the VPC Module's Private Subnet IDs.
    subnet_ids = {
      public  = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
      private = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
      data    = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
      transit = ["subnet-xxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxx"]
    }

    locals {
      private_subnet_ids = module.vpc.subnet_ids["private"]
    }


#### Network Access Control List (NACL) Outputs
NACL Outputs are presented as Maps where each key corresponds to a Subnet Layer (Public, Private, Data, or Transit) and the values are strings.

* **nacl_arns** = Map of ARNs of the Network Access Control Lists attached to each subnet within the VPC.
* **nacl_ids** = Map of IDs of the Network Access Control Lists attached to each subnet within the VPC.

##### Example
The below example illustrates how the NACL Outputs are configured as well as an example Local Block that references the ID of the NACL attached to the VPC's Private Subnet.
    nacl_id = {
      public  = "acl-xxxxxxxxxxxxxxxxx"
      private = "acl-xxxxxxxxxxxxxxxxx"
      data    = "acl-xxxxxxxxxxxxxxxxx"
      transit = "acl-xxxxxxxxxxxxxxxxx"
    }

    locals {
      private_nacl_id = module.vpc.nacl_id["private"]
    }


#### Route Table Outputs
Route Table Outputs are presented as Maps where each key corresponds to a Subnet Layer (Public, Private, Data, or Transit) and the values are lists of attributes. Each list may include two or more elements, depending on how many Availability Zones are configured within the VPC.

* **route_table_arns** = Map of ARNs of the Route Tables attached to each subnet within the VPC.
* **route_table_ids** = Map of IDs of the Route Tables attached to each subnet within the VPC.

##### Example
The below example illustrates how the Route Table Outputs are configured as well as an example Local Block that references the IDs of the Route Tables attached to the VPC's Private Subnet.
    subnet_ids = {
      public  = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
      private = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
      data    = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
      transit = ["rtb-xxxxxxxxxxxxxxxxx", "rtb-xxxxxxxxxxxxxxxxx"]
    }

    locals {
      private_route_table_ids = module.vpc.route_table_ids["private"]
    }


#### VPC Endpoint Security Group Outputs

* **vpc_endpoint_security_group_name** = Friendly name of the Security Group attached to VPC Endpoints.
* **vpc_endpoint_security_group_arn** = ARN of the Security Group attached to VPC Endpoints.
* **vpc_endpoint_security_group_id** = ID of the Security Group attached to VPC Endpoints.


#### Route 53 Resolver Outputs
Route 53 Resolver Outputs are only valid when *domain_join* is set to *true*. In all other cases, the outputs will be *null*.

* **route53_resolver_endpoint_arn** = ARN of the Outbound Route 53 Resolver used to forward DNS Requests to Volly's Domain Controllers.
* **route53_resolver_endpoint_id** = ID of the Outbound Route 53 Resolver used to forward DNS Requests to Volly's Domain Controllers.
* **route53_resolver_endpoint_ips** = IPs of the Outbound Route 53 Resolver Endpoints used to forward DNS Requests to Volly's Domain Controllers.


#### Route 53 Resolver Rule Outputs
Route 53 Resolver Outputs are only valid when *domain_join* is set to *true*. In all other cases, the outputs will be *null*.

* **route53_resolver_rule_name** = Name of the Route 53 Resolver Rule that forwards DNS Requests to Volly's Domain Controllers.
* **route53_resolver_rule_arn** = ARN of the Route 53 Resolver Rule that forwards DNS Requests to Volly's Domain Controllers.
* **route53_resolver_rule_id** = ID of the Route 53 Resolver Rule that forwards DNS Requests to Volly's Domain Controllers.
* **route53_resolver_rule_domain_name** = Domain Name associated with the Route 53 Resolver Rule that forwards DNS Requests to Volly's Domain Controllers.


#### Route 53 Resolver Security Group Outputs
Route 53 Resolver Security Group Outputs are only valid when *domain_join* is set to *true*. In all other cases, the outputs will be *null*.

* **route53_resolver_security_group_name** = Friendly name of the Security Group attached to the Route 53 Resolver.
* **route53_resolver_security_group_arn** = ARN of the Security Group attached to the Route 53 Resolver.
* **route53_resolver_security_group_id** = ID of the Security Group attached to the Route 53 Resolver.


## Notes

### NACLs
This module generates NACLs with standard rules that align with Volly's NACL Rule Numbering Schema. This schema is designed to make reading and managing NACLs simple by aligning NACL Rule Numbers to specific purposes. Below is an outline of the numbering schema.

  * **100** = Internet Connectivity (i.e. HTTP traffic in and out of the VPC)
  * **200** = Application and Database connectivity in support of the application(s) hosted within the VPC (i.e. Inbound connectivity from the private layer to the data layer on the database port)
  * **300** = Local, Intra-layer, and/or Campus connectivity (i.e. Inbound connectivity that applies to all hosts within the VPC, inbound and outbound access between multiple private subnets, or Database access from the Volly Campus network)
  * **400** = Volly Partner, Vendor, and/or Client connectivity (i.e. Outbound access to a client or partner's sFTP)
  * **500** = Volly Internal Network Integrations (i.e. connectivity between the Marketing Automation and Point of Sale networks)
  * **600** = ICMP Connectivity (i.e. Allowing ICMP connectivity from the Volly Campus network)
  * **1000** = Troubleshooting (i.e. Temporarily adding a rule to test remediation of an issue)

In some cases, the default NACL Rules generated by this module will need to be augmented to provide additional network connectivity. When configuring additional NACL Rules, the following rule numbers must be avoided as they are reserved by this module.

#### Public NACL
##### Inbound
  * **100-101**: HTTP/S traffic from the internet
  * **105**: Ephemeral port traffic from the internet
  * **110 (+ number of public subnets)**: HTTPS traffic from Private Subnet to Internet
  * **115 (+ number of public subnets)**: HTTP traffic from Private Subnet to Internet
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

##### Outbound
  * **100-101**: HTTP/S traffic to the internet
  * **105**: Ephemeral port traffic to the internet
  * **110 (+ number of public subnets x number of application ports)**: Application traffic to Private Subnet
  * **115 (+ number of public subnets)**: HTTP traffic from Private Subnet to Internet
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

#### Private NACL
##### Inbound
  * **100**: Ephemeral port traffic from the internet  
  * **200 (+ number of private subnets)**: Application traffic from the public subnets
  * **305**: Traffic from the network that hosts the Volly Domain Controllers (if *domain_join* = *true*)
  * **310 (+ number of private subnets)**: Traffic between the private subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

##### Outbound
  * **100-101**: HTTP/S traffic to the internet
  * **105**: Ephemeral port traffic to the internet
  * **200 (+ number of private subnets x number of database ports)**: Traffic to data subnets for database connectivity
  * **300**: Traffic to Route53 DNS Resolvers (if *domain_join* = *true*)
  * **305**: Traffic to the network that hosts the Volly Domain Controllers (if *domain_join* = *true*)
  * **310 (+ number of private subnets)**: Traffic between the private subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

#### Data NACL
##### Inbound
  * **100**: Ephemeral port traffic from the internet  
  * **200 (+ number of private subnets x number of database ports)**: Traffic from private subnet for databases connectivity
  * **305**: Traffic from the network that hosts the Volly Domain Controllers (if *domain_join* = *true*)
  * **310 (+ number of private subnets)**: Traffic between the data subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)

##### Outbound
  * **100-101**: HTTP/S traffic to the internet
  * **105**: Ephemeral port traffic to the internet
  * **200 (+ number of private subnets x number of database ports)**: Traffic to Data Subnet for database connectivity
  * **300**: Outbound traffic to Route53 DNS Resolvers (if *domain_join* = *true*)
  * **305**: Traffic to the network that hosts the Volly Domain Controllers (if *domain_join* = *true*)
  * **310 (+ number of data subnets)**: Traffic between the data subnets
  * **600**: ICMP traffic (if *enable_icmp* = *true*)
