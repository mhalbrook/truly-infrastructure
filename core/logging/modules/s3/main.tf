################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  account_name     = var.project == null ? data.aws_iam_account_alias.account_alias.account_alias : var.project # allow 'project' variable to overwrite account_name, otherwise set dynamically
  bucket_name      = var.is_logging_bucket == false ? var.bucket_name : "logs"                                  # if the bucket is a logging bucket, overwrite the bucket name to 'logs'
  full_bucket_name = format("%s-%s-%s", data.aws_region.region.name, local.account_name, local.bucket_name)     # set bucket name to align to volly schema
}

#############################################################
# Bucket Policy Locals
#############################################################
locals {
  acl                       = var.is_logging_bucket == true ? "log-delivery-write" : "private"
  bucket_policy             = var.is_logging_bucket == true ? data.aws_iam_policy_document.logging_bucket_policy[0].json : var.bucket_policy # set default logging bucket policy if bucket is for logging
  bucket_policy_replication = var.is_logging_bucket == true ? element(concat(data.aws_iam_policy_document.logging_bucket_policy.*.json, [""]), 1) : var.bucket_policy
  objects                   = var.replicate_bucket == true ? formatlist("arn:aws:s3:::%s/*", [local.full_bucket_name, local.full_bucket_name_replication]) : formatlist("arn:aws:s3:::%s/*", [local.full_bucket_name])    # if replication is enabled, create list of both bucket objects, otherwise create list of primary bucket objects
  buckets                   = var.replicate_bucket == true ? formatlist("arn:aws:s3:::%s", [local.full_bucket_name, local.full_bucket_name_replication]) : formatlist("arn:aws:s3:::%s", [local.full_bucket_name])        # if replication is enabled, create list of both bucket ARNs, otherwise create list of primary bucket ARN
  alb_service_account       = var.replicate_bucket == true ? [data.aws_elb_service_account.alb_account.arn, data.aws_elb_service_account.alb_account_replication[0].arn] : [data.aws_elb_service_account.alb_account.arn] # create list of AWS Acocutns that may write logs to buckets. These accoutns are used by AWS to gather and deliver access logs from S3/ELB
}

#############################################################
# Bucket Replication Locals
#############################################################
locals {
  full_bucket_name_replication = format("%s-%s-%s", data.aws_region.region_secondary.name, local.account_name, var.bucket_name) # set replication bucket name to align to volly schema
  kms_key_replication          = var.replicate_bucket == false ? "" : var.kms_key_arn_replication
}

#############################################################
# CORS Locals
#############################################################
locals {
  cors = var.allowed_headers != null || var.allowed_methods != null || var.allowed_origins != null || var.expose_headers != null ? true : false # if any CORS variable is not null, set CORS to 'true'
}

#############################################################
# Lifecycle Rule Locals
#############################################################
locals {
  default_lifecycle = length(var.lifecycle_rules) > 0 ? {} : local.standard_lifecycle                 # if custom lifecycle is provided, do not set a default lifecycle, otherwise set default to standard lifecycle: allows the lifecycle local to perform a reliable condition comparison
  lifecycles        = length(var.lifecycle_rules) > 0 ? var.lifecycle_rules : local.default_lifecycle # Set to custom lifeycle if provided, otherwise set to default lifecycle
  ######
  standard_lifecycle = { # Set the standard lifecycle 
    default-lifecycle = {
      prefix                        = null
      expiration                    = var.is_logging_bucket == false ? null : 14
      noncurrent_version_expiration = var.is_logging_bucket == false ? 90 : 2
      transitions = {
        1 = "INTELLIGENT_TIERING"
      }
      noncurrent_version_transitions = {}
    }
  }
}


