################################################################################
#  Access Logs
################################################################################
##########################################################
#  Logging KMS Key
##########################################################
module "logging_kms" {
  source      = "./modules/kms"
  environment = terraform.workspace
  service     = "logging"
  suffix      = "logs"
  key_policy  = data.aws_iam_policy_document.logs_key_policy.json

  providers = {
    aws.account   = aws
    aws.secondary = aws
  }
}

##############################################
# Key Policy
##############################################
data "aws_iam_policy_document" "logs_key_policy" {
  provider  = aws
  policy_id = "DeafultEnableIAM"
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [format("arn:aws:iam::%s:root", data.aws_caller_identity.account.account_id)]
    }
  }
  statement {
    sid       = "AllowCloudWatchAccess"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = [format("logs.%s.amazonaws.com", data.aws_region.region.name)]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [format("arn:aws:logs:*:%s:*", data.aws_caller_identity.account.account_id)]
    }
  }
}

##########################################################
#  S3 Access Logs Bucket
##########################################################
module "logging_s3" {
  source                  = "./modules/s3"
  environment             = terraform.workspace
  bucket_name             = "logging"
  is_logging_bucket       = true
  replicate_bucket        = false
  kms_key_arn             = module.logging_kms.key_arn[data.aws_region.region.name]
  kms_key_arn_replication = null
  data_classification     = "internal"

  providers = {
    aws.account     = aws
    aws.replication = aws
  }
}


################################################################################
#  Sessions Manager KMS Key (for ECS Session Logging)
################################################################################
module "sessions_kms" {
  source      = "./modules/kms"
  environment = terraform.workspace
  service     = "sessions-manager"
  suffix      = "sessions-manager"

  providers = {
    aws.account   = aws
    aws.secondary = aws
  }
}