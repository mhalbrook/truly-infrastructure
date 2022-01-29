################################################################################
# Virtual Private Cloud
################################################################################
module "vpc" {
  source            = "./modules/vpc"
  vpc_name          = terraform.workspace
  vpc_cidr          = var.vpc_cidr[terraform.workspace]
  environment       = terraform.workspace
  application_ports = var.application_ports[terraform.workspace]

  providers = {
    aws.account = aws
  }
}