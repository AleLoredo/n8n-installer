#!/usr/bin/env bash
set -euo pipefail

echo "== Instalador de n8n =="

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker no está instalado."
  echo "Instalalo desde: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose (plugin) no encontrado."
  echo "Verificá tu instalación de Docker: https://docs.docker.com/compose/install/"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker está instalado pero no accesible (¿está corriendo el daemon? ¿tenés permisos?)."
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
  RANDOM_PASS=$(openssl rand -base64 12)
  # Portable entre GNU sed (Linux) y BSD sed (macOS)
  if sed --version >/dev/null 2>&1; then
    sed -i "s/N8N_PASSWORD=.*/N8N_PASSWORD=${RANDOM_PASS}/" .env
  else
    sed -i '' "s/N8N_PASSWORD=.*/N8N_PASSWORD=${RANDOM_PASS}/" .env
  fi
  echo "Se generó .env con usuario 'admin' y password: ${RANDOM_PASS}"
fi

echo "Levantando contenedor..."
docker compose up -d

echo "Esperando a que n8n esté disponible..."
until curl -sf http://localhost:5678/healthz >/dev/null 2>&1; do
  sleep 2
done

echo "Importando workflows de ejemplo..."
for f in workflows/*.json; do
  docker compose exec -T n8n n8n import:workflow --input="/workflows/$(basename "$f")" || true
done

echo ""
echo "n8n corriendo en http://localhost:5678"
echo "Usuario: admin"