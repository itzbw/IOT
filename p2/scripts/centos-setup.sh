#!/bin/bash

set -e

# CentOS/RHEL prerequisites for K3s and Vagrant synced folders
if command -v dnf &>/dev/null; then
  PKG_MGR=dnf
elif command -v yum &>/dev/null; then
  PKG_MGR=yum
else
  echo "ERROR: yum or dnf is required (CentOS/RHEL expected)."
  exit 1
fi

$PKG_MGR install -y curl

# K3s needs API server (6443), kubelet, and flannel/VXLAN ports open
systemctl disable firewalld --now 2>/dev/null || true

# On CentOS/VirtualBox, Vagrant private_network attaches to eth1
if ! ip link show eth1 &>/dev/null; then
  echo "ERROR: eth1 not found. The private network must be configured on eth1."
  ip link
  exit 1
fi

if ! ip -4 addr show dev eth1 | grep -q "inet "; then
  echo "Bringing up eth1..."
  ifup eth1 2>/dev/null || ip link set eth1 up
fi

echo "Private network ready on eth1:"
ip -4 addr show dev eth1
