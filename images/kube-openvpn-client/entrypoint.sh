#!/bin/sh

echo "[INFO] Configuring & running dnsmasq in the background (yeah, eeeeerk)..."
for kubednsentry in $KUBE_DNS_MAPPING; do
  suffix="$(echo "$kubednsentry" | sed 's/=.\+$//')"
  ip="$(echo "$kubednsentry" | sed 's/^.\+=//')"
  echo "[INFO] Forwarding $suffix ending DNS queries to $ip"
  echo "server=/$suffix/$ip" >> /etc/dnsmasq.conf
done
dnsmasq -C /etc/dnsmasq.conf

echo "Executing OpenVPN client in the foreground..."
exec "$@"
