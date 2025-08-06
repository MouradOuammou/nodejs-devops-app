#!/bin/bash

# Build Docker image
echo "Building Docker image..."
docker build -t nodejs-devops-app:latest .

# Push to Docker Hub (optional)
# docker tag nodejs-devops-app:latest your-dockerhub-username/nodejs-devops-app:latest
# docker push your-dockerhub-username/nodejs-devops-app:latest

# Deploy with Helm
echo "Deploying with Helm..."
helm upgrade --install nodejs-devops-app ./helm/nodejs-devops-app \
  --namespace devops-demo \
  --create-namespace

echo "Deployment completed!"