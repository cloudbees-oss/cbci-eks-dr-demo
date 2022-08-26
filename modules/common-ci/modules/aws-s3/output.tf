output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "kms_alias" {
  value = var.encryption ? aws_kms_alias.key-alias[0].name : null
}
