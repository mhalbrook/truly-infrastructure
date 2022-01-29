################################################################################
# Bucket Outputs
################################################################################
output "bucket_name" {
  value = {
    (data.aws_region.region.name)           = aws_s3_bucket.s3_bucket.bucket
    (data.aws_region.region_secondary.name) = element(concat(aws_s3_bucket.s3_bucket_replication.*.bucket, [aws_s3_bucket.s3_bucket.bucket]), 0)
  }
}

output "bucket_arn" {
  value = {
    (data.aws_region.region.name)           = aws_s3_bucket.s3_bucket.arn
    (data.aws_region.region_secondary.name) = element(concat(aws_s3_bucket.s3_bucket_replication.*.arn, [aws_s3_bucket.s3_bucket.arn]), 0)
  }
}

output "bucket_id" {
  value = {
    (data.aws_region.region.name)           = aws_s3_bucket.s3_bucket.id
    (data.aws_region.region_secondary.name) = element(concat(aws_s3_bucket.s3_bucket_replication.*.id, [aws_s3_bucket.s3_bucket.id]), 0)
  }
}

output "bucket_domain_name" {
  value = {
    (data.aws_region.region.name)           = aws_s3_bucket.s3_bucket.bucket_domain_name
    (data.aws_region.region_secondary.name) = element(concat(aws_s3_bucket.s3_bucket_replication.*.bucket_domain_name, [aws_s3_bucket.s3_bucket.bucket_domain_name]), 0)
  }
}

output "bucket_hosted_zone_id" {
  value = {
    (data.aws_region.region.name)           = aws_s3_bucket.s3_bucket.hosted_zone_id
    (data.aws_region.region_secondary.name) = element(concat(aws_s3_bucket.s3_bucket_replication.*.hosted_zone_id, [aws_s3_bucket.s3_bucket.hosted_zone_id]), 0)
  }
}

output "bucket_regional_domain_name" {
  value = {
    (data.aws_region.region.name)           = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    (data.aws_region.region_secondary.name) = element(concat(aws_s3_bucket.s3_bucket_replication.*.bucket_regional_domain_name, [aws_s3_bucket.s3_bucket.bucket_regional_domain_name]), 0)
  }
}


################################################################################
# Replication Role Outputs
################################################################################
output "bucket_replication_role_name" {
  value = [for v in aws_iam_role.replication : v.name]
}

output "bucket_replication_role_arn" {
  value = [for v in aws_iam_role.replication : v.arn]
}

output "bucket_replication_role_id" {
  value = [for v in aws_iam_role.replication : v.id]
}

output "bucket_replication_role_unique_id" {
  value = [for v in aws_iam_role.replication : v.unique_id]
}
