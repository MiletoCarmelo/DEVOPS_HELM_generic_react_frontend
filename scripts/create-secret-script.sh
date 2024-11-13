#!/bin/bash

# Variables
NAMESPACE="dev"
SECRET_NAME="technical-secret"

OS_TYPE=$(uname)

# PAT TYPE : 
# ARGOCD_REPO_TOKEN_READ — public_repo, read:packages, repo:status, repo_deployment

# Encoder la configuration complète en base64
if [[ "$OS_TYPE" == "Darwin" ]]; then
    echo "🖥️ Vous êtes sur macOS."
elif [[ "$OS_TYPE" == "Linux" ]]; then
    echo "🐧 Vous êtes sur Linux."
else
    echo "🤔 Système d'exploitation non reconnu : $OS_TYPE"
    echo " => PAS SUR QUE LA COMMANDE BASE64 SOIT CORRECTE"
fi
echo " => important to know for the base64 command"

echo 
echo "🔒 Création d'un secret Docker pour GitHub Container Registry"

# Charger le PAT depuis un fichier .env
if [ -f .env ]; then
    source .env
else
    echo "⚠️  Fichier .env non trouvé, création..."
    echo
    read -sp "Entrez votre GitHub email: " GITHUB_EMAIL
    echo
    echo "GITHUB_EMAIL=${GITHUB_EMAIL}" > .env
    echo "✅ Email sauvegardé dans .env"
    echo
    read -sp "Entrez votre GitHub Username: " GITHUB_USERNAME
    echo
    echo "GITHUB_USERNAME=${GITHUB_USERNAME}" > .env
    echo "✅ Username sauvegardé dans .env"
    echo 
    read -sp "Entrez votre GitHub Personal Access Token: " GITHUB_PAT
    echo
    echo "GITHUB_PAT=${GITHUB_PAT}" > .env
    echo "✅ Token sauvegardé dans .env"
fi

# Vérifier que le GITHUB_EMAIL est défini
if [ -z "$GITHUB_EMAIL" ]; then
    echo "❌ Erreur: GITHUB_EMAIL n'est pas défini dans .env"
    echo 
    read -sp "Entrez votre GitHub email: " GITHUB_EMAIL
    echo
    echo "GITHUB_EMAIL=${GITHUB_EMAIL}" > .env
    echo "✅ Email sauvegardé dans .env"
fi


# Vérifier que le GITHUB_USERNAME est défini
if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ Erreur: GITHUB_USERNAME n'est pas défini dans .env"
    echo 
    read -sp "Entrez votre GitHub Username: " GITHUB_USERNAME
    echo
    echo "GITHUB_USERNAME=${GITHUB_USERNAME}" > .env
    echo "✅ Username sauvegardé dans .env"
fi

# Vérifier que le GITHUB_PAT est défini
if [ -z "$GITHUB_PAT" ]; then
    echo "❌ Erreur: GITHUB_PAT n'est pas défini dans .env"
    echo 
    read -sp "Entrez votre GitHub Personal Access Token: " GITHUB_PAT
    echo
    echo "GITHUB_PAT=${GITHUB_PAT}" > .env
    echo "✅ Token sauvegardé dans .env"
fi


# Supprimer les anciens secrets
echo 
echo "🧹 Nettoyage et suppression des anciens secrets..."
kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE} --ignore-not-found
kubectl delete sealedsecret ${SECRET_NAME} -n ${NAMESPACE} --ignore-not-found
sleep 5

echo
echo "🔍 Vérification du controller sealed-secrets..."
if ! kubectl get pod -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets-controller -o name &> /dev/null; then
    echo "❌ Le controller sealed-secrets n'est pas trouvé !"
    # Nettoyage
    rm temp-secret.yaml sealed-secret.yaml config.json original-secret.yaml 2> /dev/null
    exit 1
fi
echo "✅ Controller sealed-secrets trouvé"


echo
echo "🔑 Configuration Docker pour GitHub Container Registry"
echo " => Username: ${GITHUB_USERNAME}"
echo " => Email: ${GITHUB_EMAIL}"
echo " => PAT: ${GITHUB_PAT}"

# Créer l'auth en base64
echo " => to base64: ${GITHUB_USERNAME}:${GITHUB_PAT}"

if [[ "$OS_TYPE" == "Darwin" ]]; then
    AUTH_STRING=$(printf "%s" "${GITHUB_USERNAME}:${GITHUB_PAT}" | base64)
elif [[ "$OS_TYPE" == "Linux" ]]; then
    AUTH_STRING=$(echo -n "${GITHUB_USERNAME}:${GITHUB_PAT}" | base64)
