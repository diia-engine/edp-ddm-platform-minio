output "minio_root_user" {
  sensitive = true
  value     = var.minio_root_user
}

output "minio_root_password" {
  sensitive = true
  value     = random_password.password.result
}

output "minio_kes_api_key" {
  sensitive = true
  value     = module.kes_minio_api_key.stdout
}
