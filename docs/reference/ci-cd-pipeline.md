# Documentation du pipeline CI/CD

Cette page documente le pipeline GitLab CI/CD utilisé pour tester, valider, déployer et maintenir l'infrastructure DeepSeek R1 sur AWS.

## Structure du pipeline

Le pipeline est défini dans le fichier `.gitlab-ci.yml` et comprend les étapes suivantes :

```
stages:
  - test
  - validate
  - plan
  - apply
  - deploy
  - destroy
```

## Variables du pipeline

| Variable | Description | Type |
|----------|-------------|------|
| `TF_ROOT` | Chemin vers le répertoire Terraform | Prédéfinie |
| `ANSIBLE_ROOT` | Chemin vers le répertoire Ansible | Prédéfinie |
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | Secrète |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | Secrète |
| `AWS_DEFAULT_REGION` | Région AWS par défaut | Prédéfinie |
| `SSH_PRIVATE_KEY` | Clé SSH privée pour la connexion aux instances | Secrète |
| `TERRAFORM_VERSION` | Version de Terraform | Prédéfinie |
| `ANSIBLE_VERSION` | Version d'Ansible | Prédéfinie |
| `MOLECULE_VERSION` | Version de Molecule | Prédéfinie |
| `GOLANG_VERSION` | Version de Go | Prédéfinie |
| `PYTHON_VERSION` | Version de Python | Prédéfinie |

## Étapes du pipeline

### 1. Test

Cette étape exécute les tests unitaires pour Terraform et Ansible.

```yaml
test:
  stage: test
  image: golang:${GOLANG_VERSION}
  before_script:
    - apt-get update && apt-get install -y python3-pip
    - pip install ansible==${ANSIBLE_VERSION} molecule==${MOLECULE_VERSION} molecule-docker ansible-lint yamllint
    - cd ${TF_ROOT}/test && go mod download
    # Installer Terraform
    - wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    - apt-get update && apt-get install -y terraform=${TERRAFORM_VERSION}
  script:
    - cd ${CI_PROJECT_DIR}
    - chmod +x scripts/run_tests.sh
    - ./scripts/run_tests.sh
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" || $CI_COMMIT_BRANCH == "main"'
```

### 2. Validate

Cette étape valide la syntaxe des fichiers Terraform.

```yaml
validate:
  stage: validate
  image: hashicorp/terraform:${TERRAFORM_VERSION}
  script:
    - cd ${TF_ROOT}
    - terraform init -backend=false
    - terraform validate
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" || $CI_COMMIT_BRANCH == "main"'
```

### 3. Plan

Cette étape génère un plan d'exécution Terraform pour visualiser les changements qui seront appliqués.

```yaml
plan:
  stage: plan
  image: hashicorp/terraform:${TERRAFORM_VERSION}
  script:
    - cd ${TF_ROOT}
    - terraform init
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
    expire_in: 1 week
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" || $CI_COMMIT_BRANCH == "main"'
```

### 4. Apply

Cette étape applique les changements Terraform pour créer ou mettre à jour l'infrastructure.

