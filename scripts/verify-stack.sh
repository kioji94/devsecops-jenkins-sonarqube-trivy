#!/usr/bin/env bash
# Health check for the whole lab. Exit code 0 only if every check passes.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi
JENKINS_PORT="${JENKINS_PORT:-8080}"
SONARQUBE_PORT="${SONARQUBE_PORT:-9000}"

pass=0
fail=0
check() { # check "label" command...
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '  [ OK ] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '  [FAIL] %s\n' "$label"
    fail=$((fail + 1))
  fi
}

running() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]; }
sonar_up() { curl -fsS "http://localhost:${SONARQUBE_PORT}/api/system/status" | grep -q '"status":"UP"'; }

echo "== Containers"
for c in sonarqube-db sonarqube jenkins; do
  check "$c is running" running "$c"
done

echo "== Endpoints"
check "SonarQube API reports status UP (:${SONARQUBE_PORT})" sonar_up
check "Jenkins login page reachable (:${JENKINS_PORT})" curl -fsS -o /dev/null "http://localhost:${JENKINS_PORT}/login"

echo "== Tooling inside the Jenkins container"
check "docker CLI reaches the host daemon" docker exec jenkins docker version --format '{{.Server.Version}}'
check "trivy installed" docker exec jenkins trivy --version
check "sonar-scanner installed" docker exec jenkins sonar-scanner --version
check "python3 venv available" docker exec jenkins python3 -m venv --help

echo "== Versions"
docker exec jenkins sh -c 'docker --version; trivy --version | head -n 1; sonar-scanner --version 2>&1 | grep -i "scanner cli"; python3 --version' 2>/dev/null || true

echo
echo "Result: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
