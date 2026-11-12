#!/bin/bash
set -euo pipefail
dnf update -y
dnf install -y docker amazon-cloudwatch-agent
systemctl enable --now docker
usermod -aG docker ec2-user || true
mkdir -p /opt/care-guide
cat >/opt/care-guide/deploy.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail
NEW_IMAGE="$1"
CONTAINER="care-guide-api"
OLD_IMAGE="$(docker inspect --format='{{.Config.Image}}' "$CONTAINER" 2>/dev/null || true)"
docker pull "$NEW_IMAGE"
docker rm -f "${CONTAINER}-candidate" 2>/dev/null || true
docker run -d --name "${CONTAINER}-candidate" -p 8081:8000 \
  -e ENVIRONMENT=production -e APP_VERSION="${NEW_IMAGE##*:}" \
  --restart unless-stopped "$NEW_IMAGE"
for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8081/health >/dev/null; then
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker rm -f "${CONTAINER}-candidate"
    docker run -d --name "$CONTAINER" -p 8080:8000 --restart unless-stopped "$NEW_IMAGE"
    if curl -fsS http://127.0.0.1:8080/health >/dev/null; then exit 0; fi
    docker rm -f "$CONTAINER" || true
    if [ -n "$OLD_IMAGE" ]; then docker run -d --name "$CONTAINER" -p 8080:8000 --restart unless-stopped "$OLD_IMAGE"; fi
    exit 1
  fi
  sleep 3
done
docker rm -f "${CONTAINER}-candidate" || true
if [ -n "$OLD_IMAGE" ]; then
  docker run -d --name "$CONTAINER" -p 8080:8000 --restart unless-stopped "$OLD_IMAGE"
fi
exit 1
SCRIPT
chmod 0755 /opt/care-guide/deploy.sh
