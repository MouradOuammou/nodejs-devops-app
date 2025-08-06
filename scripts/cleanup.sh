#!/bin/bash

# Delete Helm release
echo "Deleting Helm release..."
helm uninstall nodejs-devops-app --namespace devops-demo

# Delete namespace
echo "Deleting namespace..."
kubectl delete namespace devops-demo

# Remove Docker images
echo "Removing Docker images..."
docker rmi nodejs-devops-app:latest

echo "Cleanup completed!"