###############################################################################
# Locals
###############################################################################
locals {
  store_ami_id = var.store_ami_id == true ? "aws:ec2:image" : "text"
}

###############################################################################
# SSM Paramter
###############################################################################
resource "aws_ssm_parameter" "default" {
  provider        = aws.account
  name            = var.name
  description     = var.description
  type            = var.kms_key_arn == null ? "String" : "SecureString"
  key_id          = var.kms_key_arn
  tier            = title(var.tier)
  value           = var.value
  allowed_pattern = var.allowed_pattern
  data_type       = local.store_ami_id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      "environment" = var.environment,
      "service"     = var.service_name
    }
  )

  lifecycle {
    ignore_changes = [value]
  }
}
