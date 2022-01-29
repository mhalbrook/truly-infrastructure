# Volly Terraform Library Module | Fargate Service

**Current Version**: v5.1

This module creates an ECS Fargate Service and Task Definition. A security group, Execution IAM Role and Task IAM Role are generated for baseline network and permissions. Finally, a CloudWatch Log Group is created to capture logs from primary and sidecar containers running within the Fargate Tasks.

Additionally, the module can be configured to:

  * Enable Autoscaling of the ECS Fargate Service
  * Enable load balancing of the Fargate Tasks with either an ALB or NLB
  * Associate the Fargate Tasks with AWS App Mesh   
  * Enable Service Discovery to associate Fargate Tasks with an AWS CloudMap Namespace
  * Attach and Elastic File System volume to Fargate Tasks for persistent storage
 


## Usage

#### Providers
From a root module, set a provider for the account in which to build the Fargate Service. When calling this Library module, set the provider equal to *aws.account*.
Additionally, set a provider for the volly-cicd account and, when calling this Library module, set the provider equal to *aws.cicd*. This provider allows the module to configure permissions for Fargate Tasks to utilize container images stored in AWS ECR.
  
    

#### Features 

##### Network Connectivity

###### Inbound Access
This module supports customizing the allowed Ingress traffic of the Security Group attached to the Fargate Tasks. This feature is enabled by providing a valid list if *sources* to the *inbound_access* variable.

The list provided to the *inbound_access* variable may contain CIDRs, Security Group IDs, and/or Managed Prefix Lists. The elements within the list are not required to be of the same type, for example, the following is a valid *inbound_access* argument:

    ["10.1.20.0/24", "sg-xxxxxxxxxxxxxxxxxx", "pl-xxxxxxxxxxxxxxxxxx"]

###### Outbound Access
This module supports customizing the allowed Egress traffic of the Security Group attached to the Fargate Tasks. This feature is enabled by providing a valid map of *destinations* and *ports* to the *outbound_access* variable.

The map provided to the *outbound_access* variable may contain CIDRs, Security Group IDs, and/or Managed Prefix Lists. The elements within the list are not required to be of the same type, for example, the following is a valid *outbound_access* argument:

    {
      10.1.20.0/24 = 7070, 
      sg-xxxxxxxxxxxxxxxxxx = 8080,
      pl-xxxxxxxxxxxxxxxxxx = 9090
    }


##### Autoscaling
The module support enabling Autoscaling for out-of-the-box Target Tracking Metrics. These metrics are:

  * **ECSServiceAverageCPUUtilization:** Scale out when average CPU across all Fargate Tasks exceed a provided threshold
  * **ECSServiceAverageMemoryUtilization:** Scale out when average memory utilization exceeds a provided threshold
  * **ALBRequestCountPerTarget:** Scale out when Application Load Balancer requests to the defined Target group exceeds a given threshold

Setting the *max_capacity* variable to a value greater than the *desired_capacity* variable will enable Autoscaling on the Fargate Service. By default, policies are generated to scale out when CPU exceeds 65% of the available CPU and/or when memory utilization exceeds 80% of the available memory. These policies can be customized via the *autoscaling_cpu_policy* and *autoscaling_memory_policy* variables. Setting either variable to *{}* will result in a policy for that metric not being created.

By default a policy for *ALBRequestCountPerTarget* is never applied as services are able to handle a various number of requests dependent on service efficiency, therefore, scaling on a standard request count may lead to unnecessary scaling events. However, a custom policy may be configured via the *autoscaling_load_balancing_policy* variable. 


##### Load Balancing
The module supports attaching the Fargate Service to a Network or Application Load Balancer. When enabled, Fargate Tasks will be added to a specified Target Group when the task launches. This feature is enabled by providing a valid Load Balancer ARN to the *load_balancer_arn* variable. 

When associating a Load Balancer to a Fargate Service, the following resources must also be provided:

  * **Load Balancer Security Group:** provided to allow the module to create a security group rule which allows network connectivity between the Load Balancer and the Fargate Tasks. 
  * **Target Group ARN:** sets the Target Group to which Fargate Tasks should be associated.


