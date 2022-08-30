output "backup_s3_name" {
  value = local.s3_backup_name
}

output "backup_s3_arn" {
  value = module.aws_s3_backups.bucket_arn
}
