################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "The environment that the resources will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "project" {
  description = "Friendly name of the Volly Project the infrastructure supports"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(any)
  default     = {}
}


################################################################################
# Network Variables
################################################################################
variable "vpc_id" {
  description = "ID of the VPC in which to which the Fargate Service is deployed"
  type        = string
}

variable "inbound_access" {
  description = "List of CIDRs, Security Group IDs, and/or Prefix Lists from which to allow inbound access to the Fargate Service"
  type        = list(any)
  default     = []
}

variable "outbound_access" {
  description = "Map of CIDRs, Security Group IDs, and/or Prefix Lists AND Ports for which to allow outbound access from the Fargate Service"
  type        = map(any)
  default     = {}
}

################################################################################
# ECS Variables
################################################################################
#############################################################
# ECS Cluster Variables
#############################################################
variable "cluster_name" {
  description = "Friendly name of the ECS Cluster to which the Fargate Service is deployed"
  type        = string
}

variable "cluster_id" {
  description = "ID of the ECS Cluster to which the Fargate Service is deployed"
  type        = string
}

#############################################################
# ECS Service Variables
#############################################################
variable "service_name" {
  description = "Friendly name of the Fargate Service"
  type        = string
}

variable "desired_capacity" {
  description = "The number of Tasks to be run by the Fargate Service. When using Autoscaling, this is the minimum number of tasks"
  type        = number
}

variable "force_new_deployment" {
  description = "Sets whether to automatically update the ECS Fargate Service when a new Task Definition version is created by the module"
  type        = bool
  default     = "true"
}

#############################################################
# Task Definition Variables
#############################################################
variable "container_cpu_units" {
  description = "The number of cpu units (MB) allocated to the ECS Fargate Tasks"
  type        = number
}

variable "container_memory" {
  description = "The amount of memory (MB) allocated to the ECS Fargate Tasks"
  type        = string
}

variable "app_port" {
  description = "The Port on which the application listens"
  type        = number
  default     = 8060
}

variable "image" {
  description = "Docker image used to deploy the application container"
  type        = string
  default     = null
}

variable "entry_point" {
  description = "The Command or Entry Point to initialize the containerized service"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Map of Environment Variables passed to the ECS Container"
  type        = map(any)
  default     = {}
}

variable "parameters" {
  description = "Map of SSM Parameters or Secrets passed as Environment Variables to the ECS Container"
  type        = map(any)
  default     = {}
}

#############################################################
# Sidecar Variables
#############################################################
variable "xray_image" {
  description = "The AWS X-Ray container image to be used for X-Ray sidecars"
  type        = string
  default     = "public.ecr.aws/xray/aws-xray-daemon"
}

variable "xray_image_version" {
  description = "The image version of the AWS X-Ray container to be used for X-Ray sidecars"
  type        = string
  default     = "3.3.3"
}

variable "envoy_image" {
  description = "The AWS APP Mesh Envoy container image to be used for Envoy sidecar proxies"
  type        = string
  default     = "public.ecr.aws/appmesh/aws-appmesh-envoy"
}

variable "envoy_image_version" {
  description = "The image version of the AWS APP Mesh Envoy container to be used for Envoy sidecar proxies"
  type        = string
  default     = "v1.18.4.0-prod"
}

variable "envoy_log_level" {
  description = "Log level for the Envoy proxy sidecar"
  type        = string
  default     = "info"
}


################################################################################
# AutoScaling Variables
################################################################################
variable "max_capacity" {
  description = "The maximum number of containers that may be run as part of the Fargate Service"
  type        = number
  default     = null
}

variable "autoscaling_type" {
  description = "Type of AutoScaling Policy to apply to the Fargate Service. Valid options are 'TargetTrackingScaling' or 'StepScaling'"
  type        = string
  default     = "TargetTrackingScaling"
}

variable "autoscaling_cpu_policy" {
  description = "Autoscaling Policy configuration for scaling when CPU reaches a specific target threshold. To disable, set value to '{}'."
  type        = map(any)
  default     = null
}

variable "autoscaling_memory_policy" {
  description = "Autoscaling Policy configuration for scaling when memory reaches a specific target threshold. To disable, set value to '{}'."
  type        = map(any)
  default     = null
}

variable "autoscaling_load_balancing_policy" {
  description = "Autoscaling Policy configuration for scaling when ALB requests reach a specific target threshold."
  type        = map(any)
  default     = null
}


################################################################################
# Load Balancer Variables
################################################################################
variable "load_balancer_arn" {
  description = "ARN of the load balancer that serves requests to the Fargate Tasks"
  type        = string
  default     = null
}

variable "load_balancer_type" {
  description = "The type of load balancer that serves requests to the Fargate Tasks. valid options are 'application' or 'network'."
  type        = string
  default     = null
}

variable "load_balancer_security_group" {
  description = "Security Group applied to the load balancer that serves requests to the Fargate Tasks"
  type        = string
  default     = null
}

variable "target_group_arn" {
  description = "ARN of the Target Groups to which Fargate Tasks are associated"
  type        = string
  default     = null
}

variable "health_check_grace_period" {
  description = "The amount of time (s) to ignore Load Balancer health checks to ensure service is not shut-down prematurely"
  type        = number
  default     = 60
}

################################################################################
# App Mesh Variables
################################################################################
variable "app_mesh_virtual_node" {
  description = "Name of the App Mesh Virtual Node or Gateway to associate with the Fargate Tasks"
  type        = string
  default     = null
}


################################################################################
# Service Discovery Variables
################################################################################
variable "namespace_id" {
  description = "ID of the Service Discovery Namespace with which to associate the Fargate Tasks"
  type        = string
  default     = null
}

variable "namespace_record_type" {
  description = "Type of Records that can be created in the Service Discovery Service with which the Fargate Tasks is associated. Valid values are 'A' or 'SRV'."
  type        = string
  default     = "A"
}


################################################################################
# EFS Variables
################################################################################
variable "efs_file_system_name" {
  description = "Friendly name for the EFS File System attached to the Fargate Tasks"
  type        = string
  default     = null
}

variable "efs_container_path" {
  description = "The name of the EFS volume home directory accessed by the Fargate Tasks"
  type        = string
  default     = null
}

variable "efs_source_volume" {
  description = "Name of the EFS volume accessed by the Fargate Tasks"
  type        = string
  default     = null
}

variable "efs_user_uid" {
  description = "User ID for the POSIX User authorized to access the EFS Volume"
  type        = string
  default     = null
}

variable "efs_user_gid" {
  description = "Group ID for the POSIX User authorized to access the EFS Volume"
  type        = string
  default     = null
}

variable "efs_owner_uid" {
  description = "User ID for the Owner of the EFS Volume Root Directory"
  type        = string
  default     = null
}

variable "efs_owner_gid" {
  description = "Group ID for the Owner of the EFS Volume Root Directory"
  type        = string
  default     = null
}

variable "efs_root_permissions" {
  description = "The Root Directory permissions provided to the Root Owner"
  type        = string
  default     = null
}

variable "efs_root_path" {
  description = "Path to the Root Directory of the EFS Volume"
  type        = string
  default     = null
}

variable "efs_kms_key_arn" {
  description = "ARN of the kms key used to encrypt the EFS Volume"
  default     = null
}


################################################################################
# Default Tags
################################################################################
variable "default_tags" {
  description = "Map of tags to be used on all resources created by the module"
  type        = map(any)
  default = {
    builtby = "terraform"
  }
}