##### App Mesh
The module supports associating Fargate Tasks with AWS APP Mesh Virtual Nodes. This allows Fargate Tasks to be targeted by App Mesh Virtual Services and Routers. 

This feature is enabled by providing a valid App Mesh Virtual Node name to the *app_mesh_virtual_node** variable. The value provided must be the *full* node name, which includes both the name of the App Mesh and the Virtual Node. For example *mesh/example-mesh/virtualNode/example-node*.


##### Service Discovery
The module supports associating Fargate Tasks with an AWS CloudMap Namespace as a Private DNS. This is usually used in conjunction with AWS App Mesh, however, this feature can be used on its own as well.

This functionality is enabled by providing a valid AWS CloudMap Namespace ID to the *namespace_id* variable. 


##### Elastic File System
The module supports attaching an Elastic File System volume to the Fargate Tasks. This feature can be used when the service running on the Fargate Service requires persistent storage. This is a rare requirement and should only be enabled in circumstances that absolutely require it.

This functionality is enabled by providing a Elastic File System Name to the *efs_file_system_name* variable. Unlike the above features, this module will create the Elastic File System, therefore, there is no need to provision the resource prior to deploying this module.

When this feature is enabled, the following resources will be created:

  * **Elastic File System:** The Elastic File System containing a persistent volume to which Fargate Tasks connect.
  * **Access Point:** An application-specific entry point to the EFS file system, which enforces user identities, permissions and directory access.
  * **Mount Points:** AWS-Managed endpoints used by the Fargate Tasks to securely connect to the EFS volume.
  * **Security Group:** Security Group attached to EFS Mount Points, which allow network access between the EFS volume and the Fargate Task.
  * **EFS Policy:** Policy enforcing configurations of the EFS volume such as, in-transit encryption and root access.


#### Sidecar Containers
In certain circumstances, Fargate Tasks may be configured to deploy sidecar containers along with the container running the primary application (application container). These sidecars provide specialized capabilities to the Fargate Task. This module is configured to deploy the following sidecar containers when circumstances call for them:

  * **Envoy Proxy Sidecar:** Enables layer-seven routing via an AWS App Mesh. When deployed, the sidecar container communicates with AWS App Mesh to route and encrypt requests as well as to discover backend services. 
    * When deployed, all requests are routed through the Envoy Container to the application container.
    * When a Fargate Task is configured as a Virtual Gateway, the Envoy sidecar is deployed without an application container as the purpose of a virtual gateway is only to route requests to other Envoy Proxies.

  * **X-Ray Sidecar:** Aggregates and delivers request data to AWS X-Ray for trace log analytics.
    * When enabled, the AWS X-Ray service may be used to view traffic flowing between Fargate Services and troubleshoot request failures. 

  * **Lacework Sidecar:** Enables the Lacework Agent to monitor the container for malicious activity during runtime. 
    * The Lacework sidecar is automatically deployed in all instances.
    * The Lacework sidecar is not designed to run continuously, it will initialize and mount a volume to the main Application Container. Once the volume is mounted, the App Container will initialize the Lacework Agent via a Docker EntryPoint Command. Once the Lacework Agent is initialized, the Lacework Agent will **Stop**.


##### Memory Allocation
When sidecar containers are deployed, memory must be shared between the application container and the sidecar containers running within the Fargate Task. The module automatically sets resource allocations via hard and soft limits.

  * **Hard Limit** = The max amount of memory a container may consume before stopping the Fargate Task
  * **Soft Limit** = The minimum amount of memory allocated to the container

Hard limits are set as follows:

  * **Application Container:** Set to the total amount of available memory *minus* the soft limit of each deployed sidecar container.
    * This configuration ensures that Fargate Task is always able to successfully allocate the minimum required memory for the sidecar containers.
  * **Envoy Sidecar:** Set to 500 (MB)
    * When an envoy container is deployed as a Virtual Gateway, the hard limit is set as if it were an *Application Container*
  * **X-Ray Sidecar:** Set to 256 (MB)

