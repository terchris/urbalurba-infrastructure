#!/bin/bash
# debug-elasticsearch.sh - Script to collect debugging information for Elasticsearch

NAMESPACE="default"
OUTPUT_FILE="debug-elasticsearch.txt"

echo "Collecting Elasticsearch debugging information..."

# Start with timestamp and cluster info
{
  echo "=== Elasticsearch Debug Information ==="
  echo "Date: $(date)"
  echo "Kubernetes Context: $(kubectl config current-context)"
  echo ""

  echo "=== Elasticsearch Pods ==="
  kubectl get pods -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch Services ==="
  kubectl get svc -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch Endpoints ==="
  kubectl get endpoints -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch StatefulSets ==="
  kubectl get statefulset -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch ConfigMaps ==="
  kubectl get configmap -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch Secrets ==="
  kubectl get secrets -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch Persistent Volume Claims (PVCs) ==="
  kubectl get pvc -n $NAMESPACE | grep elasticsearch
  echo ""

  echo "=== Elasticsearch Pod Logs ==="
  ES_POD=$(kubectl get pods -n $NAMESPACE | grep elasticsearch-master-0 | awk '{print $1}')
  if [ -n "$ES_POD" ]; then
    kubectl logs $ES_POD -n $NAMESPACE
  else
    echo "No Elasticsearch pod found."
  fi
  echo ""

  echo "=== Elasticsearch Cluster Health ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_cluster/health?pretty
  echo ""

  echo "=== Elasticsearch Cluster Settings ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_cluster/settings?pretty
  echo ""

  echo "=== Elasticsearch Nodes Information ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_nodes?pretty
  echo ""

  echo "=== Elasticsearch Indices ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_cat/indices?v
  echo ""

  echo "=== Elasticsearch Shards ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_cat/shards?v
  echo ""

  echo "=== Elasticsearch Node Stats ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_nodes/stats?pretty
  echo ""

  echo "=== Elasticsearch Cluster Stats ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_cluster/stats?pretty
  echo ""

  echo "=== Elasticsearch Thread Pool Stats ==="
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s http://localhost:9200/_cat/thread_pool?v
  echo ""

  echo "=== Resource Utilization (CPU & Memory) ==="
  kubectl top pod $ES_POD -n $NAMESPACE
  echo ""

  echo "=== Persistent Volume Details ==="
  kubectl get pv | grep elasticsearch
  echo ""

  echo "=== Network Connectivity Test ==="
  echo "Checking if Elasticsearch is reachable inside the cluster..."
  kubectl exec $ES_POD -n $NAMESPACE -- curl -s -o /dev/null -w "%{http_code}" http://localhost:9200
  echo ""

  echo "=== Elasticsearch Events ==="
  kubectl get events -n $NAMESPACE | grep -i elasticsearch
  echo ""

} > "$OUTPUT_FILE"

echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now share this file to help with troubleshooting."
