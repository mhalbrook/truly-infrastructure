###############################################################################
# Global Variables
###############################################################################
variable "environment" {
  description = "Environment that the resource will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "service_name" {
  description = "Name of the Volly Service the parameter supports. Set to 'global' when not service-specific"
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


###############################################################################
# SSM Parameter Variables
###############################################################################
variable "name" {
  description = "Name of the ssm parameter"
  type        = string
}

variable "description" {
  description = "Description of the parameter"
  type        = string
  default     = ""
}

variable "value" {
  description = "value for the parameter"
  type        = string
}

variable "tier" {
  description = "The tier of the parameter. If not specified, will default to Standard. Valid tiers are Standard and Advanced"
  type        = string
  default     = "Standard"
}

##########################################################
# Encryption Variables
##########################################################
variable "kms_key_arn" {
  description = "ARN of the kms key used to encrypt the parameter"
  type        = string
  default     = null
}

##########################################################
# Validation Variables
##########################################################
variable "allowed_pattern" {
  description = "Regular expression used to validated the format of the SSM Parameter Value"
  type        = string
  default     = null
}

variable "store_ami_id" {
  description = "Sets whether the SSM Parameter is used to store the ID of an AMI. When set to true, AWS will validate the AMI ID prior to saving the SSM parameter"
  type        = string
  default     = false
}