# n8n-installer

Instalador automatizado de [n8n](https://n8n.io/) mediante Docker Compose, con configuración por defecto y un set de workflows de ejemplo listos para importar.

## ¿Qué hace este repositorio?

- Levanta una instancia de n8n usando Docker Compose
- Genera credenciales de acceso automáticamente
- Persiste los datos en un volumen Docker
- Importa automáticamente workflows de ejemplo al primer arranque

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) instalado y corriendo
- Docker Compose (incluido en instalaciones recientes de Docker Desktop y Docker Engine)

## Instalación

```bash
git clone https://github.com/tu-usuario/n8n-installer.git
cd n8n-installer
./install.sh
```

El script:
1. Verifica que Docker esté disponible y corriendo
2. Genera un archivo `.env` con credenciales aleatorias (si no existe uno)
3. Levanta n8n vía Docker Compose
4. Espera a que el servicio esté disponible
5. Importa los workflows de ejemplo incluidos en `workflows/`

Al finalizar, accedé a n8n en **http://localhost:5678** con el usuario y contraseña mostrados en la terminal (también quedan guardados en `.env`).

## Workflows incluidos

| Archivo | Descripción |
|---|---|
| `ejemplo-webhook.json` | Recibe una petición HTTP entrante y responde con un JSON |
| `ejemplo-cron.json` | Se ejecuta en un intervalo definido (schedule trigger) |
| `ejemplo-http-request.json` | Consulta una API pública y procesa la respuesta |

Podés agregar los tuyos simplemente copiando el `.json` exportado a la carpeta `workflows/` antes de correr `install.sh`, o importándolo manualmente después desde la UI de n8n.

## Configuración

Las variables se definen en `.env` (ver `.env.example`):

| Variable | Descripción | Default |
|---|---|---|
| `N8N_USER` | Usuario de acceso | `admin` |
| `N8N_PASSWORD` | Contraseña de acceso | generada automáticamente |
| `N8N_HOST` | Host donde corre n8n | `localhost` |
| `N8N_PROTOCOL` | Protocolo (`http`/`https`) | `http` |
| `TZ` | Zona horaria | `America/Argentina/Buenos_Aires` |

## Comandos útiles

```bash
docker compose logs -f n8n   # ver logs en tiempo real
docker compose down          # detener
docker compose up -d         # reiniciar
docker compose down -v       # detener y borrar todos los datos (incluye credenciales guardadas en n8n)
```

## Seguridad

- El script genera una contraseña aleatoria en cada instalación nueva; no uses el archivo `.env.example` en producción.
- Si exponés esta instancia fuera de tu red local, configurá `N8N_PROTOCOL=https` detrás de un reverse proxy (Nginx, Caddy, Traefik) con certificado TLS.
- El archivo `.env` está en `.gitignore` — nunca lo subas al repositorio.

## Licencia

MIT