```yaml
apply:
  stage: apply
  image: hashicorp/terraform:${TERRAFORM_VERSION}
  script:
    - cd ${TF_ROOT}
    - terraform init
    - terraform apply -auto-approve
    - terraform output -json > ${CI_PROJECT_DIR}/terraform_output.json
  artifacts:
    paths:
      - ${CI_PROJECT_DIR}/terraform_output.json
    expire_in: 1 week
  when: manual
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

### 5. Deploy

Cette étape déploie l'application Ollama et l'interface utilisateur sur l'instance EC2.

```yaml
deploy:
  stage: deploy
  image: python:${PYTHON_VERSION}-slim
  before_script:
    - apt-get update && apt-get install -y openssh-client jq awscli
    - pip install ansible==${ANSIBLE_VERSION} boto3 botocore
    # Installation des collections Ansible nécessaires
    - ansible-galaxy collection install amazon.aws
  script:
    - cd ${ANSIBLE_ROOT}
    
    # Configuration de la clé SSH
    - mkdir -p ~/.ssh
    - echo "${SSH_PRIVATE_KEY}" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    
    # Récupération des outputs Terraform pour les tags
    - export INSTANCE_ID=$(cat ${CI_PROJECT_DIR}/terraform_output.json | jq -r '.instance_id.value')
    - export REGION=$(cat ${CI_PROJECT_DIR}/terraform_output.json | jq -r '.region.value')
    
    # Création de l'inventaire dynamique AWS
    - |
      cat > aws_ec2.yml << EOF
      plugin: aws_ec2
      regions:
        - ${REGION}
      filters:
        instance-id: ${INSTANCE_ID}
      keyed_groups:
        - key: tags.Name
          prefix: tag_Name_
      compose:
        ansible_host: public_ip_address
      EOF
    
    # Configuration d'Ansible
    - |
      cat > ansible.cfg << EOF
      [defaults]
      host_key_checking = False
      inventory = aws_ec2.yml
      remote_user = ubuntu
      private_key_file = ~/.ssh/id_rsa
      
      [inventory]
      enable_plugins = aws_ec2
      EOF
    
    # Exécution du playbook
    - ansible-inventory --graph
    - ansible-playbook playbook.yml
  when: manual
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  artifacts:
    paths:
      - ${ANSIBLE_ROOT}/aws_ec2.yml
      - ${ANSIBLE_ROOT}/ansible.cfg
    expire_in: 1 week
```

### 6. Destroy

Cette étape détruit l'infrastructure AWS pour éviter des coûts inutiles.

```yaml
destroy:
  stage: destroy
  image: hashicorp/terraform:${TERRAFORM_VERSION}
  script:
    - cd ${TF_ROOT}
    - terraform init
    - terraform destroy -auto-approve
  when: manual
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

## Flux de travail typique

1. **Développement** : Les développeurs créent une branche à partir de `main`, apportent des modifications et soumettent une merge request.
2. **Tests automatiques** : Les étapes `test` et `validate` s'exécutent automatiquement sur chaque merge request.
3. **Planification** : L'étape `plan` génère un plan Terraform pour visualiser les changements.
4. **Revue** : Les développeurs examinent les changements et le plan Terraform.
5. **Fusion** : Après approbation, la merge request est fusionnée dans `main`.
6. **Déploiement** : Un utilisateur autorisé déclenche manuellement les étapes `apply` et `deploy`.
7. **Nettoyage** : Lorsque l'infrastructure n'est plus nécessaire, un utilisateur autorisé déclenche manuellement l'étape `destroy`.

## Sécurité du pipeline

### Gestion des secrets

Les secrets sensibles (clés AWS, clé SSH) sont stockés en tant que variables masquées dans GitLab CI/CD :

1. Accédez à **Settings > CI/CD > Variables**
2. Ajoutez les variables avec l'option **Mask variable** activée
3. Pour les clés SSH, assurez-vous de copier la clé entière, y compris les lignes `-----BEGIN RSA PRIVATE KEY-----` et `-----END RSA PRIVATE KEY-----`

### Permissions

Le pipeline utilise des étapes manuelles pour les opérations sensibles (`apply`, `deploy`, `destroy`) afin d'éviter des modifications accidentelles de l'infrastructure.

## Dépannage du pipeline

### Problèmes courants

1. **Erreur d'authentification AWS** : Vérifiez que les variables `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` sont correctement définies.
2. **Erreur de connexion SSH** : Vérifiez que la variable `SSH_PRIVATE_KEY` contient une clé valide et que le nom de la clé correspond à celui spécifié dans Terraform.
3. **Erreur de validation Terraform** : Exécutez `terraform validate` localement pour identifier les problèmes.
4. **Erreur d'inventaire Ansible** : Vérifiez que l'instance EC2 est en cours d'exécution et que les tags sont correctement définis.

### Logs et débogage

Pour déboguer les problèmes de pipeline :

1. Consultez les logs complets dans l'interface GitLab CI/CD
2. Utilisez l'option **Keep artifacts** pour conserver les artefacts des jobs échoués
3. Ajoutez des commandes de débogage dans les scripts (par exemple, `env`, `ls -la`, `cat file`) 