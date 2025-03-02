#!/bin/bash
set -e

# Vérifier les versions
echo "Vérification des versions..."
terraform version | head -n 1
ansible --version | head -n 1

echo "Exécution des tests Terraform..."
cd terraform/test
go test -v -timeout 30m

echo "Exécution des tests Ansible..."
cd ../../ansible/roles/ollama
molecule test

echo "Tous les tests ont réussi!" 