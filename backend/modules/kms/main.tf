################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  full_key_name           = format("%s-%s", data.aws_region.region.name, var.suffix) # sets key name for primary KMS Key
  full_key_name_secondary = format("%s-%s", data.aws_region.region_secondary.name, var.suffix) # sets key name for secondary KMS Key if multi-region key is created
}

#############################################################
# Key Policy Locals
#############################################################
locals {
  default_key_policy = var.is_logging_key == true ? data.aws_iam_policy_document.key_policy_logs.json : data.aws_iam_policy_document.key_policy.json # sets the defautl key policy dependent on whether the key is used for S3 Buckets that colletd Access Logs
  key_policy = var.key_policy == null ? local.default_key_policy : var.key_policy # Sets custom key policy if provided, otherwise sets to default policy
  regions = var.multi_region == true ? [data.aws_region.region.name, data.aws_region.region_secondary.name] : [data.aws_region.region.name] # sets lits of regions dependent on whether the key is multi-region
}


################################################################################
# KMS Key Policies
################################################################################
#############################################################
# Default Key Policy
#############################################################
data "aws_iam_policy_document" "key_policy" {
  provider = aws.account
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = formatlist("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id)
    }
  }
}

#############################################################
# Default Key Policy for Keys Used with Logging Buckets
#############################################################
data "aws_iam_policy_document" "key_policy_logs" {
  provider  = aws.account
  policy_id = "key-default-1"
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [format("arn:aws:iam::%s:root", data.aws_caller_identity.current.id)]
    }
  }
  statement {
    sid       = "AllowCloudWatchAccess"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEcrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = formatlist("logs.%s.amazonaws.com", local.regions)
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [format("arn:aws:logs:*:%s:*", data.aws_caller_identity.current.id)]
    }
  }
}


################################################################################
# KMS Keys
################################################################################
#############################################################
# Primary KMS Key
#############################################################
resource "aws_kms_key" "kms" {
  provider                = aws.account
  description             = format("KMS key for %s", var.service)
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.key_policy

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_kms_alias" "kms" {
  provider      = aws.account
  name          = format("alias/%s", local.full_key_name)
  target_key_id = aws_kms_key.kms.id
}

#############################################################
# Secondary KMS Key
#############################################################
resource "aws_kms_key" "kms_secondary" {
  provider                = aws.secondary
  count                   = var.multi_region == true ? 1 : 0
  description             = format("KMS key for %s", var.service)
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.key_policy

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_kms_alias" "kms_secondary" {
  provider      = aws.secondary
  count         = var.multi_region == true ? 1 : 0
  name          = format("alias/%s", local.full_key_name_secondary)
  target_key_id = aws_kms_key.kms_secondary[0].id
}
