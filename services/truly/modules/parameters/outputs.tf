###############################################################################
# SSM Paramter Outputs
###############################################################################
output "ssm_name" {
  value = aws_ssm_parameter.default.name
}

output "ssm_arn" {
  value = aws_ssm_parameter.default.arn
}

output "ssm_type" {
  value = aws_ssm_parameter.default.type
}

output "ssm_value" {
  value     = aws_ssm_parameter.default.value
  sensitive = true
}

output "ssm_version" {
  value = aws_ssm_parameter.default.version
}

