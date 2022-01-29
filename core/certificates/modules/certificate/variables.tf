################################################################################
# Global Varibales
################################################################################
variable "environment" {
  description = "environment that the certificate will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "tags" {
  description = "Map of additional tags to add to the resources provisioned by the module"
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
# Certificate Variables
################################################################################
variable "domain_name" {
  description = "The domain name for which the certificate should be issued"
  type        = string
}

variable "subject_alternative_names" {
  description = "A list of additional domains for which the Certificate should be issued"
  type        = list(string)
  default     = []
}

variable "certificate_authority_arn" {
  description = "ARN of the Private Certificate Authority used to sign the certificate"
  type        = string
  default     = null
}


################################################################################
# Certificate Validation Variables
################################################################################
variable "validation_domain" {
  description = "Domain Name associated with the Hosted Zone in which DNS records should be provisioned for Certificate Validation"
  type        = string
  default     = null
}

variable "validation_ttl" {
  description = "The TTL of the record to add to the DNS zone to complete certificate validation"
  type        = string
  default     = "60"
}