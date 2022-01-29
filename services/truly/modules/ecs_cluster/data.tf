################################################################################
# AWS Account inputs
################################################################################
data "aws_region" "region" {
  provider = aws.account
}


################################################################################
# Log Inputs
################################################################################
data "aws_kms_key" "logs" {
  provider = aws.account
  key_id   = format("alias/%s-logs", data.aws_region.region.name)
}

data "aws_kms_key" "session_manager" {
  provider = aws.account
  key_id   = format("alias/%s-sessions-manager", data.aws_region.region.name)
}