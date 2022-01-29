################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "Environment that the nlb will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "tags" {
  description = "A map of additional tags to add to specific resources"
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
# KMS Key Variables
################################################################################
variable "service" {
  description = "The service that the KMS Key is used to encrypt (i.e. 'S3' or 'volly_platform')"
  type        = string
}

#############################################################
# Multi-Region Variables
#############################################################
variable "multi_region" {
  description = "Sets whether a key should be created in multiple regions or just one"
  type        = bool
  default     = false
}

#############################################################
# Key Policy Variables
#############################################################
variable "key_policy" {
  description = "custom KMS key policy for access to key. Default policy is created if a custom policy is not passed from root"
  default     = null
}

#############################################################
# Logging key Variables
#############################################################
variable "is_logging_key" {
  description = "Sets whether the KMS Key is used to encrypt S3 Buckets that collect Access Logs from Load Balancers and/or S3 Buckets"
  default     = false
}