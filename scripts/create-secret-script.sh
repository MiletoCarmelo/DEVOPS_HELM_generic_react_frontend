#!/bin/bash

# Créer un fichier temporaire sécurisé pour stocker le PAT
PAT_FILE=$(mktemp)
echo "VOTRE_PAT" > $PAT_FILE

# Configuration Docker avec lecture sécurisée du password
echo -n '{
  "auths": {
    "ghcr.io": {
      "username": "MiletoCarmelo",
      "password": "VOTRE_PAT",
      "auth": "'$(echo -n "MiletoCarmelo:VOTRE_PAT" | base64)'"
    }
  }
}' > docker-config.json

# Créer le secret Kubernetes
kubectl create secret docker-registry technical-secret \
  --from-file=.dockerconfigjson=docker-config.json \
  --namespace votre-namespace \
  --dry-run=client -o yaml > temp-secret.yaml

# Créer le sealed secret
kubeseal \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets \
  --format yaml \
  < temp-secret.yaml > sealed-secret.yaml

# Nettoyer les fichiers temporaires
rm $PAT_FILE docker-config.json temp-secret.yaml

# Afficher le résultat
cat sealed-secret.yaml
