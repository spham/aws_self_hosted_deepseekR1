# Architecture du déploiement DeepSeek R1 sur AWS

Ce document explique l'architecture technique du déploiement DeepSeek R1 sur AWS, les choix de conception et les raisons de ces choix.

## Vue d'ensemble de l'architecture

L'architecture se compose des éléments suivants :

```
┌─────────────────────────────────────────────────────────────┐
│                      AWS Cloud (eu-west-1)                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                     VPC par défaut                   │    │
│  │                                                     │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │              Groupe de sécurité             │    │    │
│  │  │                                             │    │    │
│  │  │  ┌─────────────────┐                        │    │    │
│  │  │  │  Instance EC2   │                        │    │    │
│  │  │  │  (g5.xlarge)    │                        │    │    │
│  │  │  │                 │                        │    │    │
│  │  │  │  ┌───────────┐  │                        │    │    │
│  │  │  │  │  Ollama   │  │                        │    │    │
│  │  │  │  │           │  │  Ports:                │    │    │
│  │  │  │  │ DeepSeek  │  │  - 22 (SSH)            │    │    │
│  │  │  │  │    R1     │  │  - 3000 (UI Web)       │    │    │
│  │  │  │  └───────────┘  │  - 11434 (API Ollama)  │    │    │
│  │  │  │                 │                        │    │    │
│  │  │  │  ┌───────────┐  │                        │    │    │
│  │  │  │  │  Web UI   │  │                        │    │    │
│  │  │  │  │  (Next.js)│  │                        │    │    │
│  │  │  │  └───────────┘  │                        │    │    │
│  │  │  │                 │                        │    │    │
│  │  │  └─────────────────┘                        │    │    │
│  │  │                                             │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Composants principaux

### 1. Infrastructure AWS (Terraform)

- **Instance EC2 g5.xlarge** : Instance GPU optimisée pour l'inférence de modèles d'IA
- **Instance Spot** : Utilisation d'instances spot pour réduire les coûts (jusqu'à 70% d'économies)
- **Groupe de sécurité** : Contrôle d'accès réseau limité aux adresses IP spécifiées
- **Volume EBS** : Stockage pour le système d'exploitation et les modèles d'IA

### 2. Logiciel (Ansible)

- **Ollama** : Moteur d'inférence pour exécuter des modèles d'IA localement
- **DeepSeek R1** : Modèle de langage avancé optimisé pour le raisonnement
- **Interface utilisateur Web** : Application Next.js pour interagir avec le modèle
- **PM2** : Gestionnaire de processus pour assurer la disponibilité de l'interface utilisateur

### 3. Pipeline CI/CD (GitLab CI)

- **Tests** : Validation de l'infrastructure et des configurations
- **Déploiement** : Automatisation du déploiement de l'infrastructure et des applications
- **Gestion du cycle de vie** : Création et destruction contrôlées de l'infrastructure

## Choix d'architecture

### Choix de l'instance EC2

Nous avons choisi l'instance **g5.xlarge** pour les raisons suivantes :

1. **GPU NVIDIA A10G** : Offre un excellent rapport performance/prix pour l'inférence de modèles d'IA
2. **16 Go de VRAM** : Suffisant pour exécuter DeepSeek R1 avec de bonnes performances
3. **4 vCPUs et 16 Go de RAM** : Adéquat pour gérer le système d'exploitation et l'interface utilisateur
4. **Disponibilité en spot** : Disponible en tant qu'instance spot pour réduire les coûts

Alternatives considérées :
- **g4dn.xlarge** : Moins cher mais performances inférieures (GPU T4)
- **g5.2xlarge** : Meilleures performances mais coût plus élevé
- **p4d.24xlarge** : Performances exceptionnelles mais coût prohibitif

### Choix du modèle d'IA

Nous avons choisi **DeepSeek R1** pour les raisons suivantes :

1. **Capacités de raisonnement** : Excellentes performances sur les tâches de raisonnement
2. **Taille optimisée** : Modèle de 7B paramètres, offrant un bon équilibre entre performances et ressources requises
3. **Licence permissive** : Licence permettant une utilisation commerciale
4. **Optimisation pour Ollama** : Bien intégré avec l'écosystème Ollama

Alternatives considérées :
- **Llama 3** : Bonnes performances générales mais moins spécialisé dans le raisonnement
- **Mistral** : Bon modèle mais performances de raisonnement inférieures
- **Claude** ou **GPT-4** : Excellentes performances mais nécessitent une API externe et des coûts récurrents

### Choix d'Ollama

Nous avons choisi **Ollama** pour les raisons suivantes :

1. **Simplicité** : Interface simple pour exécuter des modèles d'IA localement
2. **Performance** : Optimisé pour les GPU NVIDIA
3. **API REST** : Facilite l'intégration avec des applications frontales
4. **Gestion des modèles** : Téléchargement et gestion simplifiés des modèles

Alternatives considérées :
- **llama.cpp** : Plus bas niveau, nécessite plus de configuration
- **vLLM** : Meilleures performances mais configuration plus complexe
- **Text Generation Inference** : Bonnes performances mais plus complexe à déployer

### Choix de l'interface utilisateur

Nous avons choisi l'interface **Next.js Ollama UI** pour les raisons suivantes :

1. **Intégration native avec Ollama** : Conçue spécifiquement pour Ollama
2. **Interface moderne** : Interface utilisateur intuitive et réactive
3. **Facilité de déploiement** : Déploiement simple avec Node.js et PM2
4. **Personnalisation** : Facilement adaptable aux besoins spécifiques

Alternatives considérées :
- **Développement d'une interface personnalisée** : Plus de contrôle mais temps de développement plus long
- **Utilisation de l'API directement** : Plus simple mais moins convivial pour les utilisateurs

## Flux de données

1. **Entrée utilisateur** → Interface utilisateur Web (port 3000)
2. **Interface utilisateur** → API Ollama (port 11434)
3. **Ollama** → Modèle DeepSeek R1 (inférence sur GPU)
4. **Modèle DeepSeek R1** → Génération de texte
5. **Ollama** → Interface utilisateur (réponse)
6. **Interface utilisateur** → Affichage à l'utilisateur

## Considérations de sécurité

1. **Accès réseau limité** : Groupe de sécurité restreint aux adresses IP spécifiées
2. **Clés SSH** : Authentification par clé SSH pour l'accès à l'instance
3. **Utilisateur dédié** : Exécution d'Ollama sous un utilisateur dédié (non root)
4. **Mises à jour automatiques** : Configuration des mises à jour de sécurité automatiques

## Considérations de coût

1. **Instances spot** : Réduction des coûts jusqu'à 70% par rapport aux instances à la demande
2. **Arrêt automatique** : Arrêt de l'instance pendant les périodes d'inactivité
3. **Volumes gp3** : Utilisation de volumes EBS optimisés pour le coût
4. **Région optimisée** : Choix de la région AWS offrant le meilleur rapport prix/disponibilité

## Évolutivité et limites

### Capacités actuelles

- **Utilisateurs simultanés** : 1-5 utilisateurs simultanés
- **Taille du contexte** : Jusqu'à 8K tokens
- **Temps de réponse** : 1-5 secondes pour des requêtes typiques

### Limites

- **Mise à l'échelle verticale uniquement** : L'architecture actuelle ne permet pas de mise à l'échelle horizontale
- **Dépendance à une seule instance** : Point unique de défaillance
- **Capacité GPU fixe** : Limitée par les ressources de l'instance g5.xlarge

### Évolutions possibles

- **Équilibrage de charge** : Ajout de plusieurs instances avec un équilibreur de charge
- **Stockage partagé** : Utilisation d'EFS pour partager les modèles entre instances
- **Conteneurisation** : Déploiement avec Docker et ECS/EKS pour une meilleure gestion
- **API Gateway** : Ajout d'une couche API Gateway pour la gestion des requêtes et l'authentification 