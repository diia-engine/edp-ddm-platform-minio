data "aws_nat_gateway" "cluster_ip" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}*"]
  }
}

data "http" "external_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_ami" "ubuntu" {
  most_recent = "true"
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["platform-${var.cluster_name}"]
  }
}

data "aws_internet_gateway" "gw" {
  filter {
    name   = "tag:Name"
    values = ["platform-${var.cluster_name}"]
  }
}

data "aws_subnet" "public_subnet" {
  filter {
    name   = "tag:Name"
    values = ["platform-${var.cluster_name}"]
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}


module "kes_minio_api_key" {
  source     = "github.com/matti/terraform-shell-outputs.git"
  command    = <<EOT
          timeout ${var.connection_timeout}s bash -c '
          while ! nc -w 2 ${aws_eip.minio_ip.public_ip} 22 > /dev/null ; do
              sleep 5;
          done' && ssh -o 'StrictHostKeyChecking no' \
                 -o 'ConnectionAttempts 5' \
                 -i private_minio.key  ubuntu@${aws_eip.minio_ip.public_ip} \
                  timeout ${var.connection_timeout}s bash -c '
          while [ ! -e /etc/minio/kes-client/platform-api-key ] ; do
              sleep 5;
          done' && ssh -o "StrictHostKeyChecking no" \
                       -o "ConnectionAttempts 5" \
                       -i private_minio.key \
                       ubuntu@${aws_eip.minio_ip.public_ip} \
                       cat /etc/minio/kes-client/platform-api-key
          '
  EOT
  depends_on = [null_resource.minio_init]
}
