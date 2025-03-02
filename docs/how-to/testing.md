# Comment exécuter les tests

Ce guide explique comment exécuter les différents tests du projet pour valider votre infrastructure et votre configuration.

## Tests Terraform avec Terratest

Les tests Terraform vérifient que l'infrastructure se déploie correctement et que les ressources sont configurées comme prévu.

### Prérequis

- Go 1.21 ou supérieur
- Terraform 1.11 ou supérieur
- Accès AWS avec les permissions nécessaires

### Exécution des tests Terraform

```bash
cd terraform/test
go test -v -timeout 30m
```

Ce test va :
1. Déployer l'infrastructure dans AWS
2. Vérifier que l'instance est en cours d'exécution
3. Vérifier que les ports nécessaires sont ouverts
4. Détruire l'infrastructure à la fin du test

### Options de test avancées

Pour exécuter un test spécifique :

```bash
go test -v -run TestTerraformDeployment -timeout 30m
```

Pour conserver l'infrastructure après le test (utile pour le débogage) :

```bash
SKIP_destroy=true go test -v -timeout 30m
```

## Tests Ansible avec Molecule

Les tests Molecule vérifient que les rôles Ansible fonctionnent correctement dans un environnement isolé.

### Prérequis

- Python 3.11 ou supérieur
- Ansible 11.0.0 ou supérieur
- Molecule 6.0.2 ou supérieur
- Docker (pour les tests locaux)

### Exécution des tests Molecule

```bash
cd ansible/roles/ollama
molecule test
```

Ce test va :
1. Créer un conteneur Docker
2. Exécuter le rôle Ansible dans ce conteneur
3. Vérifier que tous les composants sont correctement installés
4. Détruire le conteneur à la fin du test

### Options de test avancées

Pour exécuter uniquement certaines phases :

```bash
# Uniquement la création et la convergence
molecule create
molecule converge

# Uniquement la vérification
molecule verify

# Conserver l'instance pour le débogage
molecule converge --no-destroy
```

## Exécution de tous les tests

Pour exécuter tous les tests en une seule commande :

```bash
./scripts/run_tests.sh
```

## Tests dans le pipeline CI/CD

Les tests sont automatiquement exécutés dans le pipeline GitLab CI à chaque push ou merge request. Vous pouvez consulter les résultats dans l'interface GitLab.

## Dépannage des tests

### Problèmes courants avec Terratest

- **Timeout** : Augmentez la valeur du timeout si le déploiement prend plus de temps que prévu
- **Erreurs d'authentification AWS** : Vérifiez vos variables d'environnement AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY
- **Ressources déjà existantes** : Assurez-vous qu'il n'y a pas de ressources avec les mêmes noms déjà déployées

### Problèmes courants avec Molecule

- **Erreurs Docker** : Vérifiez que Docker est en cours d'exécution et que vous avez les permissions nécessaires
- **Erreurs de dépendances Python** : Utilisez un environnement virtuel pour isoler les dépendances
- **Erreurs de connexion** : Vérifiez les paramètres de connexion dans molecule.yml 