#!/usr/bin/env bash
# Prepare an Ubuntu host for the DevSecOps lab. Safe to re-run.
#   - checks Docker + Compose v2
#   - sets the kernel parameters SonarQube (embedded Elasticsearch) needs
#   - creates .env with the docker.sock group id and a random database password
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Install Docker Engine: https://docs.docker.com/engine/install/ubuntu/" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: Docker Compose v2 plugin missing. Run: sudo apt-get install docker-compose-plugin" >&2
  exit 1
fi
if [ ! -S /var/run/docker.sock ]; then
  echo "ERROR: /var/run/docker.sock not found. Is the Docker daemon running?" >&2
  exit 1
fi

# 1. Kernel parameters for SonarQube
if [ "$(sysctl -n vm.max_map_count)" -lt 524288 ] || [ "$(sysctl -n fs.file-max)" -lt 131072 ]; then
  echo "[+] Setting vm.max_map_count=524288 and fs.file-max=131072 (persistent)"
  printf 'vm.max_map_count=524288\nfs.file-max=131072\n' | sudo tee /etc/sysctl.d/99-sonarqube.conf >/dev/null
  sudo sysctl -p /etc/sysctl.d/99-sonarqube.conf >/dev/null
else
  echo "[=] Kernel parameters already OK"
fi

# 2. .env
[ -f .env ] || cp .env.example .env

set_kv() { # set_kv KEY VALUE  (replace the line or append it)
  if grep -q "^$1=" .env; then
    sed -i "s|^$1=.*|$1=$2|" .env
  else
    echo "$1=$2" >> .env
  fi
}

set_kv DOCKER_GID "$(stat -c '%g' /var/run/docker.sock)"

if ! grep -q '^POSTGRES_PASSWORD=' .env || grep -q '^POSTGRES_PASSWORD=change-me$' .env; then
  set_kv POSTGRES_PASSWORD "$(openssl rand -hex 16)"
  echo "[+] Generated a random POSTGRES_PASSWORD in .env"
fi
chmod 600 .env

echo
echo "Host ready. Next:"
echo "  docker compose up -d --build"
echo "  ./scripts/verify-stack.sh"
