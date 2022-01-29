################################################################################
# Global Variables
################################################################################
variable "project" {
  description = "Name of the Project the infrastructure supports"
  type        = string
  default     = "truly"
}

variable "service_name" {
  description = "Name of service the infrastructure supports"
  type        = string
  default     = "clojure-demo"
}


################################################################################
# DNS Variables
################################################################################
variable "record_name" {
  description = "Name of DNS Record associated with the service"
  type        = string
  default     = "truly.halbromr.com"
}


################################################################################
# ECS Variables
################################################################################
variable "truly_parameters" {
  description = "Map of parameter values for truly-clojure-test-service"
  type        = map(any)
  default = {
    "/appconfig/MESSAGE" = {
      description = "Message displayed in the truly-clojure-test service response."
      value       = "Hello Truly!"
      tier        = "Standard"
      service     = "clojure-demo"
    }
  }
}