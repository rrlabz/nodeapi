#!/bin/sh

set -e

HEALTH_URL="http://localhost:5000/api/health"
CONTAINER_NAME="app-api-1"

echo "Waiting for app to be ready..."
sleep 10

echo "Running health check..."

i=1
while [ $i -le 10 ]
do
  if curl -f $HEALTH_URL > /dev/null 2>&1
  then
    echo "✅ App is healthy"
    exit 0
  fi
  echo "⏳ Retry $i..."
  i=$((i+1))
  sleep 5
done
echo "❌ Health check failed"
echo "---- Container Logs ----"
docker logs $CONTAINER_NAME --tail 50 || true