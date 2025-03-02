# Guide de maintenance

Ce guide couvre les tâches de maintenance courantes pour votre déploiement DeepSeek R1 sur AWS.

## Mise à jour du modèle DeepSeek R1

Pour mettre à jour le modèle vers la dernière version :

```bash
# Connexion à l'instance
ssh -i /chemin/vers/votre-cle.pem ubuntu@<IP_PUBLIQUE>

# Mise à jour du modèle
ollama pull deepseek-r1:latest

# Vérification de la version
ollama list
```

## Redémarrage des services

### Redémarrage d'Ollama

```bash
sudo systemctl restart ollama
sudo systemctl status ollama
```

### Redémarrage de l'interface utilisateur

```bash
pm2 restart ollama-ui
pm2 status
```

## Sauvegarde et restauration

### Sauvegarde des modèles Ollama

```bash
# Sauvegarde
tar -czvf ollama-models.tar.gz ~/.ollama/models

# Copie locale de la sauvegarde
scp -i /chemin/vers/votre-cle.pem ubuntu@<IP_PUBLIQUE>:~/ollama-models.tar.gz .
```

### Restauration des modèles

```bash
# Copie de la sauvegarde vers l'instance
scp -i /chemin/vers/votre-cle.pem ollama-models.tar.gz ubuntu@<IP_PUBLIQUE>:~/

# Restauration
ssh -i /chemin/vers/votre-cle.pem ubuntu@<IP_PUBLIQUE>
sudo systemctl stop ollama
tar -xzvf ollama-models.tar.gz -C ~/
sudo systemctl start ollama
```

## Mise à jour du système d'exploitation

Pour maintenir le système à jour et sécurisé :

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

## Surveillance des ressources

### Vérification de l'utilisation des ressources

```bash
# CPU et mémoire
htop

# Utilisation du disque
df -h

# Utilisation GPU
nvidia-smi
```

### Configuration de la surveillance CloudWatch

Pour configurer des alarmes CloudWatch :

```bash
# Installation de l'agent CloudWatch
sudo apt install -y amazon-cloudwatch-agent

# Configuration de base
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard

# Démarrage de l'agent
sudo systemctl start amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent
```

## Gestion des logs

### Consultation des logs Ollama

```bash
journalctl -u ollama -f
```

### Consultation des logs de l'interface utilisateur

```bash
pm2 logs ollama-ui
```

### Rotation des logs

Les logs système sont automatiquement gérés par logrotate. Pour vérifier la configuration :

```bash
cat /etc/logrotate.d/rsyslog
```

## Mise à jour de l'infrastructure

Pour mettre à jour l'infrastructure avec Terraform :

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Mise à jour de la configuration Ansible

Pour appliquer des modifications à la configuration :

```bash
cd ansible
ansible-playbook -i inventory.yml playbook.yml
```

## Dépannage courant

### Ollama ne démarre pas

```bash
# Vérification des logs
journalctl -u ollama -n 50

# Vérification de l'espace disque
df -h

# Vérification de la mémoire disponible
free -h

# Redémarrage du service
sudo systemctl restart ollama
```

### L'interface utilisateur n'est pas accessible

```bash
# Vérification du statut PM2
pm2 status

# Vérification des logs
pm2 logs ollama-ui

# Redémarrage de l'application
pm2 restart ollama-ui

# Vérification du port
sudo netstat -tulpn | grep 3000
```

### Problèmes de connexion SSH

```bash
# Vérification du groupe de sécurité dans la console AWS
# Vérification de l'état de l'instance
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].State.Name'

# Redémarrage de l'instance si nécessaire
aws ec2 reboot-instances --instance-ids <INSTANCE_ID>
``` 