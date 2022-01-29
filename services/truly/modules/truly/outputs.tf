################################################################################
#  ECS Fargate Ouputs
################################################################################
#############################################################
# Cluster Ouputs
#############################################################
output "ecs_cluster" {
  value = aws_ecs_service.fargate_service.cluster
}

#############################################################
# Service Ouputs
#############################################################
output "ecs_service_name" {
  value = aws_ecs_service.fargate_service.name
}

output "ecs_service_id" {
  value = aws_ecs_service.fargate_service.id
}

#############################################################
# Task Definition Outputs
#############################################################
output "task_definition_arn" {
  value = aws_ecs_task_definition.fargate_task.arn
}

#############################################################
# Container Definition Outputs
#############################################################
output "container_definitions" {
  value = trimsuffix(join("", [for d in data.template_file.container_definition_segments : d.rendered]), ",")
}

#############################################################
# Autoscaling Outputs
#############################################################
output "autoscaling_policy_name" {
  value = [for v in aws_appautoscaling_policy.ecs_policy : v.name]
}

output "autoscaling_policy_arn" {
  value = [for v in aws_appautoscaling_policy.ecs_policy : v.arn]
}


################################################################################
# Cloudwatch Log Group Outputs
################################################################################
output "log_group_name" {
  value = aws_cloudwatch_log_group.fargate_log_group.name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.fargate_log_group.arn
}


################################################################################
# Security Group Outputs
################################################################################
output "security_group_name" {
  value = aws_security_group.ecs_tasks.name
}

output "security_group_arn" {
  value = aws_security_group.ecs_tasks.arn
}

output "security_group_id" {
  value = aws_security_group.ecs_tasks.id
}


################################################################################
# IAM Role Outputs
################################################################################
output "execution_role_name" {
  value = aws_iam_role.fargate_role["execution"].name
}

output "execution_role_arn" {
  value = aws_iam_role.fargate_role["execution"].arn
}

output "execution_role_id" {
  value = aws_iam_role.fargate_role["execution"].id
}

output "execution_role_unique_id" {
  value = aws_iam_role.fargate_role["execution"].unique_id
}

output "task_role_name" {
  value = aws_iam_role.fargate_role["task"].name
}

output "task_role_arn" {
  value = aws_iam_role.fargate_role["task"].arn
}

output "task_role_id" {
  value = aws_iam_role.fargate_role["task"].id
}

output "task_role_unique_id" {
  value = aws_iam_role.fargate_role["task"].unique_id
}


################################################################################
# Elastic File System Outputs
################################################################################
output "efs_arn" {
  value = [for v in aws_efs_file_system.efs : v.arn]
}

output "efs_id" {
  value = [for v in aws_efs_file_system.efs : v.id]
}

#############################################################
# EFS Access Point Outputs
#############################################################
output "efs_access_point_arn" {
  value = [for v in aws_efs_access_point.access_point : v.arn]
}

output "efs_access_point_id" {
  value = [for v in aws_efs_access_point.access_point : v.id]
}

#############################################################
# EFS Mount Target Outputs
#############################################################
output "efs_mount_target_ids" {
  value = [for v in aws_efs_mount_target.mount_target : v.id]
}

#############################################################
# EFS Policy Outputs
#############################################################
output "efs_policy_id" {
  value = [for v in aws_efs_file_system_policy.efs : v.id]
}


################################################################################
# Service Discovery Outputs
################################################################################
output "service_discovery_name" {
  value = [for v in aws_service_discovery_service.service : v.name]
}

output "service_discovery_arn" {
  value = [for v in aws_service_discovery_service.service : v.arn]
}

output "service_discovery_id" {
  value = [for v in aws_service_discovery_service.service : v.id]
}