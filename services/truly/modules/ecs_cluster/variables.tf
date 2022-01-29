################################################################################
# Global Varibales
################################################################################
variable "environment" {
  description = "Environment that the nlb will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
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
  description = "Map of tags to be used on all resources created by the module"
  type        = map(any)
  default = {
    builtby = "terraform"
  }
}


################################################################################
# ECS Cluster Variables
################################################################################
variable "cluster_name" {
  description = "Friendly name of the Fargate Cluster"
  type        = string
}


################################################################################
# ECS Exec Variables
################################################################################
variable "enable_ecs_exec" {
  description = "Sets whether to enable ECS Exec to allow users to run commands against Fargate Tasks within the ECS Cluster"
  type        = bool
  default     = false
}
