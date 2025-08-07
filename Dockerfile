# Build stage
FROM node:18-alpine AS builder
WORKDIR /app

COPY package*.json ./

RUN npm ci --prefer-offline --no-audit

COPY . .

RUN npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app .

EXPOSE 3000

# Commande pour démarrer le serveur au lancement du conteneur
CMD ["node", "app.js"]
