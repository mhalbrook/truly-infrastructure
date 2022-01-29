################################################################################
# AWS Account inputs
################################################################################
data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

#############################################################
# Primary region
#############################################################
data "aws_region" "region" {
  provider = aws.account
}

data "aws_s3_bucket" "account_logging_bucket" {
  provider = aws.account
  count    = var.is_logging_bucket == true ? 0 : 1
  bucket   = format("%s-%s-logs", data.aws_region.region.name, local.account_name)
}

#############################################################
# Replication Region
#############################################################
data "aws_region" "region_secondary" {
  provider = aws.replication
}

data "aws_s3_bucket" "account_logging_bucket_replication" {
  provider = aws.replication
  count    = var.is_logging_bucket == true ? 0 : 1
  bucket   = format("%s-%s-logs", data.aws_region.region_secondary.name, local.account_name)
}


################################################################################
# AWS Logging Bucket Inputs
# accounts from which AWS delivers S3/ELB Access Logs
################################################################################
data "aws_elb_service_account" "alb_account" {
  provider = aws.account
}

data "aws_elb_service_account" "alb_account_replication" {
  provider = aws.replication
  count    = var.replicate_bucket == true ? 1 : 0
}


