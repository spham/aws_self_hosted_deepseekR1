# Projet DeepSeek R1 sur AWS EC2 avec Terraform et Ansible

## Objectif du Projet

Déploiement automatisé de DeepSeek R1 sur une instance AWS EC2 g5.xlarge en utilisant une approche Infrastructure as Code (IaC). Le projet utilise des instances spot pour optimiser les coûts.

## Architecture

* **Infrastructure**: AWS EC2 g5.xlarge (GPU) en région eu-west-1 (Irlande)
* **Modèle**: DeepSeek R1 via Ollama
* **Interface**: UI Web Next.js
* **Outils IaC**: Terraform 1.11 + Ansible 11
* **CI/CD**: GitLab CI

## Prérequis

* AWS CLI configuré
* Terraform >= 1.11
* Ansible >= 11.0.0
* Paire de clés SSH AWS
* AMI Ubuntu 24.04 LTS ARM64
* Go 1.21 (pour les tests)

## Structure du Projet

```
project/
├── terraform/
│   ├── main.tf         # Configuration EC2 et sécurité
│   ├── variables.tf    # Variables Terraform
│   ├── outputs.tf      # Outputs (IP, DNS, etc.)
│   └── test/           # Tests Terraform avec Terratest
├── ansible/
│   ├── inventory.yml   # Inventaire des hôtes
│   ├── playbook.yml    # Playbook principal
│   └── roles/
│       └── ollama/     # Rôle pour DeepSeek/Ollama
│           ├── tasks/  # Tâches Ansible
│           └── molecule/ # Tests du rôle avec Molecule
└── .gitlab-ci.yml      # Pipeline CI/CD
```

## Déploiement

### 1. Préparation des variables

```
# Créer un fichier terraform.tfvars
aws_region     = "eu-west-1"  # Irlande, où g5.xlarge est disponible
ami_id         = "ami-0e2d98d2a1e9f0169"  # AMI Ubuntu 24.04 ARM64
key_name       = "votre-key"
allowed_ip     = "x.x.x.x/32" # Votre IP CIDR
max_spot_price = "1.5"        # Prix max instance spot
```

### 2. Déploiement de l'infrastructure

```
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Configuration de l'inventaire Ansible

```
# ansible/inventory.yml
ollama_instances:
  hosts:
    ollama-1:
      ansible_host: <EC2_PUBLIC_IP>  # Utiliser l'output Terraform
      ansible_user: ubuntu
      ansible_ssh_private_key_file: /path/to/key.pem