Soft limits are set as follows:

  * **Application Container:** Half of the total memory available to the Fargate Task 
  * **Envoy Sidecar:**  Set to 300 (MB)
    * When an envoy container is deployed as a Virtual Gateway, the soft limit is set as if it were an *Application Container*
  * **X-Ray Sidecar:** Set to 156 (MB)


##### ECS Exec
The module supports Amazon ECS Exec, which enables the remote sending of commands to the Fargate Task containers via the AWS Command Line. This feature is always enabled, however, Fargate Tasks are not configured to launch containers with ECS Exec enabled by default.

For instructions on launching a Fargate Task in an existing Fargate Service and sending commands to containers within that Fargate Task, review the **Enabling ECS Exec for your tasks and services** and **Running commands using ECS Exec** of the [Using Amazon ECS Exec for Debugging](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) document.

Additionally, before sending command via ECS Exec, the [AWS Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) must be installed on the endpoint used to send the commands.



#### Dependencies
This module may require multiple resources to be created prior to deploying the module, depending on the features that are enabled within the module. All of the listed dependencies may be deployed via Terraform using existing Library Modules. 

the following resources are always required for the module:

  * ECS Cluster

If associating the Fargate Service with a Load Balancer, the following resources are required:

  * Load Balancer
  * Target Group
  * Security Group attached to Load Balancer (Application Load Balancers only)

If associating the Fargate Tasks to an AWS App Mesh Virtual Node, the following resources are required:

  * App Mesh
  * App Mesh Virtual Node

If associating the Fargate Tasks with an AWS CloudMap Namespace, the following resources are required:

  * AWS CloudMap Namespace

If attaching an Elastic File System volume to the Fargate Tasks, the following resources are required

  * KMS Key



## Example
#### Example with only *required* variables
    module "fargate" {
      source                            = "git::ssh://git@bitbucket.org/v-dso/fargate"
      project                           = var.project
      environment                       = "prod"
      cluster_name                      = "example-cluster-name"
      cluster_id                        = "arn:aws:ecs:us-east-1:0xxxxxxxxxx3:cluster/example"
      service_name                      = "example"
      vpc_id                            = "vpc-xxxxxxxxxxxxxxxxx"
      image                             = "example-image"
      entry_point                       = "npm run start:prod"
      container_cpu_units               = 1024
      container_memory                  = 2048
      desired_capacity                  = 2
      app_port                          = 8000


      providers = {
        aws.account = aws.account
        aws.cicd    = aws
      }
    }

#### Example with *all* variables
    module "fargate" {
      source                            = "git::ssh://git@bitbucket.org/v-dso/fargate"
      project                           = var.project
      environment                       = "prod"
      cluster_name                      = "example-cluster-name"
      cluster_id                        = "arn:aws:ecs:us-east-1:0xxxxxxxxxx3:cluster/example"
      service_name                      = "example"
      vpc_id                            = "vpc-xxxxxxxxxxxxxxxxx"
      namespace_id                      = "ns-xxxxxxxxxxxxxxxx"
      namespace_record_type             = "SRV"
      load_balancer_arn                 = "arn:aws:elasticloadbalancing:us-east-1:xxx:loadbalancer/app/example-load-balancer/x"
      load_balancer_security_group      = "example-security-group"
      target_group_arn                  = "arn:aws:elasticloadbalancing:us-east-1:xxx:targetgroup/example-target-group/x"
      health_check_grace_period         = 120
      image                             = "example-image"
      entry_point                       = "npm run start:prod"
      container_cpu_units               = 1024
      container_memory                  = 2048
      desired_capacity                  = 2
      max_capacity                      = 50
      force_new_deployment              = false
      app_port                          = 8000
      app_mesh_virtual_node             = "mesh/example-mesh/virtualNode/example-node"
      efs_file_system_name              = "example-file-system"
      efs_container_path                = "/var/example"
      efs_source_volume                 = "example-volume-name"
      efs_root_path                     = "/root"
      efs_user_uid                      = 1000
      efs_user_gid                      = 1000
      efs_owner_uid                     = 1000
      efs_owner_gid                     = 1000
      efs_root_permissions              = 777
      efs_kms_key_arn                   = "arn:aws:kms:us-east-1:xxx:key/xxx-xxx-xxx-xxx-xxx"
      inbound_access                    = ["10.1.20.0/24", "sg-xxxxxxxxxxxxxxxxxx", "pl-xxxxxxxxxxxxxxxxxx"]
      outbound_access                   = {
        10.1.20.0/24 = 7070, 
        sg-xxxxxxxxxxxxxxxxxx = 8080,
        pl-xxxxxxxxxxxxxxxxxx = 9090
      }

      parameters                        = { 
        example/environment/variable = example-value 
      }

      autoscaling_cpu_policy            = {
        target_value       = 60
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
      }
      autoscaling_memory_policy         = {
        target_value       = 75
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
      }
      autoscaling_load_balancing_policy = {
        target_value       = 100000
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
      }

      tags = {
        example-tag-key = "example-tag-value"
      }

      providers = {
        aws.account = aws.account
        aws.cicd    = aws
      }
    }



