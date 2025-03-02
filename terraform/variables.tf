variable "aws_region" {
  default = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS ARM64 AMI ID"
}

variable "key_name" {
  description = "Nom de la paire de clés SSH"
}

variable "allowed_ip" {
  description = "CIDR block pour l'accès"
}

variable "max_spot_price" {
  description = "Prix maximum pour l'instance spot"
  default     = "0.5"
} 