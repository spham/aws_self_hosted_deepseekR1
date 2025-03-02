# Optimisation des coûts

Ce guide vous aidera à optimiser les coûts de votre déploiement DeepSeek R1 sur AWS.

## Utilisation des instances spot

Le projet utilise déjà des instances spot pour réduire les coûts jusqu'à 70%. Voici comment optimiser davantage cette configuration :

### Ajustement du prix maximum

Modifiez la variable `max_spot_price` dans votre fichier `terraform.tfvars` en fonction des tendances de prix actuelles :

```hcl
max_spot_price = "1.2"  # Ajustez en fonction des prix spot actuels
```

Pour vérifier les prix spot actuels :

```bash
aws ec2 describe-spot-price-history \
  --instance-types g5.xlarge \
  --product-descriptions "Linux/UNIX" \
  --region eu-west-1 \
  --start-time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

### Configuration de la demande d'interruption

Ajoutez cette configuration à votre instance EC2 dans `main.tf` :

```hcl
resource "aws_spot_instance_request" "ollama_instance" {
  # ...
  spot_type = "persistent"
  
  instance_interruption_behavior = "stop"
  
  tags = {
    Name = "ollama-deepseek"
  }
}
```

## Arrêt automatique pendant les périodes d'inactivité

### Configuration d'un script d'arrêt automatique

Ajoutez cette tâche à votre playbook Ansible :

```yaml
- name: Créer un script d'arrêt automatique
  ansible.builtin.copy:
    dest: /usr/local/bin/auto-shutdown.sh
    mode: 0755
    content: |
      #!/bin/bash
      # Vérifier l'utilisation du CPU
      CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print $1}')
      # Convertir en utilisation (100 - idle)
      CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)
      # Si l'utilisation est inférieure à 5% pendant plus d'une heure, arrêter l'instance
      if (( $(echo "$CPU_USAGE < 5" | bc -l) )); then
        # Vérifier depuis combien de temps le CPU est inactif
        IDLE_TIME=$(uptime | awk '{print $3}' | cut -d',' -f1)
        if (( $(echo "$IDLE_TIME > 1.0" | bc -l) )); then
          # Arrêter l'instance
          aws ec2 stop-instances --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        fi
      fi

- name: Ajouter le script au cron
  ansible.builtin.cron:
    name: "auto-shutdown"
    hour: "*/1"
    minute: "0"
    job: "/usr/local/bin/auto-shutdown.sh"
```

### Planification des arrêts nocturnes

Ajoutez une tâche cron pour arrêter l'instance pendant la nuit :

```yaml
- name: Ajouter un arrêt nocturne
  ansible.builtin.cron:
    name: "night-shutdown"
    hour: "1"
    minute: "0"
    job: "aws ec2 stop-instances --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)"
```

## Optimisation du stockage

### Utilisation de volumes gp3 optimisés

Modifiez la configuration du volume EBS dans `main.tf` :

```hcl
resource "aws_ebs_volume" "ollama_data" {
  availability_zone = aws_instance.ollama_instance.availability_zone
  size              = 100
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  
  tags = {
    Name = "ollama-data"
  }
}
```

### Nettoyage automatique des modèles inutilisés

Ajoutez cette tâche à votre playbook Ansible :

```yaml
- name: Script de nettoyage des modèles inutilisés
  ansible.builtin.copy:
    dest: /usr/local/bin/cleanup-models.sh
    mode: 0755
    content: |
      #!/bin/bash
      # Supprimer les modèles non utilisés depuis plus de 30 jours
      find ~/.ollama/models -type f -name "*.bin" -atime +30 -delete
      # Garder uniquement les 2 dernières versions de chaque modèle
      for model in $(ollama list | grep -v "NAME" | awk '{print $1}' | sort | uniq); do
        # Compter le nombre de versions
        versions=$(ollama list | grep "$model" | wc -l)
        if [ $versions -gt 2 ]; then
          # Supprimer les versions les plus anciennes
          ollama list | grep "$model" | sort -k2 | head -n $(($versions - 2)) | awk '{print $1":"$2}' | xargs -I{} ollama rm {}
        fi
      done

- name: Ajouter le script de nettoyage au cron
  ansible.builtin.cron:
    name: "cleanup-models"
    day: "1"
    hour: "3"
    minute: "0"
    job: "/usr/local/bin/cleanup-models.sh"
```

## Utilisation d'AWS Savings Plans

Pour les déploiements à long terme, envisagez d'utiliser AWS Savings Plans :

1. Analysez votre utilisation sur 30 jours
2. Achetez un Compute Savings Plan pour couvrir votre utilisation de base
3. Utilisez des instances spot pour les besoins supplémentaires

## Surveillance et optimisation continue

### Mise en place d'un tableau de bord de coûts

```hcl
resource "aws_cloudwatch_dashboard" "cost_dashboard" {
  dashboard_name = "ollama-cost-optimization"
  
  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "CPUUtilization", "InstanceId", "${aws_instance.ollama_instance.id}" ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.aws_region}",
        "title": "CPU Utilization"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "NetworkIn", "InstanceId", "${aws_instance.ollama_instance.id}" ],
          [ "AWS/EC2", "NetworkOut", "InstanceId", "${aws_instance.ollama_instance.id}" ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${var.aws_region}",
        "title": "Network Traffic"
      }
    }
  ]
}
EOF
}
```

### Configuration des alertes de coûts

```hcl
resource "aws_budgets_budget" "ollama_budget" {
  name              = "ollama-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "100"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["votre@email.com"]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["votre@email.com"]
  }
}
```

## Résumé des économies potentielles

| Stratégie | Économie potentielle |
|-----------|---------------------|
| Instances spot | 60-70% |
| Arrêt automatique | 30-40% |
| Volumes gp3 | 20% |
| Nettoyage des modèles | 10-15% |
| Savings Plans | 20-30% |

En combinant ces stratégies, vous pouvez réduire vos coûts de 70-80% par rapport à un déploiement standard avec des instances à la demande. 