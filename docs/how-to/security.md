# Guide de sécurisation du déploiement

Ce guide vous aidera à sécuriser votre déploiement DeepSeek R1 sur AWS.

## Sécurisation des accès réseau

### Configuration du groupe de sécurité

Limitez l'accès à votre instance en modifiant la variable `allowed_ip` dans votre fichier `terraform.tfvars` :

```hcl
allowed_ip = "123.45.67.89/32"  # Remplacez par votre IP publique
```

Pour une sécurité accrue, créez un groupe de sécurité plus restrictif dans `main.tf` :

```hcl
resource "aws_security_group" "ollama_sg" {
  name        = "ollama-sg"
  description = "Security group for Ollama instance"

  # SSH - Restreint à votre IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
    description = "SSH access"
  }

  # UI Web - Restreint à votre IP
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
    description = "Web UI access"
  }

  # Trafic sortant - Tout autoriser
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Mise en place d'un proxy inverse avec authentification

Pour ajouter une couche d'authentification à l'interface utilisateur :

1. Installez Nginx :
   ```bash
   sudo apt update
   sudo apt install -y nginx apache2-utils
   ```

2. Créez un utilisateur :
   ```bash
   sudo htpasswd -c /etc/nginx/.htpasswd votre_utilisateur
   ```

3. Configurez Nginx :
   ```bash
   sudo nano /etc/nginx/sites-available/ollama
   ```

   Ajoutez la configuration suivante :
   ```nginx
   server {
       listen 80;
       server_name _;
       
       location / {
           auth_basic "Zone Restreinte";
           auth_basic_user_file /etc/nginx/.htpasswd;
           proxy_pass http://localhost:3000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

4. Activez la configuration :
   ```bash
   sudo ln -s /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

5. Mettez à jour le groupe de sécurité pour autoriser le port 80 :
   ```hcl
   ingress {
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = [var.allowed_ip]
     description = "HTTP access"
   }
   ```

## Sécurisation des clés SSH

### Utilisation de clés ED25519

Générez une clé ED25519 plus sécurisée :

```bash
ssh-keygen -t ed25519 -C "votre@email.com" -f ~/.ssh/deepseek-key
```

Importez la clé dans AWS :

```bash
aws ec2 import-key-pair --key-name deepseek-key --public-key-material fileb://~/.ssh/deepseek-key.pub
```

Mettez à jour votre `terraform.tfvars` :

```hcl
key_name = "deepseek-key"
```

### Protection par mot de passe de la clé privée

Pour ajouter un mot de passe à une clé existante :

```bash
ssh-keygen -p -f ~/.ssh/deepseek-key
```

## Sécurisation des secrets dans CI/CD

### Utilisation des variables masquées GitLab CI

Dans GitLab, configurez les variables suivantes comme "masquées" et "protégées" :
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- SSH_PRIVATE_KEY

### Limitation des permissions IAM

Créez une politique IAM restrictive :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstances",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "eu-west-1"
        }
      }
    }
  ]
}
```

## Sécurisation du système d'exploitation

### Mises à jour automatiques

Ajoutez cette tâche à votre playbook Ansible :

```yaml
- name: Configuration des mises à jour de sécurité automatiques
  ansible.builtin.apt:
    name: unattended-upgrades
    state: present

- name: Activation des mises à jour automatiques
  ansible.builtin.copy:
    dest: /etc/apt/apt.conf.d/20auto-upgrades
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
```

### Durcissement SSH

Modifiez la configuration SSH dans votre playbook Ansible :

```yaml
- name: Durcissement de la configuration SSH
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
  loop:
    - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin no' }
    - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication no' }
    - { regexp: '^#?X11Forwarding', line: 'X11Forwarding no' }
    - { regexp: '^#?MaxAuthTries', line: 'MaxAuthTries 3' }
  notify: restart ssh

- name: restart ssh
  ansible.builtin.service:
    name: ssh
    state: restarted
```

## Protection des données sensibles

### Isolation du modèle

Assurez-vous que le modèle ne peut pas accéder à des données sensibles :

```yaml
- name: Créer un utilisateur dédié pour Ollama
  ansible.builtin.user:
    name: ollama
    system: yes
    create_home: yes

- name: Configurer le service Ollama pour utiliser l'utilisateur dédié
  ansible.builtin.lineinfile:
    path: /etc/systemd/system/ollama.service
    regexp: '^User='
    line: 'User=ollama'
  notify: restart ollama
```

### Chiffrement des données au repos

Activez le chiffrement EBS dans votre configuration Terraform :

```hcl
resource "aws_ebs_volume" "ollama_data" {
  availability_zone = aws_instance.ollama_instance.availability_zone
  size              = 100
  encrypted         = true
  
  tags = {
    Name = "ollama-data"
  }
}
```

## Audit et surveillance

### Activation des logs CloudTrail

```hcl
resource "aws_cloudtrail" "ollama_trail" {
  name                          = "ollama-trail"
  s3_bucket_name                = aws_s3_bucket.ollama_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true
}
```

### Configuration d'alertes de sécurité

```hcl
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAttemptCount"
  namespace           = "CloudTrailMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
``` 