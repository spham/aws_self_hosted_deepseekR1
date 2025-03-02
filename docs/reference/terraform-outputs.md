# Outputs Terraform

Cette page documente tous les outputs Terraform générés par le projet.

## Outputs principaux

| Output | Type | Description |
|--------|------|-------------|
| `public_ip` | string | Adresse IP publique de l'instance EC2 |
| `instance_id` | string | ID de l'instance EC2 |
| `region` | string | Région AWS où l'instance est déployée |
| `security_group_id` | string | ID du groupe de sécurité |
| `ssh_command` | string | Commande SSH pour se connecter à l'instance |
| `web_ui_url` | string | URL de l'interface utilisateur web |

## Utilisation des outputs

### Dans Terraform

Vous pouvez référencer ces outputs dans d'autres modules Terraform :

```hcl
module "ollama" {
  source = "./modules/ollama"
  # ...
}

resource "aws_route53_record" "ollama" {
  zone_id = aws_route53_zone.example.zone_id
  name    = "ollama.example.com"
  type    = "A"
  ttl     = "300"
  records = [module.ollama.public_ip]
}
```

### Dans la ligne de commande

Pour afficher tous les outputs :

```bash
terraform output
```

Pour afficher un output spécifique :

```bash
terraform output public_ip
```

Pour utiliser un output dans un script shell :

```bash
PUBLIC_IP=$(terraform output -raw public_ip)
echo "L'instance est accessible à l'adresse: $PUBLIC_IP"
```

### Dans Ansible

Les outputs sont également utilisés pour générer automatiquement l'inventaire Ansible dans le pipeline CI/CD :

```yaml
- name: Récupération des outputs Terraform
  set_fact:
    public_ip: "{{ lookup('file', 'terraform_output.json') | from_json | json_query('public_ip.value') }}"
    instance_id: "{{ lookup('file', 'terraform_output.json') | from_json | json_query('instance_id.value') }}"
    region: "{{ lookup('file', 'terraform_output.json') | from_json | json_query('region.value') }}"
```

## Détails des outputs

### public_ip

L'adresse IP publique de l'instance EC2. Utilisez cette adresse pour :
- Vous connecter à l'instance via SSH
- Accéder à l'interface utilisateur web (http://PUBLIC_IP:3000)
- Configurer des DNS personnalisés

### instance_id

L'identifiant unique de l'instance EC2. Utilisez cet ID pour :
- Gérer l'instance via AWS CLI ou la console AWS
- Créer des snapshots ou des AMI personnalisées
- Configurer des alarmes CloudWatch

Exemple d'utilisation avec AWS CLI :
```bash
aws ec2 describe-instances --instance-ids i-1234567890abcdef0
```

### region

La région AWS où l'instance est déployée. Utilisez cette information pour :
- Configurer AWS CLI pour interagir avec l'instance
- Créer des ressources supplémentaires dans la même région
- Comprendre la latence potentielle selon votre localisation

### security_group_id

L'identifiant du groupe de sécurité associé à l'instance. Utilisez cet ID pour :
- Modifier les règles de sécurité
- Associer le groupe à d'autres instances
- Configurer des règles de pare-feu supplémentaires

Exemple de modification des règles avec AWS CLI :
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-1234567890abcdef0 \
  --protocol tcp \
  --port 443 \
  --cidr 123.45.67.89/32
```

### ssh_command

Une commande SSH prête à l'emploi pour se connecter à l'instance. Exemple :
```
ssh -i ~/.ssh/deepseek-key.pem ubuntu@12.34.56.78
```

### web_ui_url

L'URL complète pour accéder à l'interface utilisateur web. Exemple :
```
http://12.34.56.78:3000
``` 