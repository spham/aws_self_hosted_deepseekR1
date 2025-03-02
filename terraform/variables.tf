variable "aws_region" {
  description = "Région AWS où déployer l'infrastructure"
  default     = "eu-west-1" # Irlande, où g5.xlarge est disponible
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS ARM64 AMI ID"
  # AMI ID pour Ubuntu 24.04 LTS ARM64 en eu-west-1
  default = "ami-0e2d98d2a1e9f0169"
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