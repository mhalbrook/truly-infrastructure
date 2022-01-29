################################################################################
# Global variables
################################################################################
variable "environment" {
  description = "Environment that the Route 53 Record will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
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
    builtby = "terraform"
  }
}


################################################################################
# Hosted Zone variables
################################################################################
variable "private_zone" {
  description = "Sets whether the record is being created in a Private Hosted Zone"
  type        = bool
  default     = false
}

variable "apex_domain" {
  description = "Apex Domain of the Hosted Zone in which the Route 53 Record"
  type        = string
  default     = null
}


################################################################################
# DNS Record variables
################################################################################
variable "alias" {
  description = "Sets whether the Route 53 Record is an Alias Record"
  type        = bool
  default     = false
}

variable "record_name" {
  description = "Name of the Route 53 Record to be provisioned (i.e. app.myvolly.com)"
  type        = string
}

variable "record_type" {
  description = "Type of Route 53 Record to be provisioned."
  type        = string
}

variable "ttl" {
  description = "Time to Live for the Route 53 Record"
  type        = number
  default     = 600
}

variable "record_values" {
  description = "List of Record Values targetted by the Route 53 Record"
}

variable "zone_id" {
  description = "Zone ID of the resource being targeted by Route 53 Alias record"
  type        = string
  default     = null
}


################################################################################
# Routing Policy Variables
################################################################################
variable "routing_policy" {
  description = "Name of the Routing Policy for the Route 53 Record. Valid options are 'simple', 'multivalue', 'failover' or 'weighted'"
  type        = string
  default     = "simple"
}

variable "region" {
  description = "List of AWS Regions in which to associate Latency Routing Records. Requests are served to the region with the least latency."
  type        = list(any)
  default     = ["us-east-1", "us-west-2"]
}

variable "weight" {
  description = "The percentage of requests to be served by the Primary DNS Record for Weighted Routing Records"
  type        = number
  default     = 50
}


################################################################################
# Health Check Variables
################################################################################
variable "health_check" {
  description = "Sets whether to evaluate the health of the Route 53 Record set"
  type        = bool
  default     = false
}

variable "health_check_protocol" {
  description = "The protocol used to conduct health checks of the Route 53 Record set. Valid options are 'HTTP', 'HTTPS', 'HTTP_STR_MATCH', 'HTTPS_STR_MATCH', 'TCP', 'CALCULATED' and 'CLOUDWATCH_METRIC'"
  type        = string
  default     = "HTTPS"
}

variable "health_check_port" {
  description = "The Port used to conduct health checks of the Route 53 Record set"
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "The destination for the health check request of the Route 53 Record set."
  type        = string
  default     = "/"
}

variable "health_check_threshold" {
  description = "The number of health checks that must be passed or failed before the target is conisdered healthy or unhealthy"
  type        = number
  default     = 3
}

variable "health_check_interval" {
  description = "The amount of time (sec) that Route 53 waits between sending health checks requests"
  type        = number
  default     = 30
}

