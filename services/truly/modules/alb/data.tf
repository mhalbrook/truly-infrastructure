################################################################################
# AWS Account inputs
################################################################################
data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

data "aws_region" "region" {
  provider = aws.account
}


################################################################################
# VPC inputs
################################################################################
data "aws_subnet_ids" "subnets" {
  provider = aws.account
  vpc_id   = var.vpc_id
  tags = {
    layer = var.subnet_layer
  }
}

data "aws_subnet" "subnet" {
  provider = aws.account
  for_each = toset(data.aws_subnet_ids.subnets.ids)
  id       = each.value
}


################################################################################
# Logging Bucket inputs
################################################################################
data "aws_s3_bucket" "account_logging_bucket" {
  provider = aws.account
  bucket   = format("%s-%s-logs", data.aws_region.region.name, data.aws_iam_account_alias.account_alias.account_alias)
}