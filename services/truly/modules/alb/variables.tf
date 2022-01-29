################################################################################
# Variables passed in from root module
################################################################################
variable "environment" {
  description = "environment that the nlb will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to provision resources"
  type        = string
}

variable "project" {
  description = "Name of the Volly Project the infrastructure supports"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(any)
  default     = {}
}

variable "default_tags" {
  description = "map of tags to be used on all resources created by the module"
  type        = map(any)
  default = {
    builtby               = "terraform"
    "data classification" = "internal confidential"
  }
}


################################################################################
# Load Balancer Variables
################################################################################
variable "load_balancer_type" {
  description = "Sets the type of Load Balancer to provision. Valid options are 'application' or 'network'."
  type        = string
}

variable "service_name" {
  description = "friendly name used to describe the load balancer"
  type        = string
}

variable "subnet_layer" {
  description = "selection of which network layer in which to place the Load Balancer. Valid options are 'public', 'private', 'data' or 'transit'"
  type        = string
}

variable "certificate_arns" {
  description = "List of ARNs of the certificates used to encrypt traffic to the load balancer"
  type        = list(any)
  default     = null
}

variable "enable_deletion_protection" {
  description = "Sets whether to protect the Load Balancer from accidental termination"
  type        = string
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Sets whether the Load Balancer should distribute traffic accross all availability zones"
  type        = bool
  default     = true
}

variable "enable_http2" {
  description = "Sets whether HTTP/2 is enabled for the Load Balancer"
  type        = bool
  default     = true
}

variable "ip_address_type" {
  description = "The type of IP addresses used by the subnets for your load balancer"
  type        = string
  default     = "ipv4"
}


################################################################################
# Load Balancer Listener Variables
################################################################################
variable "listeners" {
  description = "Map of Load Balancer Listener configurations"
  type        = map(any)
  default     = null
}

variable "listener_rules" {
  description = "Map of Load Balancer Listener Rule configurations"
  type        = map(any)
  default     = {}
}

variable "http_port" {
  description = "The port for the HTTP listener"
  type        = number
  default     = 80
}


################################################################################
# Target Group Variables
################################################################################
variable "target_groups" {
  description = "Map of configuration for each target group"
  type        = map(any)
}

variable "load_balancing_algorithm" {
  description = "Sets which algorithm the Load Balancer should use when routing requests. Valid options are 'round_robin' or 'least_outstanding_requests"
  type        = string
  default     = "round_robin"
}

variable "health_check_timeout" {
  description = "The amount of time, in seconds, during which no response means a failed health check."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive health checks successes required before considering an unhealthy target healthy."
  type        = number
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive health check failures required before considering the target unhealthy."
  type        = number
  default     = 5
}

variable "health_check_interval" {
  description = "The approximate amount of time, in seconds, between health checks of an individual target."
  type        = number
  default     = 30
}

variable "health_check_matcher" {
  description = "The HTTP codes to use when checking for a successful response from a target."
  type        = string
  default     = "200"
}

variable "deregistration_delay" {
  description = "Amount of time (sec) the load balancer waits until changing the target states from darining to unused"
  type        = number
  default     = 120
}

variable "sticky_session_duration" {
  description = "Sets the duration for which the Load Balancer will deliver requests to the same target"
  type        = number
  default     = null
}


################################################################################
# Global Accelerator Variables
################################################################################
variable "enable_static_ips" {
  description = "Sets whether to assign static IPs to the Load Balancer via a Global Accelerator"
  type        = bool
  default     = false
}


################################################################################
# Service Discovery Variables
################################################################################
variable "namespace_id" {
  description = "Name of the AWS Cloud Map Namespace to which the Load Balancer is registered"
  type        = string
  default     = null
}

variable "service_discovery_name" {
  description = "Name, under which, the Load Balancer is registered to the Cloud Map Namespace"
  type        = string
  default     = null
}