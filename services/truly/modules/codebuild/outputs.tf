################################################################################
# CodeBuild Project Outputs
################################################################################
output "project_name" {
  value = aws_codebuild_project.codebuild.name
}

output "project_arn" {
  value = aws_codebuild_project.codebuild.arn
}

output "project_id" {
  value = aws_codebuild_project.codebuild.id
}


################################################################################
# IAM Outputs
################################################################################
output "codebuild_role_name" {
  value = aws_iam_role.codebuild_role.name
}

output "codebuild_role_arn" {
  value = aws_iam_role.codebuild_role.arn
}

output "codebuild_role_id" {
  value = aws_iam_role.codebuild_role.id
}

output "codebuild_role_unique_id" {
  value = aws_iam_role.codebuild_role.unique_id
}
