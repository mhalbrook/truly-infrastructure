################################################################################
# KMS Key Outputs
################################################################################
output "key_name" {
  value = {
    (data.aws_region.region_secondary.name) = try(trimprefix(aws_kms_alias.kms_secondary[0].name, "alias/"), null)
    (data.aws_region.region.name)           = trimprefix(aws_kms_alias.kms.name, "alias/")
  }
}

output "key_alias" {
  value = {
    (data.aws_region.region_secondary.name) = try(aws_kms_alias.kms_secondary[0].name, null)
    (data.aws_region.region.name)           = aws_kms_alias.kms.name
  }
}

output "key_arn" {
  value = {
    (data.aws_region.region_secondary.name) = try(aws_kms_key.kms_secondary[0].arn, null)
    (data.aws_region.region.name)           = aws_kms_key.kms.arn
  }
}

output "key_id" {
  value = {
    (data.aws_region.region_secondary.name) = try(aws_kms_key.kms_secondary[0].id, null)
    (data.aws_region.region.name)           = aws_kms_key.kms.id
  }
}