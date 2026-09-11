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
  echo "Creando archivo .env a partir de .env.example..."
  cp .env.example .env
fi

# Cargar variables de entorno desde .env
set -a
source .env
set +a

# Si la contraseña no está definida en .env, generar una contraseña segura
if [ -z "${N8N_OWNER_PASSWORD:-}" ]; then
  N8N_OWNER_PASSWORD=$(openssl rand -hex 12)
  # Actualizar N8N_OWNER_PASSWORD en .env (compatible con GNU sed y BSD sed)
  if sed --version >/dev/null 2>&1; then
    sed -i "s/^N8N_OWNER_PASSWORD=.*/N8N_OWNER_PASSWORD=${N8N_OWNER_PASSWORD}/" .env
  else
    sed -i '' "s/^N8N_OWNER_PASSWORD=.*/N8N_OWNER_PASSWORD=${N8N_OWNER_PASSWORD}/" .env
  fi
fi

echo "Levantando contenedor..."
docker compose up -d

PORT="${N8N_PORT:-5678}"
echo "Esperando a que n8n esté disponible en http://localhost:${PORT}..."
until curl -sf "http://localhost:${PORT}/healthz" >/dev/null 2>&1; do
  sleep 2
done

echo "Configurando cuenta del propietario de n8n..."
EMAIL="${N8N_OWNER_EMAIL:-admin@example.com}"
FIRST_NAME="${N8N_OWNER_FIRST_NAME:-Admin}"
LAST_NAME="${N8N_OWNER_LAST_NAME:-User}"

docker compose exec -T n8n n8n user-management:create-owner \
  --email "$EMAIL" \
  --password "$N8N_OWNER_PASSWORD" \
  --firstName "$FIRST_NAME" \
  --lastName "$LAST_NAME" >/dev/null 2>&1 || echo "Nota: La cuenta de propietario ya existe o ya fue configurada previamente."

echo "Importando workflows desde carpeta workflows/..."
for f in workflows/*.json; do
  [ -f "$f" ] || continue
  filename=$(basename "$f")
  echo "  -> Importando ${filename}..."
  if ! docker compose exec -T n8n n8n import:workflow --input="/workflows/${filename}" >/dev/null 2>&1; then
    docker compose exec -T n8n n8n import:workflow --separate < "$f" >/dev/null 2>&1 || true
  fi
done


echo ""
echo "=================================================="
echo "  n8n corriendo exitosamente                    "
echo "  URL: ${N8N_PROTOCOL:-http}://${N8N_HOST:-localhost}:${PORT}"
echo "  Email: ${EMAIL}"
echo "  Password: ${N8N_OWNER_PASSWORD}"
echo "=================================================="