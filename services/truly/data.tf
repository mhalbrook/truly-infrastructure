################################################################################
# AWS Account inputs
################################################################################
data "aws_region" "region" {
  provider = aws
}

############################################################################################
# VPC Inputs
############################################################################################
data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    bucket  = "us-east-1-halbromr-terraform-state-backend"
    key     = "core/vpc/terraform.tfstate"
    region  = "us-east-1"
    profile = "default"
  }
}

############################################################################################
# Certificate Inputs
############################################################################################
data "terraform_remote_state" "certificates" {
  backend   = "s3"
  workspace = "leveraged"

  config = {
    bucket  = "us-east-1-halbromr-terraform-state-backend"
    key     = "core/certificates/terraform.tfstate"
    region  = "us-east-1"
    profile = "default"
  }
}