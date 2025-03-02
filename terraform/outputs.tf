output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.ollama_instance.id
}

output "public_ip" {
  description = "Adresse IP publique de l'instance"
  value       = aws_instance.ollama_instance.public_ip
}

output "public_dns" {
  description = "DNS public de l'instance"
  value       = aws_instance.ollama_instance.public_dns
}

output "region" {
  description = "Région AWS utilisée"
  value       = var.aws_region
}

output "instance_type" {
  description = "Type d'instance utilisé"
  value       = aws_instance.ollama_instance.instance_type
} 