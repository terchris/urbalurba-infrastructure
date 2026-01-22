#!/bin/bash
# service-rabbitmq.sh - RabbitMQ service metadata
#
# RabbitMQ is a message broker for async communication.

# === Service Metadata (Required) ===
SCRIPT_ID="rabbitmq"
SCRIPT_NAME="RabbitMQ"
SCRIPT_DESCRIPTION="Message broker for async communication"
SCRIPT_CATEGORY="QUEUES"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="080-setup-rabbitmq.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n queues -l app=rabbitmq --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="60"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Reliable message broker supporting multiple messaging protocols"
SCRIPT_LOGO="rabbitmq-logo.webp"
SCRIPT_WEBSITE="https://www.rabbitmq.com"
