#!/bin/bash

# Variables
NAMESPACE="dev"
SECRET_NAME="technical-secret"

# Créer le contenu du .dockerconfigjson
cat << EOF > docker-config.json
{
  "auths": {
    "ghcr.io": {
      "username": "<ussename>",
      "password": "<pat>",
      "auth": "$(echo -n "<username>:<pat>" | base64)"
    }
  }
}
EOF

# Créer le secret normal
kubectl create secret docker-registry ${SECRET_NAME} \
  --namespace=${NAMESPACE} \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<pat> \
  --dry-run=client -o yaml > temp-secret.yaml

# Créer le sealed secret
kubeseal \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets \
  --format yaml \
  < temp-secret.yaml > sealed-secret.yaml

# Appliquer le sealed secret
kubectl apply -f sealed-secret.yaml -n ${NAMESPACE}

# Nettoyage
rm docker-config.json temp-secret.yaml

# Vérification
echo "Attente de la création du secret..."
sleep 5
kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}

# move to templates/technical-secret.yaml
mv sealed-secret.yaml templates/technical-secret.yaml


echo "Process completed. Check the templates/technical-secret.yaml file for the encrypted value."