## Variables

#### Required Variables
* **project** *string* = Friendly name of the Volly Project the infrastructure supports. 
* **environment** *string* = The environment that the resources will support. 
    * Valid options are *cit*, *uat*, *prod*, *core* or *campus*.
* **cluster_name** *string* = Friendly name of the ECS Cluster to which the Fargate Service is deployed.
* **cluster_id ** *string* = ID of the ECS Cluster to which the Fargate Service is deployed.
    * ECS Cluster ID and ARN are synonymous.
* **service_name** *string* = Friendly name for the Fargate Service.
    * The module will automatically prepend the provided value with the Project Name when naming resources.                    
* **vpc_id** *string* = ID of the VPC in which to which the Fargate Service is deployed
* **image** *string* = Friendly name of the Application Container Docker image.
    * By default, the module pulls images from the AWS Elastic Container Registry in the Volly-CICD account. To pull images from a different location, provide the full url path to the image (i.e. xxxxxxxxxxxx.dkr.ecr.us-east-1.amazonaws.com)          
        * For custom ECR locations, the Fargate Execution role must be provided with permissions to access images in the repository. 
    * If the *app_mesh_virtual_node* variable is set, the *image* variable is not required. In this scenario, the module will configure the Fargate Service that runs only an Envoy Sidecar. This configuration is uncommon, but valid when deploying Fargate Services to act as App Mesh Virtual Gateways.
* **entry_point** *string* = The Command or Entry Point that initializes the containerized service.
    * When deploying a Fargate Service to act as an App Mesh Virtual Gateway, this variable may be omitted, however, omitting this variable in any other circumstance will prevent the Application Container from successfully initializing. 
* **container_cpu_units** *number* = The number of cpu units (MB) allocated to the ECS Fargate Tasks
* **container_memory** *number* = The amount of memory (MB) allocated to the ECS Fargate Tasks
* **desired_capacity** *number* = The number of Tasks to be run by the Fargate Service. 
    * When Autoscaling is enabled, this value is the minimum number of Fargate Task that may run within the Fargate Service
* **app_port** *number* = The Port on which the application listens.
    * Defaults to Port 8060.



#### Optional Variables
* **force_new_deployment** *string* = Sets whether to automatically update the ECS Fargate Service when a new Task Definition version is created by the module.
    * Defaults to *true*
    * It is not recommended to alter this variable, however, in rare cases where Task Definition changes need to be staged, but not immediately deployed, this variable may be temporarily set to false.             
* **parameters** *string* = Map of AWS Systems Manager Parameters or Secrets Manager Secrets passed as Environment Variables to the Application Container via the Task Definition.
    * Values set in this variable are set as Environment Variables within the Application container when the Fargate Task launches. This allows for quicker launch times when certain Environment Variables are required for the containers to reach a stable state.                      
* **tags** *string* = A map of tags to assign to all resources.
    * This argument may be used when setting custom tags for resources. By default, certain tags are added to all resources via the *default_tags* variable. 


##### Network Connectivity
* **inbound_access** *list* = List of sources from which to allow traffic to the Fargate Service.
  * List values may be CIDRs, Security Group IDs, and/or Managed Prefix Lists.
