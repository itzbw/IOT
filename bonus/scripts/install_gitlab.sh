#!/bin/bash
set -e

echo "=== Adding GitLab Helm repo ==="
helm repo add gitlab https://charts.gitlab.io/ || true
helm repo update

echo "=== Creating gitlab namespace ==="
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

echo "=== Installing GitLab (chart 9.10.5) ==="
helm install gitlab gitlab/gitlab \
  -n gitlab \
  --version 9.10.5 \
  -f bonus/confs/gitlab-values.yaml \
  --timeout 600s

echo "=== Waiting for pods (Ctrl+C once stable) ==="
kubectl get pods -n gitlab -w
