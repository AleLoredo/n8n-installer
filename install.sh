#!/usr/bin/env bash
# Configuración de manejo de errores:
# -e: finaliza el script inmediatamente ante cualquier fallo.
# -u: trata variables no definidas como error.
# -o pipefail: retorna el código de falla si falla alguna parte de una tubería (pipe).
set -euo pipefail

echo "== Instalador de n8n =="

# -----------------------------------------------------------------------------
# 1. VERIFICACIÓN DE PRERREQUISITOS DEL SISTEMA
# -----------------------------------------------------------------------------

# Verificar que el comando 'docker' esté instalado y disponible en PATH
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker no está instalado."
  echo "Instalalo desde: https://docs.docker.com/get-docker/"
  exit 1
fi

# Verificar que el plugin 'docker compose' esté disponible
if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose (plugin) no encontrado."
  echo "Verificá tu instalación de Docker: https://docs.docker.com/compose/install/"
  exit 1
fi

# Verificar que el daemon de Docker esté iniciado y el usuario tenga permisos de acceso
if ! docker info >/dev/null 2>&1; then
  echo "Docker está instalado pero no accesible (¿está corriendo el daemon? ¿tenés permisos?)."
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. GESTIÓN DEL ARCHIVO DE CONFIGURACIÓN (.env)
# -----------------------------------------------------------------------------

# Si no existe el archivo .env local, copiar la plantilla base (.env.example)
if [ ! -f .env ]; then
  echo "Creando archivo .env a partir de .env.example..."
  cp .env.example .env
fi

# Cargar automáticamente todas las variables definidas en .env al entorno de ejecución del script
set -a
source .env
set +a

# -----------------------------------------------------------------------------
# 3. GESTIÓN Y VALIDACIÓN DE LA CONTRASEÑA DEL PROPIETARIO (OWNER)
# -----------------------------------------------------------------------------
# n8n exige que la contraseña del propietario contenga al menos 1 letra mayúscula.
# Si N8N_OWNER_PASSWORD está vacía o no incluye letras mayúsculas, se genera una contraseña válida
# con prefijo "N8n_" y se actualiza/guarda de forma permanente en el archivo .env.
if [ -z "${N8N_OWNER_PASSWORD:-}" ] || ! [[ "$N8N_OWNER_PASSWORD" =~ [A-Z] ]]; then
  N8N_OWNER_PASSWORD="N8n_$(openssl rand -hex 8)"
  if grep -q "^N8N_OWNER_PASSWORD=" .env 2>/dev/null; then
    # Reemplazo compatible tanto con Linux (GNU sed) como con macOS (BSD sed)
    if sed --version >/dev/null 2>&1; then
      sed -i "s/^N8N_OWNER_PASSWORD=.*/N8N_OWNER_PASSWORD=${N8N_OWNER_PASSWORD}/" .env
    else
      sed -i '' "s/^N8N_OWNER_PASSWORD=.*/N8N_OWNER_PASSWORD=${N8N_OWNER_PASSWORD}/" .env
    fi
  else
    echo "N8N_OWNER_PASSWORD=${N8N_OWNER_PASSWORD}" >> .env
  fi
fi

# -----------------------------------------------------------------------------
# 4. DESPLIEGUE DE CONTENEDORES CON DOCKER COMPOSE
# -----------------------------------------------------------------------------
echo "Levantando contenedor..."
docker compose up -d

# -----------------------------------------------------------------------------
# 5. ESPERA HASTA QUE N8N ESTÉ DISPONIBLE (HEALTHCHECK)
# -----------------------------------------------------------------------------
PORT="${N8N_PORT:-5678}"
echo "Esperando a que n8n esté disponible en http://localhost:${PORT}..."
until curl -sf "http://localhost:${PORT}/healthz" >/dev/null 2>&1; do
  sleep 2
done

# -----------------------------------------------------------------------------
# 6. CONFIGURACIÓN AUTOMÁTICA DE LA CUENTA DEL PROPIETARIO (OWNER SETUP)
# -----------------------------------------------------------------------------
# En n8n v1+, la creación de la primera cuenta de administrador se realiza mediante la API REST (/rest/owner/setup).
# Si la cuenta ya fue creada en ejecuciones anteriores, n8n responderá un error que es silenciado amigablemente.
echo "Configurando cuenta del propietario de n8n..."
EMAIL="${N8N_OWNER_EMAIL:-admin@example.com}"
FIRST_NAME="${N8N_OWNER_FIRST_NAME:-Admin}"
LAST_NAME="${N8N_OWNER_LAST_NAME:-User}"

curl -s -f -X POST "http://localhost:${PORT}/rest/owner/setup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${N8N_OWNER_PASSWORD}\",\"firstName\":\"${FIRST_NAME}\",\"lastName\":\"${LAST_NAME}\"}" >/dev/null 2>&1 || echo "Nota: La cuenta de propietario ya existe o ya fue configurada previamente."

# -----------------------------------------------------------------------------
# 7. IMPORTACIÓN AUTOMÁTICA DE WORKFLOWS DE EJEMPLO
# -----------------------------------------------------------------------------
# Recorre todos los archivos .json presentes en la carpeta 'workflows/'.
# Intenta importarlos usando la ruta montada del volumen en el contenedor (/workflows/).
# Si falla el archivo montado, utiliza la entrada estándar (stdin) como alternativa.
echo "Importando workflows desde carpeta workflows/..."
for f in workflows/*.json; do
  [ -f "$f" ] || continue
  filename=$(basename "$f")
  echo "  -> Importando ${filename}..."
  if ! docker compose exec -T n8n n8n import:workflow --input="/workflows/${filename}" >/dev/null 2>&1; then
    docker compose exec -T n8n n8n import:workflow --separate < "$f" >/dev/null 2>&1 || true
  fi
done

# -----------------------------------------------------------------------------
# 8. RESUMEN Y DATOS DE ACCESO
# -----------------------------------------------------------------------------
echo ""
echo "=================================================="
echo "  n8n corriendo exitosamente                    "
echo "  URL: ${N8N_PROTOCOL:-http}://${N8N_HOST:-localhost}:${PORT}"
echo "  Email: ${EMAIL}"
echo "  Password: ${N8N_OWNER_PASSWORD}"
echo "=================================================="