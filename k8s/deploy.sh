#!/usr/bin/env bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANGUAGE=en

cd "$(dirname "${BASH_SOURCE[0]}")/.."

IMAGE="movie-watchlist-api:1.0"

step() {
    echo ""
    echo "[$1/8] $2"
    echo "----------------------------------------"
}

read_env() {
    awk -v key="$1" 'index($0, key "=") == 1 { sub(/^[^=]*=/, ""); sub(/\r$/, ""); print; exit }' .env
}

step 1 "Checking environment"

for tool in docker minikube kubectl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    exit 1
fi

for key in POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD PGADMIN_DEFAULT_EMAIL PGADMIN_DEFAULT_PASSWORD; do
    if [ -z "$(read_env "$key")" ]; then
        echo "Error: Missing or empty $key in .env"
        exit 1
    fi
done

if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running"
    exit 1
fi

echo "Environment check passed"

step 2 "Starting Kubernetes cluster"

minikube start --driver=docker

if [ "$(kubectl config current-context)" != "minikube" ]; then
    echo "Error: Unexpected Kubernetes context"
    exit 1
fi

kubectl wait --for=condition=Ready node/minikube --timeout=180s
kubectl get nodes

step 3 "Enabling Kubernetes addons"

minikube addons enable traefik
minikube addons enable metrics-server

kubectl rollout status deployment/traefik -n kube-system --timeout=180s
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

echo "Traefik and Metrics Server are ready"

step 4 "Building and loading Docker image"

docker build -t "$IMAGE" .
minikube image load "$IMAGE" --overwrite=true

echo "Image $IMAGE loaded successfully"

step 5 "Configuring storage and environment"

kubectl apply -f k8s/postgres-pv.yaml
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/pgadmin-pvc.yaml

kubectl create secret generic watchlist-db-secret \
    --from-literal="POSTGRES_DB=$(read_env POSTGRES_DB)" \
    --from-literal="POSTGRES_USER=$(read_env POSTGRES_USER)" \
    --from-literal="POSTGRES_PASSWORD=$(read_env POSTGRES_PASSWORD)" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic watchlist-pgadmin-secret \
    --from-literal="PGADMIN_DEFAULT_EMAIL=$(read_env PGADMIN_DEFAULT_EMAIL)" \
    --from-literal="PGADMIN_DEFAULT_PASSWORD=$(read_env PGADMIN_DEFAULT_PASSWORD)" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/api-configmap.yaml

kubectl get pv,pvc

step 6 "Deploying PostgreSQL"

kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-deployment.yaml

kubectl rollout status deployment/watchlist-postgres --timeout=180s

echo "PostgreSQL status:"
kubectl get pods -l app=watchlist-postgres
kubectl get svc watchlist-postgres

step 7 "Deploying Movie Watchlist API"

kubectl apply -f k8s/api-service.yaml
kubectl apply -f k8s/api-nodeport.yaml
kubectl apply -f k8s/api-loadbalancer.yaml
kubectl apply -f k8s/api-ingress.yaml
kubectl apply -f k8s/api-deployment.yaml

kubectl rollout restart deployment/watchlist-api
kubectl rollout status deployment/watchlist-api --timeout=180s

echo "API status:"
kubectl get pods -l app=watchlist-api

echo "Network services:"
kubectl get svc
kubectl get ingress

step 8 "Deploying pgAdmin and volume demonstrations"

kubectl apply -f k8s/pgadmin-service.yaml
kubectl apply -f k8s/pgadmin-deployment.yaml

kubectl rollout status deployment/watchlist-pgadmin --timeout=300s

echo "pgAdmin status:"
kubectl get pods -l app=watchlist-pgadmin
kubectl get svc watchlist-pgadmin

kubectl apply -f k8s/emptydir-demo.yaml
kubectl apply -f k8s/hostpath-demo.yaml

kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=120s

kubectl rollout status deployment/hostpath-writer --timeout=120s
kubectl rollout status deployment/hostpath-reader --timeout=120s

echo "Volume demonstrations:"
kubectl get pod emptydir-demo
kubectl get pods -l demo=hostpath

echo ""
echo "Deployment summary"
echo "----------------------------------------"

kubectl get pods,deploy,rs
kubectl get svc,ingress,pv,pvc

echo ""
echo "Deployment completed successfully"
echo "Run 'minikube tunnel' to access pgAdmin at http://127.0.0.1:5050"