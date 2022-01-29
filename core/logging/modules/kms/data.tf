################################################################################
# AWS Account inputs
################################################################################
data "aws_caller_identity" "current" {
  provider = aws.account
}

data "aws_iam_account_alias" "account_alias" {
  provider = aws.account
}

#############################################################
# Primary region
#############################################################
data "aws_region" "region" {
  provider = aws.account
}

#############################################################
# Secondary Region
#############################################################
data "aws_region" "region_secondary" {
  provider = aws.secondary
}
