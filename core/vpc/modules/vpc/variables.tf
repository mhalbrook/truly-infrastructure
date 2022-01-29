################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "The environment the VPC supports"
  type        = string
}

variable "tags" {
  description = "A map of additional tags to add to specific resources"
  type        = map(string)
  default     = {}
}

variable "default_tags" {
  description = "Map of tags to be used on all resources created by the module"
  type        = map(any)

  default = {
    builtby               = "terraform"
    "data classification" = "internal confidential"
  }
}


################################################################################
# VPC Variables
################################################################################
variable "vpc_name" {
  description = "Friendly name for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to configured in the VPC"
  type        = number
  default     = 2
}

variable "domain_join" {
  description = "Sets whether to create Routes and NACL Rules for access to the network where the Volly Active Directory instances are hosted"
  type        = bool
  default     = false
}


################################################################################
# NACL Variables
################################################################################
variable "application_ports" {
  description = "list of Ports on which the applications within the Private Subnet of the VPC will listen"
  type        = list(any)
  default     = []
}

variable "database_ports" {
  description = "list of Ports on which the databases within the VPC will listen"
  type        = list(any)
  default     = []
}

variable "enable_icmp" {
  description = "sets whether to generate NACL Rules allowing ICMP (ping) connections from Volly Campus and Local networks"
  type        = bool
  default     = false
}


################################################################################
# Gateway Variables
################################################################################
variable "internet_enabled" {
  description = "Sets whether to enable inbound internet traffic via an Internet Gateway"
  type        = bool
  default     = true
}

variable "transit_gateway_id" {
  description = "ID of the transit Gateway to attach to the VPC"
  type        = string
  default     = null
}

################################################################################
# External Network Variables
################################################################################
variable "domain_cidr" {
  description = "CIDR of the network where the Volly Active Directory instances are hosted"
  type        = string
  default     = "172.20.0.0/16"
}

variable "domain_name" {
  description = "Name of the Domain that the VPC is configured to join"
  type        = string
  default     = "loyaltyexpress.local"
}

variable "domain_ips" {
  description = "IP addresses of the Volly Domain Controllers"
  type        = list(any)
  default     = ["172.20.20.110", "172.20.21.210"]
}

variable "campus_cidrs" {
  description = "CIDRs of the Volly Campus and Campus VPN subnets"
  type        = list(any)
  default     = ["172.16.6.0/24", "172.16.16.0/24"]
}
