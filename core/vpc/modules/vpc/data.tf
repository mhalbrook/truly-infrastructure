################################################################################
# AWS Account Inputs
################################################################################
#############################################################
# Global Inputs
#############################################################
data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

data "aws_region" "region" {
  provider = aws.account
}

data "aws_availability_zones" "available" {
  provider = aws.account
}

#############################################################
# KMS Inputs
#############################################################
data "aws_kms_key" "logs" {
  provider = aws.account
  key_id   = format("alias/%s-logs", data.aws_region.region.name)
}