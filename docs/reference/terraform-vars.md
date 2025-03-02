# Variables Terraform

Cette page documente toutes les variables Terraform disponibles dans le projet.

## Variables principales

| Variable | Type | Description | Valeur par défaut | Obligatoire |
|----------|------|-------------|------------------|------------|
| `aws_region` | string | Région AWS où déployer l'infrastructure | `"eu-west-1"` | Non |
| `ami_id` | string | ID de l'AMI Ubuntu 24.04 ARM64 | - | Oui |
| `key_name` | string | Nom de la paire de clés SSH AWS | - | Oui |
| `allowed_ip` | string | CIDR de l'IP autorisée à accéder à l'instance | `"0.0.0.0/0"` | Non |
| `max_spot_price` | string | Prix maximum pour l'instance spot | `"1.5"` | Non |
| `instance_type` | string | Type d'instance EC2 | `"g5.xlarge"` | Non |
| `root_volume_size` | number | Taille du volume racine en Go | `100` | Non |
| `tags` | map(string) | Tags à appliquer aux ressources | `{}` | Non |

## Exemple d'utilisation

```hcl
# terraform.tfvars
aws_region     = "eu-west-1"
ami_id         = "ami-0e2d98d2a1e9f0169"
key_name       = "deepseek-key"
allowed_ip     = "123.45.67.89/32"
max_spot_price = "1.2"
instance_type  = "g5.xlarge"
root_volume_size = 120
tags = {
  Project     = "DeepSeek-R1"
  Environment = "Development"
  Owner       = "AI-Team"
}
```

## Détails des variables

### aws_region

La région AWS où l'infrastructure sera déployée. Choisissez une région qui propose des instances g5.xlarge.

Régions recommandées :
- `eu-west-1` (Irlande)
- `us-east-1` (Virginie du Nord)
- `us-west-2` (Oregon)

### ami_id

L'ID de l'AMI Ubuntu 24.04 ARM64. Cet ID varie selon la région.

Pour trouver l'AMI appropriée :
```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-noble-24.04-arm64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --region eu-west-1
```

### key_name

Le nom de la paire de clés SSH AWS utilisée pour se connecter à l'instance.

Pour créer une nouvelle paire de clés :
```bash
aws ec2 create-key-pair --key-name deepseek-key --query 'KeyMaterial' --output text > deepseek-key.pem
chmod 400 deepseek-key.pem
```

### allowed_ip

L'adresse IP ou le bloc CIDR autorisé à accéder à l'instance. Pour des raisons de sécurité, limitez cette valeur à votre propre IP.

Pour obtenir votre IP publique :
```bash
curl ifconfig.me
```

Puis ajoutez `/32` à la fin pour créer un bloc CIDR qui ne contient que votre IP.

### max_spot_price

Le prix maximum que vous êtes prêt à payer pour l'instance spot, en dollars par heure. Si le prix spot dépasse cette valeur, l'instance sera interrompue.

Pour vérifier les prix spot actuels :
```bash
aws ec2 describe-spot-price-history \
  --instance-types g5.xlarge \
  --product-descriptions "Linux/UNIX" \
  --region eu-west-1 \
  --start-time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

### instance_type

Le type d'instance EC2 à utiliser. Le projet est optimisé pour `g5.xlarge`, qui offre un bon équilibre entre performances et coût.

Alternatives possibles :
- `g4dn.xlarge` : Moins cher mais moins performant
- `g5.2xlarge` : Plus performant mais plus cher
- `p4d.24xlarge` : Pour les charges de travail extrêmes (très coûteux)

### root_volume_size

La taille du volume racine en Go. Le modèle DeepSeek R1 nécessite environ 20 Go, mais prévoyez de l'espace supplémentaire pour le système d'exploitation, les logs et d'autres modèles potentiels.

### tags

Des tags à appliquer à toutes les ressources créées. Utile pour la gestion des coûts et l'organisation. 