################################################################################
# Locals
################################################################################
locals {
  full_repo_name = format("%s-%s", var.project, var.service_name)
  immutability = var.enable_tag_immutability == false ? "MUTABLE" : "IMMUTABLE"
  attach_lifecycle_policy = var.lifecycle_policy != null ? true : var.attach_lifecycle_policy
}


################################################################################
# ECR Repository
################################################################################


resource "aws_ecr_repository" "ecr" {
  provider               = aws.account
  name                   = local.full_repo_name
  image_tag_mutability   = local.immutability

  dynamic "encryption_configuration" {
    for_each = var.kms_key_arn != null ? ["encryption"] : []
    content {
      encryption_type = "KMS"
      kms_key         = var.kms_key_arn
    }
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}


################################################################################
# ECR Repository Policy
################################################################################
data "aws_iam_policy_document" "policy" {
  statement {
    sid     = "AWSOrgAccess"
    effect  = "Allow"
    actions = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = ["o-23xm3aw09v"]
    }
  }
}

resource "aws_ecr_repository_policy" "ecrpolicy" {
  repository = aws_ecr_repository.ecr.name
  policy     = data.aws_iam_policy_document.policy.json
}


################################################################################
# ECR Repository Lifecycle Policy
################################################################################
resource "aws_ecr_lifecycle_policy" "default" {
  provider   = aws.account
  count      = local.attach_lifecycle_policy ? 1 : 0
  repository = aws_ecr_repository.ecr.name
  policy     = var.lifecycle_policy != null ? var.lifecycle_policy : file(format("%s/templates/default-lifecycle-policy.json.tpl", path.module))
}