* **outbound_access** *map* = 
This module supports customizing the allowed Ingress traffic of the Security Group attached to the Fargate Tasks. This feature is enabled by providing a valid list if *sources* to the *inbound_access* variable.

The list provided to the *inbound_access* variable may contain CIDRs, Security Group IDs, and/or Managed Prefix Lists. The elements within the list are not required to be of the same type, for example, the following is a valid *inbound_access* argument:

    ["10.1.20.0/24", "sg-xxxxxxxxxxxxxxxxxx", "pl-xxxxxxxxxxxxxxxxxx"]

###### Outbound Access

##### Autoscaling
* **max_capacity** *number* = The maximum number of containers that may be run as part of the Fargate Service.
    * Setting this variable to a value greater than the *desired_capacity* variable will enable Autoscaling with a default set of scaling policies.                    
* **autoscaling_cpu_policy** *map* = Map containing Autoscaling Policy configuration arguments for scaling when CPU utilization exceeds a specific target threshold. 
    * If this variable is not set and Autoscaling is enabled, a default policy is generated.
        * Default policy triggers scaling when average CPU utilization exceeds 65% of the CPU units available to the Fargate Task. 
    * To disable Autoscaling based on CPU utilization, set the variable equal to *{}* 
    * When set, the following arguments must be set within the map:

        * **target_value** *number* = The percent of CPU units that may be consumed by the Fargate Service before scaling events are triggered. (i.e. if set to 65, new Fargate Tasks will launch when average CPU utilization exceeds 65%)
        * **scale_in_cooldown** *number* = The amount of time (s) that CloudWatch waits before analyzing CPU Utilization after a scale-in event. This ensures that metrics are not analyzed prematurely, leading to unnecessary or inefficient scaling events.
        * **scale_out_cooldown** = The amount of time (s) that CloudWatch waits before analyzing CPU Utilization after a scale-out event. This ensures that metrics are not analyzed prematurely, leading to unnecessary or inefficient scaling events.     

* **autoscaling_memory_policy** *map* = Map containing Autoscaling Policy configuration arguments for scaling when memory utilization exceeds a specific target threshold. 
    * If this variable is not set and Autoscaling is enabled, a default policy is generated.
        * Default policy triggers scaling when average memory utilization exceeds 80% of the memory available to the Fargate Task. 
    * To disable Autoscaling based on memory utilization, set the variable equal to *{}* 
    * When set, the following arguments must be set within the map:

        * **target_value** *number* = The percent of memory that may be consumed by the Fargate Service before scaling events are triggered. (i.e. if set to 80, new Fargate Tasks will launch when average memory utilization exceeds 80%)
        * **scale_in_cooldown** *number* = The amount of time (s) that CloudWatch waits before analyzing memory Utilization after a scale-in event. This ensures that metrics are not analyzed prematurely, leading to unnecessary or inefficient scaling events.
        * **scale_out_cooldown** = The amount of time (s) that CloudWatch waits before analyzing memory Utilization after a scale-out event. This ensures that metrics are not analyzed prematurely, leading to unnecessary or inefficient scaling events.   

* **autoscaling_load_balancing_policy** *map* = Map containing Autoscaling Policy configuration arguments for scaling when Application Load Balancer requests exceed a specific target threshold. 
    * If this variable is not set and Autoscaling is enabled, a default policy is NOT generated. 
    * When set, the following arguments must be set within the map:

        * **target_value** *number* = The average number of requests from the Application Load Balancer to the specified Target Group that is allowed before scaling events are triggered. (i.e. if set to 100000, new Fargate Tasks will launch when average requests exceed 100,000)
        * **scale_in_cooldown** *number* = The amount of time (s) that CloudWatch waits before analyzing average requests after a scale-in event. This ensures that metrics are not analyzed prematurely, leading to unnecessary or inefficient scaling events.
        * **scale_out_cooldown** = The amount of time (s) that CloudWatch waits before analyzing average requests after a scale-out event. This ensures that metrics are not analyzed prematurely, leading to unnecessary or inefficient scaling events.          


