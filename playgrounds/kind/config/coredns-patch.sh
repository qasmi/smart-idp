#!/bin/bash

set -e

echo "Patching CoreDNS config..."
kubectl -n kube-system get configmap coredns -o yaml | \
  sed 's|forward \. /etc/resolv.conf|forward . 8.8.8.8 1.1.1.1|' | \
  kubectl apply -f -

kubectl rollout restart deployment coredns -n kube-system

echo "Cluster is ready with patched CoreDNS"
