################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "Environment that the App Mesh will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "service_name" {
  description = "Name of the repository"
  type        = string
}

variable "project" {
  description = "Name of the Volly Project the infrastructure supports"
  type        = string
}

variable "tags" {
  description = "A map of additional tags to add to the resources provisioned by the module"
  type        = map(string)
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
# ECR Repository Variables
################################################################################
variable "kms_key_arn" {
  description = "ARN of the KMS Key used to encrypt images in the ECR Repository"
  type        = string
  default     = null
}

variable "attach_lifecycle_policy" {
  description = "Sets whether to attach a default Lifecycle Policy to the ECR Repository"
  type        = bool
  default     = false
}

variable "lifecycle_policy" {
  description = "Custom Lifecycle Policy to attach to the ECR Repository"
  type        = string
  default     = null
}

variable "enable_tag_immutability" {
  description = "Sets whether to make Image Tags Immutable"
  type        = bool
  default     = false
}