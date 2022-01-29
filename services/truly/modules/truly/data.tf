################################################################################
# AWS Account inputs
################################################################################
data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

data "aws_caller_identity" "account" {
  provider = aws.account
}

data "aws_caller_identity" "cicd" {
  provider = aws.cicd
}

data "aws_region" "region" {
  provider = aws.account
}


################################################################################
# VPC Inputs
################################################################################
data "aws_vpc" "vpc" {
  provider = aws.account
  id       = var.vpc_id
}

data "aws_subnet_ids" "private" {
  provider = aws.account
  vpc_id   = data.aws_vpc.vpc.id
  tags = {
    layer = "private"
  }
}

data "aws_subnet" "private" {
  provider = aws.account
  for_each = data.aws_subnet_ids.private.ids
  id       = each.value
}


################################################################################
# KMS Inputs
################################################################################
data "aws_kms_key" "logs" {
  provider = aws.account
  key_id   = format("alias/%s-logs", data.aws_region.region.name)
}

data "aws_kms_key" "session_manager" {
  provider = aws.account
  key_id   = format("alias/%s-sessions-manager", data.aws_region.region.name)
}
