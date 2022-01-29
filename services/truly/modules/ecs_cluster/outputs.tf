################################################################################
# ECS Cluster
################################################################################
output "cluster_name" {
  value = aws_ecs_cluster.fargate_cluster.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.fargate_cluster.arn
}

output "cluster_id" {
  value = aws_ecs_cluster.fargate_cluster.id
}


################################################################################
# Cloudwatch Log Group Outputs
################################################################################
output "log_group_name" {
  value = try(aws_cloudwatch_log_group.log_group[0].name, null)
}

output "log_group_arn" {
  value = try(aws_cloudwatch_log_group.log_group[0].arn, null)
}