##### Load Balancing
* **load_balancer_arn** *string* = ARN of the Load Balancer that serves requests to the Fargate Tasks.              
    * May be a Network or Application Load Balancer.
    * When set, the *target_group_arn* variable is required.
    * When associating the Fargate Service with an *Application Load Balancer*, the *load_balancer_security_group* variable is required.
* **load_balancer_security_group** *string* = Security Group applied to the Load balancer that serves requests to the Fargate Tasks.
    * Only required when associating the Fargate Service with an *Application Load Balancer* as security groups may not be attached to *Network Load Balancers*.   
    * When set, Security Group Rules allowing connectivity between the Load Balancer and the Fargate Tasks are set within the defined Security Group.  
* **target_group_arn** *string* = ARN of the Target Groups to which Fargate Tasks are associated.                   
* **health_check_grace_period** *number* = The amount of time (s) to ignore Load Balancer health checks to ensure service is not shut-down prematurely.
    * Defaults to 60 (s)
    * Fargate tasks are frequently added to Target Groups prior to the service reaching a stable state. In these scenarios, setting the *health_check_grace_period* too low will result in Load Balancers prematurely determining the service is unhealthy and stopping the Fargate Task.        

##### App Mesh
* **app_mesh_virtual_node** *string* = Name of the App Mesh Virtual Node or Gateway to associate with the Fargate Tasks.
    * When set, the module will automatically integrate with App Mesh and an Envoy sidecar container will be deployed within the Fargate Task.
    * The value provided must be the *full* node name, which includes both the name of the App Mesh and the Virtual Node (i.e. *mesh/example-mesh/virtualNode/example-node*)
        * The Virtual Service and Virtual Gateway Library Modules output the full Virtual Node name, which can be used to set this argument. This output is called *full_node_reference* 
*  **envoy_log_level** *string* = Sets the level of detail provided in CloudWatch logs for the Envoy Container.
    * Valid values are *info*, *trace*, *warning*, *debug* or *off* 
    * Defaults to *info*
    * It is not recommended to alter the default value of this variable, however, when troubleshooting Envoy sidecar issues, this variable may be temporarily altered to provide more detailed logs by setting the value to *trace* or *debug*. 
* **envoy_image_version** *string* = Sets the version of the Envoy sidecar image to use within the Fargate Tasks. 
    * Defaults to the most current version tested with Volly services.
    * It is not recommended to alter the default value of this variable, however, when troubleshooting Envoy sidecar issues, this variable may temporarily set to a newer or older image version.

##### X-Ray
* **xray_image_version** *string* = Sets the version of the X-Ray sidecar image to use within the Fargate Tasks. 
    * Defaults to the most current version tested with Volly services.
    * It is not recommended to alter the default value of this variable, however, when troubleshooting X-Ray sidecar issues, this variable may temporarily set to a newer or older image version. 

##### Service Discovery (CloudMap)
* **namespace_id** *string* = ID of the Service Discovery Namespace with which to associate the Fargate Tasks.  
* **namespace_record_type** *string* = Type of Records that can be created in the Service Discovery Service with which the Fargate Tasks is associated. 
    * Valid options are *A* or *SRV*.
    * Defaults to *A*.                    

##### Elastic File System
* **efs_file_system_name** *string* = Friendly name for the EFS File System attached to the Fargate Tasks. 
    * When set, all of the below EFS variables are required.            
* **efs_container_path** *string* = The name of the EFS volume home directory accessed by the Fargate Tasks                
* **efs_source_volume** *string* = Friendly name of the EFS volume accessed by the Fargate Tasks                                     
* **efs_user_uid** *string* = User ID for the POSIX User authorized to access the EFS Volume                      
* **efs_user_gid** *string* = Group ID for the POSIX User authorized to access the EFS Volume                      
* **efs_owner_uid** *string* = User ID for the Owner of the EFS Volume Root Directory                 
* **efs_owner_gid** *string* = Group ID for the Owner of the EFS Volume Root Directory                         
* **efs_root_permissions** *string* = The Root Directory permissions provided to the Root Owner   
* **efs_root_path** *string* = Path to the Root Directory of the EFS Volume           
* **efs_kms_key_arn** *string* = ARN of the kms key used to encrypt the EFS Volume                   