else
    AUTH_STRING=$(echo -n "${GITHUB_USERNAME}:${GITHUB_PAT}" | base64)
fi


# Créer la configuration Docker en JSON
# DOCKER_JSON=$(cat << EOF
# {
#   "auths": {
#     "ghcr.io": {
#       "username": "${GITHUB_USERNAME}",
#       "password": "${GITHUB_PAT}",
#       "email": "${GITHUB_EMAIL}",
#       "auth": "${AUTH_STRING}"
#     }
#   }
# }
# EOF
# )

# Créer la configuration Docker en JSON
DOCKER_JSON=$(cat << EOF
{
  "auths": {
    "ghcr.io": {
      "auth": "${AUTH_STRING}"
    }
  }
}
EOF
)


# Encoder la configuration complète en base64
if [[ "$OS_TYPE" == "Darwin" ]]; then
    DOCKER_CONFIG_B64=$( printf "%s" "${DOCKER_JSON}" | base64 )
elif [[ "$OS_TYPE" == "Linux" ]]; then
     DOCKER_CONFIG_B64=$( echo -n "${DOCKER_JSON}" | base64 )
else
     DOCKER_CONFIG_B64=$( echo -n "${DOCKER_JSON}" | base64 )
fi


# Créer le secret temporaire
echo "📝 Création du secret temporaire..."
cat > temp-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    sealedsecrets.bitnami.com/namespace-wide: "true"
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${DOCKER_CONFIG_B64}
EOF


# Créer le sealed secret
echo "🔒 Création du sealed secret..."
kubeseal \
  --scope namespace-wide \
  --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets \
  --format yaml \
  --namespace ${NAMESPACE} \
  < temp-secret.yaml > sealed-secret.yaml
  

# Si sealed-secret.yaml n'existe pas, exiter
if [ ! -f "sealed-secret.yaml" ]; then
    echo "❌ Erreur: sealed-secret.yaml n'a pas été créé"
    # Nettoyage
    rm temp-secret.yaml sealed-secret.yaml config.json original-secret.yaml 2> /dev/null
    exit 1
fi


# Appliquer le sealed secret
echo "📦 Application du sealed secret..."
kubectl apply -f sealed-secret.yaml

# Vérifier les événements et l'état du sealed secret
echo "🔍 Vérification du statut du sealed secret et des événements récents dans le namespace ${NAMESPACE}..."

LAST_EVENT=$(kubectl describe sealedsecret ${SECRET_NAME} -n ${NAMESPACE})

if echo "${LAST_EVENT}" | grep -q "ErrUpdateFailed"; then
  echo "❌ Erreur détectée : ErrUpdateFailed. Interruption du script."
  echo
  echo "${LAST_EVENT}"
  echo
  # Nettoyage
  rm temp-secret.yaml sealed-secret.yaml config.json original-secret.yaml 2> /dev/null
  exit 1
fi

echo "✅ Secret créé avec succès!"

sleep 10

# Mettre à jour values.yaml avec le secret encodé
if [ -f "sealed-secret.yaml" ]; then
    echo "Mise à jour de values.yaml..."
    # Extraire la partie encodée du secret
    DOCKER_CONFIG=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.\.dockerconfigjson}')
    
    # Créer ou mettre à jour values.yaml
    cat > values.yaml.new << EOF
# Configuration du secret Docker pour GitHub Container Registry
dockerRegistry:
  enabled: true
  secret:
    name: ${SECRET_NAME}
    namespace: ${NAMESPACE}
    type: kubernetes.io/dockerconfigjson
    data: ${DOCKER_CONFIG}
# Configuration du déploiement
deployment:
  imagePullSecrets:
    name: ${SECRET_NAME}
EOF

    # Ajouter le reste du contenu existant s'il existe
    if [ -f values.yaml ]; then
        echo "Fusion avec le values.yaml existant..."
        # Ignorer les 3 premières lignes (supposées être les commentaires) et ajouter le reste
        tail -n +14 values.yaml >> values.yaml.new
        mv values.yaml.new values.yaml
        echo "✅ values.yaml mis à jour avec succès"
    else
        mv values.yaml.new values.yaml
        echo "✅ Nouveau values.yaml créé"
    fi
fi

# Vérification finale
if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} > /dev/null 2>&1; then
    echo "✅ Secret créé et values.yaml mis à jour avec succès"
    echo "📋 Structure du values.yaml :"
    grep -v "data:" values.yaml | head -n 10  # Affiche la structure sans exposer les données sensibles
else
    echo "❌ Erreur : Le secret n'a pas été créé correctement"
fi

# Nettoyage
rm temp-secret.yaml sealed-secret.yaml config.json original-secret.yaml 2> /dev/null