# Premier déploiement complet

Ce tutoriel vous guidera à travers toutes les étapes nécessaires pour déployer DeepSeek R1 sur AWS EC2, en expliquant chaque étape en détail.

## Objectifs d'apprentissage

À la fin de ce tutoriel, vous saurez :
- Configurer Terraform pour déployer une infrastructure AWS
- Utiliser des instances spot EC2 pour réduire les coûts
- Déployer Ollama avec le modèle DeepSeek R1
- Configurer une interface utilisateur web pour interagir avec le modèle

## Étape 1 : Préparation de l'environnement

### Configuration d'AWS

1. Créez un utilisateur IAM avec les permissions nécessaires :
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:*",
           "elasticloadbalancing:*",
           "cloudwatch:*",
           "autoscaling:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

2. Configurez AWS CLI :
   ```bash
   aws configure
   ```

3. Créez une paire de clés SSH si vous n'en avez pas déjà une :
   ```bash
   aws ec2 create-key-pair --key-name deepseek-key --query 'KeyMaterial' --output text > deepseek-key.pem
   chmod 400 deepseek-key.pem
   ```

### Installation des outils

Assurez-vous d'avoir installé :
- Terraform >= 1.11
- Ansible >= 11.0.0

## Étape 2 : Configuration de Terraform

1. Créez un fichier `terraform.tfvars` détaillé :
   ```hcl
   aws_region     = "eu-west-1"
   ami_id         = "ami-0e2d98d2a1e9f0169"
   key_name       = "deepseek-key"
   allowed_ip     = "123.45.67.89/32"  # Votre IP
   max_spot_price = "1.5"
   ```

2. Initialisez Terraform :
   ```bash
   cd terraform
   terraform init
   ```

3. Vérifiez le plan d'exécution :
   ```bash
   terraform plan
   ```

4. Appliquez la configuration :
   ```bash
   terraform apply
   ```

5. Notez les outputs, notamment :
   - `public_ip` : L'adresse IP publique de l'instance
   - `instance_id` : L'identifiant de l'instance EC2
   - `region` : La région AWS utilisée

## Étape 3 : Configuration d'Ansible

1. Créez un fichier d'inventaire `inventory.yml` :
   ```yaml
   ollama_instances:
     hosts:
       ollama-1:
         ansible_host: <PUBLIC_IP>  # Remplacez par l'IP publique
         ansible_user: ubuntu
         ansible_ssh_private_key_file: /chemin/vers/deepseek-key.pem
   ```

2. Vérifiez la connectivité :
   ```bash
   ansible -i inventory.yml ollama_instances -m ping
   ```

## Étape 4 : Déploiement de l'application

1. Exécutez le playbook Ansible :
   ```bash
   ansible-playbook -i inventory.yml playbook.yml
   ```

2. Suivez la progression du déploiement. Cette étape peut prendre 10-15 minutes car elle inclut :
   - Installation d'Ollama
   - Téléchargement du modèle DeepSeek R1 (~20GB)
   - Installation de Node.js et de l'interface utilisateur
   - Configuration du démarrage automatique

## Étape 5 : Vérification et utilisation

1. Accédez à l'interface web :
   ```
   http://<PUBLIC_IP>:3000
   ```

2. Testez le modèle avec quelques requêtes simples :
   - "Explique-moi comment fonctionne un transformeur en IA"
   - "Écris une fonction Python pour trier une liste"

3. Vérifiez l'état des services sur le serveur :
   ```bash
   ansible -i inventory.yml ollama_instances -a "systemctl status ollama"
   ansible -i inventory.yml ollama_instances -a "pm2 status"
   ```

## Conclusion

Félicitations ! Vous avez déployé avec succès DeepSeek R1 sur AWS EC2. Vous pouvez maintenant :

- Explorer les [guides pratiques](../how-to/) pour des tâches spécifiques
- Consulter la [référence technique](../reference/) pour des informations détaillées
- Approfondir votre compréhension avec les [explications](../explanation/)

## Dépannage

Si vous rencontrez des problèmes :

1. Vérifiez que l'instance est en cours d'exécution :
   ```bash
   aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].State.Name'
   ```

2. Vérifiez les logs Ollama :
   ```bash
   ansible -i inventory.yml ollama_instances -a "journalctl -u ollama -n 50"
   ```

3. Vérifiez les logs de l'interface utilisateur :
   ```bash
   ansible -i inventory.yml ollama_instances -a "pm2 logs ollama-ui"
   ``` 