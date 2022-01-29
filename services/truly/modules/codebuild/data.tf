################################################################################
# AWS Account inputs
################################################################################
data "aws_caller_identity" "account" {
  provider = aws.account
}

data "aws_region" "region" {
  provider = aws.account
}
