#!/bin/bash
# Enhanced debug-mongodb.sh - Script to collect debugging information for MongoDB

NAMESPACE="default"
OUTPUT_FILE="debug-mongodb.txt"
MONGO_POD=$(kubectl get pods -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}')

if [ -z "$MONGO_POD" ]; then
  echo "No MongoDB pod found in namespace $NAMESPACE." > "$OUTPUT_FILE"
  exit 1
fi

# Retrieve MongoDB credentials from the correct Kubernetes Secret
MONGO_USERNAME=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.MONGODB_ROOT_USER}' | base64 --decode)
MONGO_PASSWORD=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.MONGODB_ROOT_PASSWORD}' | base64 --decode)

if [ -z "$MONGO_PASSWORD" ]; then
  echo "Could not retrieve MongoDB root password from Kubernetes secret." >> "$OUTPUT_FILE"
  exit 1
fi

echo "Collecting MongoDB debugging information..."

{
  echo "=== MongoDB Debug Information ==="
  echo "Date: $(date)"
  echo "Kubernetes Context: $(kubectl config current-context)"
  echo ""

  echo "=== MongoDB Pods ==="
  kubectl get pods -n $NAMESPACE | grep mongodb
  echo ""

  echo "=== MongoDB Services ==="
  kubectl get svc -n $NAMESPACE | grep mongodb
  echo ""

  echo "=== MongoDB Endpoints ==="
  kubectl get endpoints -n $NAMESPACE | grep mongodb
  echo ""

  echo "=== MongoDB StatefulSets ==="
  kubectl get statefulset -n $NAMESPACE | grep mongodb
  echo ""

  echo "=== MongoDB Pod Logs (Last 100 lines) ==="
  kubectl logs $MONGO_POD -n $NAMESPACE --tail=100
  echo ""

  echo "=== MongoDB Admin Ping Check ==="
  kubectl exec $MONGO_POD -n $NAMESPACE -- mongosh --quiet --username $MONGO_USERNAME --password $MONGO_PASSWORD --authenticationDatabase admin --eval "db.adminCommand('ping')"
  echo ""

  echo "=== MongoDB Databases ==="
  kubectl exec $MONGO_POD -n $NAMESPACE -- mongosh --quiet --username $MONGO_USERNAME --password $MONGO_PASSWORD --authenticationDatabase admin --eval "show dbs"
  echo ""

  echo "=== Check Gravitee Database User Access ==="
  GIO_USER=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.GRAVITEE_MONGODB_DATABASE_USER}' | base64 --decode)
  GIO_PASS=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.GRAVITEE_MONGODB_DATABASE_PASSWORD}' | base64 --decode)
  GIO_DB=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.GRAVITEE_MONGODB_DATABASE_NAME}' | base64 --decode)
  
  echo "Testing connection with Gravitee credentials..."
  kubectl exec $MONGO_POD -n $NAMESPACE -- mongosh --quiet --username $GIO_USER --password $GIO_PASS --authenticationDatabase admin --eval "db.adminCommand('ping')"
  echo ""

  echo "=== MongoDB Events ==="
  kubectl get events -n $NAMESPACE | grep -i mongodb
  echo ""

} > "$OUTPUT_FILE"

echo "Enhanced debug information collected and saved to $OUTPUT_FILE"