```

### 4. Déploiement de l'application

```
cd ../ansible
ansible-playbook -i inventory.yml playbook.yml
```

## Tests

### Tests Terraform

```
cd terraform/test
go test -v -timeout 30m
```

### Tests Ansible

```
cd ansible/roles/ollama
molecule test
```

### Exécution de tous les tests

```
./scripts/run_tests.sh
```

## Pipeline CI/CD

Le projet inclut une pipeline GitLab CI avec les étapes suivantes:

* **test**: Exécute les tests Terraform et Ansible
* **validate**: Valide la syntaxe Terraform
* **plan**: Planifie les changements d'infrastructure
* **apply**: Applique les changements (manuel)
* **deploy**: Déploie l'application avec Ansible (manuel)
* **destroy**: Détruit l'infrastructure (manuel)

### Variables d'environnement GitLab CI

* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY
* SSH_PRIVATE_KEY

## Optimisation des Coûts

* Instance Spot EC2 (économie jusqu'à 70%)
* Volume gp3 pour un meilleur rapport coût/performance
* Sécurité groupe restreint aux IPs nécessaires
* Arrêt automatique de l'instance pendant les périodes d'inactivité

## Monitoring

* PM2 pour la gestion des processus Node.js
* CloudWatch pour les métriques EC2
* Logs Ollama dans `/var/log/ollama`

## Arrêt des Ressources

```
cd terraform
terraform destroy
```

## Points d'Attention

### Coûts:
* Instance g5.xlarge (~$734/mois à la demande, ~$220-300/mois en spot)
* Stockage gp3 100GB (~$10/mois)
* **IMPORTANT**: Surveillez attentivement votre utilisation pour éviter des coûts imprévus

### Sécurité:
* Accès limité par IP
* Ports exposés: 22 (SSH), 3000 (UI)

### Performance:
* Modèle ~20GB en RAM
* Temps de démarrage ~5-10min

## Maintenance

### Mise à jour du modèle:

```
ollama pull deepseek-r1:latest
```

### Redémarrage de l'UI:

```
pm2 restart ollama-ui
```

### Mise à jour des versions:

Pour mettre à jour les versions des outils, modifiez les variables dans `.gitlab-ci.yml`:

```
TERRAFORM_VERSION: "1.11"
ANSIBLE_VERSION: "11.0.0"
MOLECULE_VERSION: "6.0.2"
GOLANG_VERSION: "1.21"
PYTHON_VERSION: "3.11"
```

## Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Commit (`git commit -am 'Ajout de fonctionnalité'`)
4. Push (`git push origin feature/amelioration`)
5. Créer une Pull Request 

## Avertissements de Sécurité

**ATTENTION**: Ce projet déploie une infrastructure cloud avec un modèle d'IA puissant. Veuillez prendre en compte les considérations de sécurité suivantes:

### Groupes de Sécurité AWS:

* Le groupe de sécurité par défaut n'expose que les ports 22 (SSH) et 3000 (UI Web)
* **PERSONNALISATION NÉCESSAIRE**: Modifiez la variable `allowed_ip` pour restreindre l'accès à votre IP uniquement
* Ne laissez JAMAIS les ports ouverts à toutes les IPs (0.0.0.0/0) en production
* Exemple de configuration sécurisée:

```
allowed_ip = "123.45.67.89/32"  # Remplacez par votre IP publique
```

### Authentification:

* L'interface web n'a pas d'authentification par défaut
* Considérez l'ajout d'une authentification basique ou d'un proxy inverse avec authentification
* Exemple avec Nginx et authentification basique:

```
server {
    listen 80;
    server_name ollama.example.com;
    
    location / {
        auth_basic "Zone Restreinte";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Clés SSH:

* Utilisez des clés SSH fortes (ED25519 ou RSA 4096 bits minimum)
* Ne partagez jamais vos clés privées
* Considérez l'utilisation d'un agent SSH avec des clés protégées par mot de passe

### Secrets dans CI/CD:

* Les variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY et SSH_PRIVATE_KEY sont des secrets sensibles
* Utilisez les variables masquées de GitLab CI
* Limitez les permissions IAM au strict minimum nécessaire
* Exemple de politique IAM restrictive:

```
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
        "ec2:AuthorizeSecurityGroupIngress"
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

### Données Sensibles:

* Le modèle DeepSeek R1 traitera toutes les entrées fournies
* Ne soumettez pas de données personnelles ou confidentielles
* Considérez les implications légales (RGPD, etc.) si vous traitez des données d'utilisateurs

### Mises à jour de Sécurité:

* Configurez des mises à jour automatiques pour le système d'exploitation
* Vérifiez régulièrement les vulnérabilités dans les dépendances
* Ajoutez cette tâche à votre playbook Ansible:

```yml
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

## Documentation complète

Une documentation complète suivant le framework [Diátaxis](https://diataxis.fr/) est disponible dans le [dossier docs](./docs/). Cette documentation est organisée en quatre sections distinctes pour répondre à différents besoins :

- **[Tutoriels](./docs/tutorials/)** : Guides pas à pas pour les débutants
- **[Guides pratiques](./docs/how-to/)** : Instructions concises pour accomplir des tâches spécifiques
- **[Référence technique](./docs/reference/)** : Documentation détaillée des composants du système
- **[Explications](./docs/explanation/)** : Discussions approfondies sur les concepts et choix techniques

### Points d'entrée recommandés

- 🚀 **Première utilisation** : Consultez le [guide de démarrage rapide](./docs/tutorials/quickstart.md)
- 🔧 **Maintenance** : Voir le [guide de maintenance](./docs/how-to/maintenance.md)
- 💰 **Optimisation des coûts** : Consultez le [guide d'optimisation des coûts](./docs/how-to/cost-opt.md)
- 🔒 **Sécurité** : Voir le [guide de sécurisation](./docs/how-to/security.md)
- 🧪 **Tests** : Consultez le [guide des tests](./docs/how-to/testing.md)
- 🤔 **Pourquoi ces choix techniques ?** : Voir les [alternatives technologiques](./docs/explanation/alternatives.md)

## Aperçu du projet

![Architecture du projet](./docs/images/architecture.png)

Ce projet permet de déployer rapidement et de manière reproductible le modèle DeepSeek R1 sur AWS EC2 en utilisant:

- **Terraform** pour provisionner l'infrastructure AWS
- **Ansible** pour configurer l'instance et déployer Ollama avec DeepSeek R1
- **Interface Web Next.js** pour interagir avec le modèle via une UI conviviale

### Caractéristiques principales:

- **Optimisation des coûts**: Utilisation d'instances spot EC2 (économie jusqu'à 70%)
- **Déploiement automatisé**: Infrastructure as Code pour un déploiement reproductible
- **Sécurité renforcée**: Groupes de sécurité restreints et bonnes pratiques
- **Maintenance simplifiée**: Scripts et playbooks pour les mises à jour et la maintenance
- **Tests intégrés**: Tests automatisés pour Terraform et Ansible

### Captures d'écran

![Interface utilisateur](./docs/images/ui-screenshot.png)

*Interface web pour interagir avec DeepSeek R1*

![Dashboard de monitoring](./docs/images/monitoring-dashboard.png)

*Dashboard de monitoring des ressources*

### Performances

Sur une instance g5.xlarge, vous pouvez vous attendre aux performances suivantes:

| Métrique | Valeur |
|----------|--------|
| Temps de génération | ~20-30 tokens/seconde |
| Latence initiale | ~500-800ms |
| Utilisation mémoire | ~18-20GB |
| Utilisation GPU | ~90-95% |

### Cas d'utilisation

Ce déploiement est particulièrement adapté pour:

- Développement et test d'applications IA
- Traitement de données sensibles nécessitant une infrastructure privée
- Expérimentation avec des modèles d'IA avancés
- Environnements d'apprentissage et de recherche

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](./LICENSE) pour plus de détails.

## Contact

Pour toute question ou suggestion, veuillez ouvrir une issue sur ce dépôt ou contacter l'équipe à [contact@sylvainp.dev](mailto:contact@sylvainp.dev).
