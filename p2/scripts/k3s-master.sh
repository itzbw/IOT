#!/bin/bash

set -e

export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

NODE_IP="192.168.56.110"
K3S="/usr/local/bin/k3s"

echo "🔧 Installing K3s on server node at $NODE_IP..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --node-ip=$NODE_IP

while [ ! -f /etc/rancher/k3s/k3s.yaml ] || [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  echo "⏳ Waiting for K3s to be ready..."
  sleep 2
done

while ! $K3S kubectl get nodes &>/dev/null; do
  echo "⏳ Waiting for K3s API server..."
  sleep 2
done
echo "✅ K3s is ready!"

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

mkdir -p /vagrant/confs
cat /var/lib/rancher/k3s/server/node-token > /vagrant/confs/token

MANIFEST_DIR="/vagrant/confs"
echo "📦 Looking for Kubernetes YAMLs in $MANIFEST_DIR"

if ls $MANIFEST_DIR/*.yml >/dev/null 2>&1; then
  echo "🚀 Applying Kubernetes manifests to kube-system..."
  $K3S kubectl apply -n kube-system -f $MANIFEST_DIR/config-map.yml
  $K3S kubectl apply -n kube-system -f $MANIFEST_DIR/app-one.yml
  $K3S kubectl apply -n kube-system -f $MANIFEST_DIR/app-two.yml
  $K3S kubectl apply -n kube-system -f $MANIFEST_DIR/app-three.yml
  $K3S kubectl apply -n kube-system -f $MANIFEST_DIR/ingress.yml
else
  echo "⚠️ No YAML files found in $MANIFEST_DIR. Skipping kubectl apply."
fi

echo "✅ Script completed!"
