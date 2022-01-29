################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  full_project_name = format("%s-%s", var.project, var.service_name) # set the project name to align with Volly naming schema
}

#############################################################
# Build Detail Locals
#############################################################
locals {
  buildspec                = var.buildspec == null ? file(format("%s/buildspec.yml", path.module)) : var.buildspec                                                # use the default buildspec if one is not provided by the root module
  standardize_compute_type = var.environment_type != "LINUX_CONTAINER" && var.compute_type == "BUILD_GENERAL1_SMALL" ? "BUILD_GENERAL1_MEDIUM" : var.compute_type # Small compute type is only valid for LINUX_CONTAINER environments. If Small is selected with an environment other than LINUX_CONTAINER, set the compute to Medium to avoid errors
  compute_type             = var.environment_type == "LINUX_GPU_CONTAINER" ? "BUILD_GENERAL1_LARGE" : local.standardize_compute_type                              # When environment is set to LINUX_GPU_CONTAINER, the compute type must be Large, so forve that configuration, otherwise respect the compute type variable setting
  environment_variables = {                                                                                                                                       # set the environment variables of the CodeBuild Project
    "AWS_ACCOUNT_ID"     = data.aws_caller_identity.account.account_id
    "AWS_DEFAULT_REGION" = data.aws_region.region.name
    "ECR_REPO"           = local.full_project_name
    "ENV_TAG"            = "setbyJenkinsfile"
    "SERVICE"            = var.service_name
  }
}

#############################################################
# Logging Locals
#############################################################
locals {
  log_group_arn = format("arn:aws:logs:%s:%s:log-group:/aws/codebuild/%s", data.aws_region.region.name, data.aws_caller_identity.account.account_id, local.full_project_name) # set the name of the log group for CodeBuild project logs
}


################################################################################
# CodeBuild Project
################################################################################
resource "aws_codebuild_project" "codebuild" {
  provider       = aws.account
  name           = local.full_project_name
  description    = format("Project for %s builds", local.full_project_name)
  service_role   = aws_iam_role.codebuild_role.arn
  encryption_key = var.kms_key_arn
  build_timeout  = var.build_timeout
  source_version = var.source_version

  artifacts {
    type                   = upper(var.artifacts_type)
    location               = var.artifacts_location
    namespace_type         = var.artifacts_type == "S3" ? var.artifacts_namespace : null
    encryption_disabled    = false
    override_artifact_name = var.artifacts_override_name
    packaging              = var.artifacts_type == "S3" && var.artifacts_zip_package == true ? "ZIP" : var.artifacts_type == "S3" ? "NONE" : null
  }

  environment {
    type            = var.environment_type
    compute_type    = var.compute_type
    image           = var.image_id
    privileged_mode = var.privileged_mode

    dynamic "environment_variable" {
      for_each = merge(local.environment_variables, var.environment_variables)
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  source {
    type      = upper(var.source_provider)
    buildspec = local.buildspec
    location  = var.source_location
  }

  cache {
    type     = var.cache_type
    location = var.cache_location
    modes    = var.cache_modes
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
# IAM Role for CodeBuild
################################################################################
resource "aws_iam_role" "codebuild_role" {
  provider           = aws.account
  name               = format("%s-%s-codebuild", data.aws_region.region.name, local.full_project_name)
  description        = format("Role used by CodeBuild to complete %s builds", local.full_project_name)
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  path               = "/"

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.log_group_arn, format("%s:*", local.log_group_arn)]
  }
  statement {
    effect    = "Allow"
    actions   = ["codebuild:CreateReportGroup", "codebuild:CreateReport", "codebuild:UpdateReport", "codebuild:BatchPutTestCases"]
    resources = ["arn:aws:codebuild:us-east-1:396564397582:report-group/portal-*"]
  }
}

resource "aws_iam_policy" "codebuild_policy" {
  provider    = aws.account
  name        = format("%s-%s-codebuild", data.aws_region.region.name, local.full_project_name)
  description = format("Policy allowing for the creation of CodeBuild reports & logging for %s", local.full_project_name)
  policy      = data.aws_iam_policy_document.policy.json
  path        = "/"
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  provider   = aws.account
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecr" {
  provider   = aws.account
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
