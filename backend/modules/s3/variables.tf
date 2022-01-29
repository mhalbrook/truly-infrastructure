################################################################################
# Global Variables
################################################################################
variable "project" {
  description = "Friendly name of the project the S3 Bucket supports. Allows naming convention to be overriden when the bucket should not be named after the account in which it resides."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment that the S3 bucket will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "data_classification" {
  description = "Volly classification of data stored in the S3 bucket. Valid options are 'public', 'strategic', 'internal confidential' or 'client confidential'"
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
# Bucket Variables
################################################################################
variable "bucket_name" {
  description = "Friendly name for the S3 bucket"
  type        = string
}

variable "is_logging_bucket" {
  description = "Set to true if this is the primary logging bucket for the account"
  type        = bool
  default     = false
}

#############################################################
# Encryption
#############################################################
variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the S3 bucket"
  type        = string
}

#############################################################
# Bucket Policies
#############################################################
variable "bucket_policy" {
  description = "Sets the bucket policy for the S3 Bucket. Default to null (unless overwritten by root module) unless bucket is the primary account logging bucket"
  type        = string
  default     = ""
}

#############################################################
# Replication
#############################################################
variable "replicate_bucket" {
  description = "Set equal to true to generate an identical bucket in the us-west-2 region and replicate objects between buckets"
  type        = bool
  default     = false
}

variable "kms_key_arn_replication" {
  description = "ARN of the KMS key used to encrypt the Replication S3 bucket"
  type        = string
  default     = ""
}

#############################################################
# Lifecycle Rules
#############################################################
variable "lifecycle_rules" {
  description = "Map of values to set lifecycle rules for the buckets"
  type        = map(any)
  default     = {}
}

#############################################################
# CORS
#############################################################
variable "allowed_headers" {
  description = "specifies headers allowed via CORS policy"
  type        = list(any)
  default     = null
}

variable "allowed_methods" {
  description = "specifies methods that are allowed via CORS policy"
  type        = list(any)
  default     = null
}

variable "allowed_origins" {
  description = "specifies origins that are allowed via CORS policy"
  type        = list(any)
  default     = null
}

variable "expose_headers" {
  description = "specifies which headers are exposed in responses via CORS policy"
  type        = list(any)
  default     = null
}

variable "max_age_seconds" {
  description = "specifies amount of time (s) that browsers can cache the response for a preflight request via CORS policy"
  type        = number
  default     = 3000
}

#############################################################
# CloudTrail
#############################################################
variable "enable_cloudtrail" {
  description = "Sets whether to create an AWS CloudTrail Trail for S3 Events"
  type        = bool
  default     = false
}