################################################################################
# Bucket
################################################################################
resource "aws_s3_bucket" "s3_bucket" {
  provider = aws.account
  bucket   = local.full_bucket_name
  acl      = local.acl
  policy   = local.bucket_policy
  force_destroy = true

  versioning {
    enabled = true
  }

  dynamic "logging" {
    for_each = var.is_logging_bucket == true ? [] : ["logging"]
    content {
      target_bucket = data.aws_s3_bucket.account_logging_bucket[0].id
      target_prefix = format("s3-%s/", var.bucket_name)
    }
  }

  dynamic "lifecycle_rule" {
    for_each = local.lifecycles
    content {
      id                                     = lifecycle_rule.key
      enabled                                = true
      prefix                                 = lifecycle_rule.value.prefix
      abort_incomplete_multipart_upload_days = 2

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration != null ? ["expiration"] : []
        content {
          days                         = lifecycle_rule.value.expiration
          expired_object_delete_marker = false
        }
      }

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration == null ? ["expiration"] : []
        content {
          expired_object_delete_marker = true
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lifecycle_rule.value.noncurrent_version_expiration != null ? ["expiration"] : []
        content {
          days = lifecycle_rule.value.noncurrent_version_expiration
        }
      }

      dynamic "transition" {
        for_each = lifecycle_rule.value.transitions
        content {
          days          = transition.key
          storage_class = transition.value
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = lifecycle_rule.value.noncurrent_version_transitions
        content {
          days          = noncurrent_version_transition.key
          storage_class = noncurrent_version_transition.value
        }
      }
    }
  }


  dynamic "replication_configuration" {
    for_each = var.replicate_bucket == true ? ["replication"] : []
    content {
      role = aws_iam_role.replication[0].arn
      rules {
        id       = "Replication"
        status   = "Enabled"
        priority = 0
        source_selection_criteria {
          sse_kms_encrypted_objects {
            enabled = true
          }
        }
        destination {
          bucket             = format("arn:aws:s3:::%s", local.full_bucket_name_replication)
          replica_kms_key_id = var.kms_key_arn_replication
        }
      }
    }
  }

  dynamic "cors_rule" {
    for_each = local.cors == true ? ["cors"] : []
    content {
      allowed_headers = var.allowed_headers
      allowed_methods = var.allowed_methods
      allowed_origins = var.allowed_origins
      expose_headers  = var.expose_headers
      max_age_seconds = var.max_age_seconds
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = var.is_logging_bucket == true ? "AES256" : "aws:kms"
        kms_master_key_id = var.is_logging_bucket == true ? null : var.kms_key_arn
      }
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}

#############################################################
# Public Access Block
#############################################################
resource "aws_s3_bucket_public_access_block" "public_block" {
  provider                = aws.account
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


################################################################################
# Replicated Bucket
################################################################################
resource "aws_s3_bucket" "s3_bucket_replication" {
  provider = aws.replication
  count    = var.replicate_bucket == true ? 1 : 0
  bucket   = local.full_bucket_name_replication
  acl      = local.acl
  policy   = local.bucket_policy_replication
  force_destroy = true

  versioning {
    enabled = true
  }

  dynamic "logging" {
    for_each = var.is_logging_bucket == true ? [] : ["logging"]
    content {
      target_bucket = data.aws_s3_bucket.account_logging_bucket_replication[0].id
      target_prefix = format("s3-%s/", var.bucket_name)
    }
  }

  dynamic "lifecycle_rule" {
    for_each = local.lifecycles
    content {
      id                                     = lifecycle_rule.key
      enabled                                = true
      prefix                                 = lifecycle_rule.value.prefix
      abort_incomplete_multipart_upload_days = 2

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration != null ? ["expiration"] : []
        content {
          days                         = lifecycle_rule.value.expiration
          expired_object_delete_marker = false
        }
      }

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration == null ? ["expiration"] : []
        content {
          expired_object_delete_marker = true
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lifecycle_rule.value.noncurrent_version_expiration != null ? ["expiration"] : []
        content {
          days = lifecycle_rule.value.noncurrent_version_expiration
        }
      }

      dynamic "transition" {
        for_each = lookup(lifecycle_rule, "transitions", null) != null ? lifecycle_rule.value.transitions : {}
        content {
          days          = lifecycle_rule.value.transitions.days
          storage_class = lifecycle_rule.value.transitions.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = lookup(lifecycle_rule, "noncurrent_version_transitions", null) != null ? lifecycle_rule.value.noncurrent_version_transitions : {}
        content {
          days          = lifecycle_rule.value.noncurrent_version_transitions.days
          storage_class = lifecycle_rule.value.noncurrent_version_transitions.storage_class
        }
      }
    }
  }

  dynamic "replication_configuration" {
    for_each = var.replicate_bucket == true ? ["replication"] : []
    content {
      role = aws_iam_role.replication[0].arn
      rules {
        id       = "Replication"
        status   = "Enabled"
        priority = 0
        source_selection_criteria {
          sse_kms_encrypted_objects {
            enabled = true
          }
        }
        destination {
          bucket             = format("arn:aws:s3:::%s", local.full_bucket_name)
          replica_kms_key_id = var.kms_key_arn
        }
      }
    }
  }

  dynamic "cors_rule" {
    for_each = local.cors == true ? ["cors"] : []
    content {
      allowed_headers = var.allowed_headers
      allowed_methods = var.allowed_methods
      allowed_origins = var.allowed_origins
      expose_headers  = var.expose_headers
      max_age_seconds = var.max_age_seconds
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = var.is_logging_bucket == true ? "AES256" : "aws:kms"
        kms_master_key_id = var.is_logging_bucket == true ? null : var.kms_key_arn_replication
      }
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}

#############################################################
# Block Public Access
#############################################################
resource "aws_s3_bucket_public_access_block" "public_block_replication" {
  provider                = aws.replication
  count                   = var.replicate_bucket == true ? 1 : 0
  bucket                  = aws_s3_bucket.s3_bucket_replication[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


################################################################################
# Replication IAM Role
################################################################################
resource "aws_iam_role" "replication" {
  provider           = aws.account
  count              = var.replicate_bucket == true ? 1 : 0
  name               = format("%s-%s-replication", local.account_name, var.bucket_name)
  description        = format("role for replicating S3 objects between %s buckets", local.bucket_name)
  assume_role_policy = data.aws_iam_policy_document.assume_s3[0].json

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment           = var.environment,
      "data classification" = var.data_classification
    }
  )
}

data "aws_iam_policy_document" "assume_s3" {
  provider = aws.account
  count    = var.replicate_bucket == true ? 1 : 0
  statement {
    sid     = "S3Trust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "replication" {
  provider = aws.account
  count    = var.replicate_bucket == true ? 1 : 0
  statement {
    sid       = "GetBucketInfo"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetReplicationConfiguration", "s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging", "s3:GetObjectRetention", "s3:GetObjectLegalHold"]
    resources = concat([aws_s3_bucket.s3_bucket.arn, aws_s3_bucket.s3_bucket_replication[0].arn], formatlist("%s/*", [aws_s3_bucket.s3_bucket.arn, aws_s3_bucket.s3_bucket_replication[0].arn]))
  }
  statement {
    sid       = "AllowReplication"
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:GetObjectVersionTagging"]
    resources = concat([aws_s3_bucket.s3_bucket.arn, aws_s3_bucket.s3_bucket_replication[0].arn], formatlist("%s/*", [aws_s3_bucket.s3_bucket.arn, aws_s3_bucket.s3_bucket_replication[0].arn]))
  }
  statement {
    sid       = "AllowKMS"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt"]
    resources = [var.kms_key_arn, var.kms_key_arn_replication]
  }
}

resource "aws_iam_policy" "replication" {
  provider    = aws.account
  count       = var.replicate_bucket == true ? 1 : 0
  name        = format("%s-replication", local.full_bucket_name)
  description = format("policy allowing S3 replication between %s buckets", local.bucket_name)
  policy      = data.aws_iam_policy_document.replication[0].json
}

resource "aws_iam_role_policy_attachment" "replication" {
  provider   = aws.account
  count      = var.replicate_bucket == true ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}


################################################################################
# Bucket policy for logging bucket
################################################################################
data "aws_iam_policy_document" "logging_bucket_policy" {
  provider = aws.account
  count    = length(local.buckets)

  statement {
    sid       = "AllowResourceLogging"
    actions   = ["s3:PutObject"]
    resources = [element(local.objects, count.index)]

    principals {
      type        = "AWS"
      identifiers = [element(local.alb_service_account, count.index)]
    }
  }

  statement {
    sid       = "AWSLogDeliveryWrite"
    actions   = ["s3:PutObject"]
    resources = [element(local.objects, count.index)]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com", "cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "AWSLogDeliveryAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [element(local.buckets, count.index)]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com", "cloudtrail.amazonaws.com"]
    }
  }
}


################################################################################
# CloudTrail
################################################################################
resource "aws_cloudtrail" "cloudtrail" {
  provider                      = aws.account
  count                         = var.enable_cloudtrail == true ? 1 : 0
  name                          = format("%s-trail", local.full_bucket_name)
  s3_bucket_name                = data.aws_s3_bucket.account_logging_bucket[0].bucket
  s3_key_prefix                 = format("cloudtrail/%s", local.full_bucket_name)
  enable_log_file_validation    = true
  include_global_service_events = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = formatlist("%s/", local.buckets)
    }
  }
}