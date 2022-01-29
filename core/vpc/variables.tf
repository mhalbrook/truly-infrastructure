variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = map(any)
  default = {
    truly = "10.1.0.0/16"
  }
}

variable "application_ports" {
  description = "List of ports the backend applications listen on"
  type        = map(any)
  default = {
    truly = [8080]
  }
}