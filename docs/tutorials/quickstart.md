# Guide de démarrage rapide

Ce guide vous permettra de déployer rapidement DeepSeek R1 sur AWS en quelques étapes simples.

## Prérequis

Avant de commencer, assurez-vous d'avoir :

- Un compte AWS avec les permissions nécessaires
- AWS CLI configuré localement
- Terraform >= 1.11 installé
- Ansible >= 11.0.0 installé

## Étapes de déploiement rapide

### 1. Cloner le dépôt

```bash
git clone https://github.com/votre-org/deepseek-aws-deployment.git
cd deepseek-aws-deployment
```

### 2. Configurer les variables

Créez un fichier `terraform.tfvars` avec le contenu suivant :

```hcl
aws_region     = "eu-west-1"  # Irlande, où g5.xlarge est disponible
ami_id         = "ami-0e2d98d2a1e9f0169"  # AMI Ubuntu 24.04 ARM64
key_name       = "votre-key"  # Remplacez par le nom de votre clé SSH AWS
allowed_ip     = "x.x.x.x/32" # Remplacez par votre IP CIDR
max_spot_price = "1.5"        # Prix max instance spot
```

### 3. Déployer l'infrastructure

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Notez l'adresse IP publique dans les outputs.

### 4. Déployer l'application

```bash
cd ../ansible
ansible-playbook -i "PUBLIC_IP," -u ubuntu --private-key=/chemin/vers/votre-key.pem playbook.yml
```

Remplacez `PUBLIC_IP` par l'adresse IP obtenue à l'étape précédente.

### 5. Accéder à l'interface

Ouvrez votre navigateur et accédez à `http://PUBLIC_IP:3000`

## Prochaines étapes

- Consultez [le tutoriel de déploiement complet](./first-deploy.md) pour une explication détaillée
- Découvrez comment [sécuriser votre déploiement](../how-to/security.md)
- Apprenez à [optimiser les coûts](../how-to/cost-opt.md) de votre infrastructure 