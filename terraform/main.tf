provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "ollama_instance" {
  ami           = var.ami_id
  instance_type = "g5.xlarge"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  # Utilisation d'une instance spot pour réduire les coûts
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = var.max_spot_price
    }
  }

  vpc_security_group_ids = [aws_security_group.ollama_sg.id]
  key_name               = var.key_name

  tags = {
    Name        = "ollama-deepseek"
    Environment = "production"
  }
}

resource "aws_security_group" "ollama_sg" {
  name        = "ollama-security-group"
  description = "Security group for Ollama instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} 