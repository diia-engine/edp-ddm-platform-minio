variable "aws_region" {
  default = "eu-central-1"
}

variable "aws_zone" {
  default = "eu-central-1b"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC"
  default     = "192.168.100.0/24"
}

variable "connection_timeout" {
  type    = number
  default = 300
}

variable "minio_url" {
  type    = string
  default = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2025-04-22T22-12-26Z"
}

variable "mc_url" {
  type    = string
  default = "https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2025-04-16T18-13-26Z"
}

variable "minio_root_user" {
  type    = string
  default = "minio"
}

variable "minio_volume_path" {
  type    = string
  default = "/dev/xvdh"
}

variable "minio_ec2_instance_type" {
  type        = string
  description = "Default instance size for minio instance"
  default     = "t2.micro"
}

variable "minio_ebs_volume_size" {
  type        = string
  description = "Default data volumes size for storage"
  default     = 300
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "main"
}

variable "backup_bucket_name" {
  type        = string
  description = "Bucket name for storing backups"
  default     = "backup-bucket"
}

variable "wait_for_cluster_cmd" {
  description = "Custom local-exec command to execute for determining if the eks cluster is healthy. Cluster endpoint will be available as an environment variable called ENDPOINT"
  type        = string
  default     = "bash -c 'until wget -O - -q $ENDPOINT >/dev/null && true ; do echo \"Waiting for Minio is up and port 9001 is open\"; sleep 15; done'"
}

variable "wait_for_cluster_interpreter" {
  description = "Custom local-exec command line interpreter for the command to determining if the eks cluster is healthy."
  type        = list(string)
  default     = ["/bin/sh", "-c"]
}

variable "kes_download_url" {
  type        = string
  default     = "https://github.com/minio/kes/releases/download/2025-03-12T09-35-18Z/kes-linux-amd64"
  description = "Minio KES binary download URL"
}

variable "vault_auth_secret_id" {
  type        = string
  default     = "secret"
  description = "Minio KES server secret id for vault auth"
}

variable "vault_auth_role_id" {
  type        = string
  default     = "roleid"
  description = "Minio KES server role id for vault auth"
}

variable "vault_ip" {
  type        = string
  default     = "127.0.0.1"
  description = "Minio KES server auth path"
}

variable "tags" {
  type        = map(any)
  description = "A map of tags to add to all resources."
}
