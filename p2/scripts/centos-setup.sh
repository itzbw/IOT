#!/bin/bash

set -e

detect_private_if() {
  local if_by_ip
  if_by_ip=$(ip -o -4 addr show | awk '/192\.168\.56\./ {print $2; exit}')
  if [ -n "$if_by_ip" ]; then
    echo "$if_by_ip"
    return
  fi
  if ip link show eth1 &>/dev/null; then
    echo eth1
    return
  fi
  if ip link show enp0s9 &>/dev/null; then
    echo enp0s9
    return
  fi
}

if command -v dnf &>/dev/null; then
  PKG_MGR=dnf
elif command -v yum &>/dev/null; then
  PKG_MGR=yum
else
  echo "ERROR: yum or dnf is required (CentOS/RHEL expected)."
  exit 1
fi

$PKG_MGR install -y curl

systemctl disable firewalld --now 2>/dev/null || true

PRIVATE_IF=$(detect_private_if)
if [ -z "$PRIVATE_IF" ]; then
  echo "ERROR: private network interface not found (expected eth1 or 192.168.56.x)."
  ip link
  exit 1
fi

if ! ip -4 addr show dev "$PRIVATE_IF" | grep -q "inet "; then
  echo "Bringing up $PRIVATE_IF..."
  ifup "$PRIVATE_IF" 2>/dev/null || ip link set "$PRIVATE_IF" up
fi

echo "Private network ready on $PRIVATE_IF:"
ip -4 addr show dev "$PRIVATE_IF"
