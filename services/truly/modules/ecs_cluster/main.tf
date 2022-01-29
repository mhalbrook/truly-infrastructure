################################################################################
# Locals
################################################################################
locals {
  full_fargate_name = format("%s-%s", var.project, var.cluster_name)
}

################################################################################
# ECS Cluster
################################################################################
resource "aws_ecs_cluster" "fargate_cluster" {
  provider = aws.account
  name     = local.full_fargate_name

  dynamic "configuration" {
    for_each = var.enable_ecs_exec == true ? [1] : []
    content {
      execute_command_configuration {
        kms_key_id = data.aws_kms_key.session_manager.arn
        logging    = "OVERRIDE"

        log_configuration {
          cloud_watch_encryption_enabled = true
          cloud_watch_log_group_name     = aws_cloudwatch_log_group.log_group[0].name
        }
      }
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      "environment" = var.environment
    }
  )
}


################################################################################
# Cloudwatch Log Group
################################################################################
resource "aws_cloudwatch_log_group" "log_group" {
  provider          = aws.account
  count             = var.enable_ecs_exec == true ? 1 : 0
  name              = format("/volly/%s/ecs-exec", local.full_fargate_name)
  retention_in_days = 30
  kms_key_id        = data.aws_kms_key.logs.arn
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}