## Outputs

#### ECS Cluster
* **ecs_cluster** *string* = Friendly name of the ECS Cluster to which the Fargate Service is deployed 

#### Fargate Service
* **ecs_service_name** *string* = Friendly name of the ECS Fargate Service.
* **ecs_service_id** *string* = ID of the ECS Fargate Service.

#### Fargate Task Definition
* **task_definition_arn** *string* = ARN of the Task Definition created for the Fargate Tasks.

#### Fargate Task Container Definition
* **container_definitions** *map* = The full Fargate Task Container Definition output in JSON format.
    * This output is not useful as an input for other Terraform module arguments, however, it can be useful in troubleshooting issues when Task Definitions fail to create or update due to incorrect Container Definition syntax.

#### Autoscaling
* **autoscaling_policy_name** *list* = List of names of the applied Autoscaling Policies.
* **autoscaling_policy_arn** *list* = List of ARNs of the applied Autoscaling Policies.

#### CloudWatch Log Group
* **log_group_name** *string* = Friendly name of the CloudWatch Log Group where the Fargate Tasks deliver logs.
* **log_group_arn** *string* = ARN name of the CloudWatch Log Group where the Fargate Tasks deliver logs.

#### Security Group
* **security_group_name** *string* = Friendly name of the Security Group attached to the Fargate Tasks.
* **security_group_arn** *string* = ARN of the Security Group attached to the Fargate Tasks.
* **security_group_id** *string* = ID of the Security Group attached to the Fargate Tasks.

#### IAM Roles
##### Execution Role
The Execution Role is used to perform actions required to launch the Fargate Task. Permissions provided to the Execution role are not passed the the Fargate Task during runtime.

* **execution_role_name** *string* = Friendly name of the IAM Execution Role used by the Fargate Service to launch Fargate Tasks.
* **execution_role_arn** *string* = ARN of the IAM Execution Role used by the Fargate Service to launch Fargate Tasks.
* **execution_role_id** *string* = ID of the IAM Execution Role used by the Fargate Service to launch Fargate Tasks.
* **execution_role_unique_id** *string* = Unique ID of the IAM Execution Role used by the Fargate Service to launch Fargate Tasks.

##### Task Role
The Task Role is used by the Fargate Task to take actions against other AWS Services.

* **task_role_name** *string* = Friendly name of the IAM Task Role used by the Fargate Tasks to perform actions against other AWS Services.
* **task_role_arn** *string* = ARN of the IAM Task Role used by the Fargate Tasks to perform actions against other AWS Services.
* **task_role_id** *string* = ID of the IAM Task Role used by the Fargate Tasks to perform actions against other AWS Services.
* **task_role_unique_id** *string* = Unique ID of the IAM Task Role used by the Fargate Tasks to perform actions against other AWS Services.

#### Elastic File System Outputs
Elastic File System Outputs are presented as lists to ensure outputs are correctly handled when no Elastic File System is created. In some cases, lists may only include one element.

* **efs_arn** *list* = ARN of the Elastic File System.
* **efs_id** *list* = ID of the Elastic File System.

##### EFS Access Point Outputs
* **efs_access_point_arn** *list* = ARN of the Elastic File System Access Point.
* **efs_access_point_id** *list* = ID of the Elastic File System Access Point.

##### EFS Mount Target Outputs
* **efs_mount_target_ids** *list* = List of IDs of the Elastic File System Mount Targets.

##### EFS Policy Outputs
* **efs_policy_id** *list* = ID of the Elastic File System Policy.

#### Service Discovery Outputs
Service Discovery Outputs are presented as lists to ensure outputs are correctly handled when no Namespace is associated with the Fargate Service. In all cases, lists only include one element.

* **service_discovery_name** *list* = Friendly name of the Service Discovery Namespace associated with the Fargate Service.
* **service_discovery_arn** *list* = ARN of the Service Discovery Namespace associated with the Fargate Service.
* **service_discovery_id** *list* = ID name of the Service Discovery Namespace associated with the Fargate Service.
