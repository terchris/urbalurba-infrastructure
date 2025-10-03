# sovdev-logger - Multi-Language OTLP Integration

**Key Features**: Structured Logging • OpenTelemetry Integration • Multi-Language Support • Context Preservation • Exception Tracking • Batched Export • Console & OTLP Output

**File**: `doc/package-monitoring-sovdev-logger.md`
**Purpose**: Complete integration guide for sovdev-logger library across TypeScript, Python, C#, PHP, Go, and Rust
**Target Audience**: Application developers, backend engineers, integration teams
**Last Updated**: October 3, 2025

## 📋 Overview

**sovdev-logger** is a multi-language structured logging library that provides OpenTelemetry Protocol (OTLP) integration for the Urbalurba monitoring stack. It standardizes log output across different programming languages, ensuring consistent structured logging with automatic OTLP export to Loki via the OpenTelemetry Collector.

As the **application-side logging interface**, sovdev-logger enables:
- **Structured JSON Logging**: Consistent log format across all languages
- **Automatic OTLP Export**: Direct integration with OpenTelemetry Collector
- **Context Preservation**: Trace ID, span ID, correlation ID tracking
- **Dual Output**: Console logs (development) + OTLP export (production)
- **Exception Tracking**: Automatic error serialization with stack traces
- **Batched Performance**: Buffered log export for high-throughput applications

**Key Capabilities**:
- **System Identification**: `systemId` parameter for multi-tenant log routing
- **Function-Level Tracing**: `functionName` for pinpoint error location
- **Input/Response Capture**: `inputJSON` and `responseJSON` for complete context
- **Log Levels**: DEBUG, INFO, WARN, ERROR, FATAL with severity mapping
- **Auto-Flush**: Graceful shutdown ensures no log loss
- **Environment Configuration**: OTLP endpoint via environment variables

**Architecture Type**: Application-side logging library with OTLP exporter

## 🏗️ Architecture

### **Data Flow**
```
Application Code
         │
         │ sovdevLog(level, function, message, exception, input, response)
         ▼
┌──────────────────────────────────┐
│  sovdev-logger Library           │
│                                  │
│  1. Structure log entry (JSON)   │
│  2. Add context (traceId, etc.)  │
│  3. Set severity level           │
│  4. Batch for export             │
│                                  │
│  ┌────────────┐ ┌──────────────┐│
│  │  Console   │ │ OTLP Exporter││
│  │  Output    │ │  (batched)   ││
│  └────────────┘ └──────────────┘│
└──────────────────────────────────┘
         │                    │
         ▼                    ▼
  Developer Console    OTLP Collector
                            │
                            ▼
                          Loki
                            │
                            ▼
                       Grafana UI
```

### **Log Entry Structure**
```json
{
  "timestamp": "2025-10-03T10:30:15.234Z",
  "level": "ERROR",
  "systemId": "my-service-name",
  "functionName": "processOrder",
  "message": "Order processing failed",
  "traceId": "d04584f7-bf95-41e0-9e20-f8063b7658b6",
  "spanId": "abc123def456",
  "correlationId": "req-789012",
  "exception": {
    "type": "ValidationError",
    "message": "Invalid order quantity",
    "stack": "ValidationError: Invalid order quantity\n    at processOrder (orders.ts:45:12)..."
  },
  "inputJSON": {
    "orderId": "ORD-12345",
    "quantity": -5,
    "customerId": "CUST-67890"
  },
  "responseJSON": {
    "status": "failed",
    "errorCode": "INVALID_QUANTITY",
    "validationErrors": ["Quantity must be positive"]
  }
}
```

### **Integration with Monitoring Stack**
```
Application (sovdev-logger)
         │
         │ HTTP POST http://otel.localhost/v1/logs
         │ Header: Host: otel.localhost
         ▼
┌──────────────────────────────────┐
│  Traefik IngressRoute            │
│  (routes to OTLP Collector)      │
└──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  OTLP Collector                  │
│  - Resource enrichment           │
│  - Attribute transformation      │
│  - Batch processing              │
└──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  Loki (Log Storage)              │
│  - Indexed by service_name       │
│  - Queryable via LogQL           │
└──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  Grafana (Visualization)         │
│  - Dashboard queries             │
│  - Explore log streams           │
└──────────────────────────────────┘
```

## 🚀 Language-Specific Integration

### **TypeScript / JavaScript**

**Library Location**: `terchris/grafana1/sovdev-logger/typescript/`

**Installation** (from source):
```bash
cd terchris/grafana1/sovdev-logger/typescript
npm install
npm run build

# Use in your project
npm link  # From sovdev-logger directory
npm link sovdev-logger  # From your project directory
```

**Basic Usage**:
```typescript
import {
  initializeSovdevLogger,
  sovdevLog,
  flushSovdevLogs,
  SOVDEV_LOGLEVELS
} from 'sovdev-logger';

// 1. Initialize once at application startup
initializeSovdevLogger('my-service-name');

// 2. Basic logging
sovdevLog(
  SOVDEV_LOGLEVELS.INFO,
  'main',
  'Application started',
  null
);

// 3. Log with input and response context
const input = { userId: '12345', action: 'getData' };
const response = { status: 'success', data: ['item1', 'item2'] };

sovdevLog(
  SOVDEV_LOGLEVELS.INFO,
  'processRequest',
  'Request processed successfully',
  null,
  input,
  response
);

// 4. Log errors with exception
try {
  throw new Error('Something went wrong');
} catch (error) {
  sovdevLog(
    SOVDEV_LOGLEVELS.ERROR,
    'processOrder',
    'Order processing failed',
    error,
    { orderId: '12345' }
  );
}

// 5. CRITICAL: Flush before application exit
// Without flushing, batched logs still in buffer will be lost
await flushSovdevLogs();
```

**Environment Configuration**:
```bash
# Required
SYSTEM_ID=my-service-name                       # Your application identifier
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs  # OTLP endpoint
OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'     # Host header for Traefik routing

# Optional
LOG_TO_CONSOLE=true                             # Enable console output (default: true)
OTEL_LOG_LEVEL=debug                            # OpenTelemetry SDK debug logging
```

**Complete Example** (`examples/basic/simple-logging.ts`):
```typescript
import {
  initializeSovdevLogger,
  sovdevLog,
  flushSovdevLogs,
  SOVDEV_LOGLEVELS
} from 'sovdev-logger';

async function main() {
  // Initialize with system ID
  initializeSovdevLogger('basic-example');

  // Log at different levels
  sovdevLog(SOVDEV_LOGLEVELS.INFO, 'main', 'Application started', null);
  sovdevLog(SOVDEV_LOGLEVELS.DEBUG, 'main', 'Debug info', null, { debugData: 'context' });
  sovdevLog(SOVDEV_LOGLEVELS.WARN, 'main', 'Warning', null, { reason: 'demo' });

  // Log with input/response
  const input = { userId: '12345', action: 'getData' };
  const response = { status: 'success', data: ['item1', 'item2'] };
  sovdevLog(SOVDEV_LOGLEVELS.INFO, 'processRequest', 'Request processed', null, input, response);

  // Log error with exception
  try {
    throw new Error('Demo error');
  } catch (error) {
    sovdevLog(SOVDEV_LOGLEVELS.ERROR, 'main', 'Error occurred', error, { context: 'demo' });
  }

  sovdevLog(SOVDEV_LOGLEVELS.INFO, 'main', 'Application finished', null);

  // Flush before exit
  await flushSovdevLogs();
}

main().catch(console.error);
```

**Running the Example**:
```bash
cd terchris/grafana1/sovdev-logger/typescript/examples/basic

# Set environment variables
export SYSTEM_ID=sovdev-test-typescript
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
export OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'
export LOG_TO_CONSOLE=true

# Run
npx tsx simple-logging.ts
```

**Official TypeScript Documentation**: https://opentelemetry.io/docs/languages/js/

---

### **Python**

**Status**: Planned (not yet implemented)

**Planned API**:
```python
from sovdev_logger import initialize_sovdev_logger, sovdev_log, flush_sovdev_logs, SOVDEV_LOGLEVELS

# Initialize
initialize_sovdev_logger('my-service-name')

# Log
sovdev_log(
    SOVDEV_LOGLEVELS.INFO,
    'main',
    'Application started',
    None
)

# Log with context
sovdev_log(
    SOVDEV_LOGLEVELS.ERROR,
    'process_order',
    'Order failed',
    exception,
    input_json={'order_id': '12345'},
    response_json={'status': 'failed'}
)

# Flush before exit
flush_sovdev_logs()
```

**Environment Configuration** (same as TypeScript):
```bash
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'
```

**Official Python Documentation**: https://opentelemetry.io/docs/languages/python/

---

### **C# (.NET)**

**Status**: Planned (not yet implemented)

**Planned API**:
```csharp
using SovdevLogger;

// Initialize
SovdevLogger.Initialize("my-service-name");

// Log
SovdevLogger.Log(
    SovdevLogLevels.INFO,
    "Main",
    "Application started",
    null
);

// Log with context
SovdevLogger.Log(
    SovdevLogLevels.ERROR,
    "ProcessOrder",
    "Order failed",
    exception,
    inputJson: new { orderId = "12345" },
    responseJson: new { status = "failed" }
);

// Flush before exit
await SovdevLogger.FlushAsync();
```

**Environment Configuration** (same as TypeScript):
```bash
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

**Official C# Documentation**: https://opentelemetry.io/docs/languages/net/

---

### **PHP**

**Status**: Planned (not yet implemented)

**Planned API**:
```php
<?php
use SovdevLogger\Logger;
use SovdevLogger\LogLevels;

// Initialize
Logger::initialize('my-service-name');

// Log
Logger::log(
    LogLevels::INFO,
    'main',
    'Application started',
    null
);

// Log with context
Logger::log(
    LogLevels::ERROR,
    'processOrder',
    'Order failed',
    $exception,
    ['orderId' => '12345'],
    ['status' => 'failed']
);

// Flush before exit
Logger::flush();
?>
```

**Environment Configuration** (same as TypeScript):
```bash
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'
```

**Official PHP Documentation**: https://opentelemetry.io/docs/languages/php/

---

### **Go**

**Status**: Planned (not yet implemented)

**Planned API**:
```go
package main

import "github.com/sovdev/sovdev-logger-go"

func main() {
    // Initialize
    sovdevlogger.Initialize("my-service-name")

    // Log
    sovdevlogger.Log(
        sovdevlogger.INFO,
        "main",
        "Application started",
        nil,
        nil,
        nil,
    )

    // Log with context
    sovdevlogger.Log(
        sovdevlogger.ERROR,
        "processOrder",
        "Order failed",
        err,
        map[string]interface{}{"orderId": "12345"},
        map[string]interface{}{"status": "failed"},
    )

    // Flush before exit
    sovdevlogger.Flush()
}
```

**Environment Configuration** (same as TypeScript):
```bash
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'
```

**Official Go Documentation**: https://opentelemetry.io/docs/languages/go/

---

### **Rust**

**Status**: Planned (not yet implemented)

**Planned API**:
```rust
use sovdev_logger::{initialize, log, flush, LogLevel};
use std::collections::HashMap;

fn main() {
    // Initialize
    initialize("my-service-name");

    // Log
    log(
        LogLevel::Info,
        "main",
        "Application started",
        None,
        None,
        None,
    );

    // Log with context
    let mut input = HashMap::new();
    input.insert("orderId", "12345");

    let mut response = HashMap::new();
    response.insert("status", "failed");

    log(
        LogLevel::Error,
        "process_order",
        "Order failed",
        Some(&error),
        Some(&input),
        Some(&response),
    );

    // Flush before exit
    flush();
}
```

**Environment Configuration** (same as TypeScript):
```bash
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'
```

**Official Rust Documentation**: https://opentelemetry.io/docs/languages/rust/

---

## ⚙️ Configuration

### **Environment Variables**

**Required**:
```bash
SYSTEM_ID=<your-service-name>                   # Identifies your application in logs
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=<otlp-url>     # OTLP Collector endpoint
OTEL_EXPORTER_OTLP_HEADERS='{"Host":"<host>"}'  # Traefik routing header
```

**Optional**:
```bash
LOG_TO_CONSOLE=true                             # Enable console output (default: true)
OTEL_LOG_LEVEL=debug                            # OpenTelemetry SDK debug logging
```

### **Local Development Configuration**

**For Mac host (outside cluster)**:
```bash
export SYSTEM_ID=my-service-dev
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
export OTEL_EXPORTER_OTLP_HEADERS='{"Host":"otel.localhost"}'
export LOG_TO_CONSOLE=true
```

**For Kubernetes pod (inside cluster)**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: my-app:latest
      env:
        - name: SYSTEM_ID
          value: "my-service-prod"
        - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
          value: "http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/logs"
        - name: LOG_TO_CONSOLE
          value: "false"
```

### **Production Configuration**

**Docker Compose**:
```yaml
services:
  my-app:
    image: my-app:latest
    environment:
      SYSTEM_ID: my-service-prod
      OTEL_EXPORTER_OTLP_LOGS_ENDPOINT: http://otel-collector:4318/v1/logs
      LOG_TO_CONSOLE: "false"
```

### **Log Levels**

| Level | Severity | Use Case |
|-------|----------|----------|
| **DEBUG** | Detailed | Development debugging, verbose tracing |
| **INFO** | Informational | Normal operations, business events |
| **WARN** | Warning | Recoverable issues, potential problems |
| **ERROR** | Error | Application errors, failed operations |
| **FATAL** | Fatal | Critical failures requiring immediate attention |

## 🔍 Verification & Debugging

### **Test OTLP Endpoint Connectivity**

```bash
# From Mac host
curl -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test"}}]},"scopeLogs":[{"logRecords":[{"body":{"stringValue":"test log"}}]}]}]}'

# Expected: No error (200 or 204 response)
```

### **Query Logs in Loki**

```bash
# Check if logs from your service are indexed
kubectl exec -n monitoring loki-0 -c loki -- \
  wget -q -O - 'http://localhost:3100/loki/api/v1/label/service_name/values'

# Should include your systemId (e.g., "my-service-name")
```

### **View Logs in Grafana**

1. Open `http://grafana.localhost`
2. Login: `admin` / `SecretPassword1`
3. Navigate to **Explore** → Select **Loki** datasource
4. Query:
   ```logql
   {service_name="my-service-name"}
   ```
5. Verify logs appear with structured fields

### **Troubleshooting No Logs Appearing**

**1. Check application console output**:
```bash
# If LOG_TO_CONSOLE=true, you should see JSON logs in stdout
# Example output:
{
  "timestamp": "2025-10-03T10:30:15.234Z",
  "level": "INFO",
  "systemId": "my-service-name",
  "functionName": "main",
  "message": "Application started"
}
```

**2. Verify OTLP Collector is receiving logs**:
```bash
# Check OTLP Collector logs for your service
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep "my-service-name"
```

**3. Check Loki ingestion**:
```bash
# Query Loki for recent logs
kubectl exec -n monitoring loki-0 -c loki -- \
  wget -q -O - 'http://localhost:3100/loki/api/v1/query_range?query={service_name="my-service-name"}&limit=10'
```

**4. Common issues**:
- **No logs in OTLP Collector**: Check `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` and `OTEL_EXPORTER_OTLP_HEADERS`
- **Logs not flushed**: Ensure `flushSovdevLogs()` is called before application exit
- **Wrong label in Loki**: Query by `service_name` (not `systemId` - OTLP maps `systemId` → `service.name` → `service_name`)
- **Traefik routing failure**: Verify `Host: otel.localhost` header is set correctly

## 🛠️ Best Practices

### **1. Always Initialize Once**
```typescript
// ✅ CORRECT: Initialize at application startup
initializeSovdevLogger('my-service');

// ❌ WRONG: Do not initialize inside functions
function someFunction() {
  initializeSovdevLogger('my-service');  // Bad: reinitializes logger
}
```

### **2. Always Flush Before Exit**
```typescript
// ✅ CORRECT: Flush ensures batched logs are sent
async function main() {
  initializeSovdevLogger('my-service');
  sovdevLog(SOVDEV_LOGLEVELS.INFO, 'main', 'Done', null);
  await flushSovdevLogs();  // Critical: ensures logs reach OTLP Collector
}

// ❌ WRONG: Without flush, last logs may be lost
async function main() {
  initializeSovdevLogger('my-service');
  sovdevLog(SOVDEV_LOGLEVELS.INFO, 'main', 'Done', null);
  // Missing flush: logs still in buffer will be lost
}
```

### **3. Use Meaningful Function Names**
```typescript
// ✅ CORRECT: Function names help locate errors
sovdevLog(SOVDEV_LOGLEVELS.ERROR, 'processOrder', 'Validation failed', error);
// Grafana query: {service_name="my-service"} | json | functionName="processOrder"

// ❌ WRONG: Generic names make debugging harder
sovdevLog(SOVDEV_LOGLEVELS.ERROR, 'main', 'Error', error);
```

### **4. Include Context with Input/Response**
```typescript
// ✅ CORRECT: Full context for debugging
sovdevLog(
  SOVDEV_LOGLEVELS.ERROR,
  'processPayment',
  'Payment failed',
  error,
  { orderId: '12345', amount: 99.99, currency: 'USD' },  // input
  { status: 'failed', errorCode: 'INSUFFICIENT_FUNDS' }  // response
);

// ❌ WRONG: No context makes troubleshooting difficult
sovdevLog(SOVDEV_LOGLEVELS.ERROR, 'processPayment', 'Payment failed', error);
```

### **5. Use Appropriate Log Levels**
```typescript
// ✅ CORRECT: Level matches severity
sovdevLog(SOVDEV_LOGLEVELS.INFO, 'processOrder', 'Order created', null);
sovdevLog(SOVDEV_LOGLEVELS.WARN, 'processOrder', 'Slow response detected', null);
sovdevLog(SOVDEV_LOGLEVELS.ERROR, 'processOrder', 'Order failed', error);

// ❌ WRONG: Using INFO for errors hides critical issues
sovdevLog(SOVDEV_LOGLEVELS.INFO, 'processOrder', 'Order failed', error);
```

### **6. Avoid Logging Sensitive Data**
```typescript
// ✅ CORRECT: Redact sensitive fields
sovdevLog(
  SOVDEV_LOGLEVELS.INFO,
  'login',
  'User login',
  null,
  { username: user.email, password: '[REDACTED]' }
);

// ❌ WRONG: Logging passwords, tokens, API keys
sovdevLog(
  SOVDEV_LOGLEVELS.INFO,
  'login',
  'User login',
  null,
  { username: user.email, password: user.password }  // Security risk
);
```

## 🚀 Use Cases

### **1. API Request Logging**
```typescript
async function handleRequest(req, res) {
  const input = { method: req.method, url: req.url, userId: req.user?.id };

  try {
    const result = await processRequest(req);
    sovdevLog(
      SOVDEV_LOGLEVELS.INFO,
      'handleRequest',
      'Request processed',
      null,
      input,
      { status: 200, data: result }
    );
    res.json(result);
  } catch (error) {
    sovdevLog(
      SOVDEV_LOGLEVELS.ERROR,
      'handleRequest',
      'Request failed',
      error,
      input,
      { status: 500, error: error.message }
    );
    res.status(500).json({ error: 'Internal server error' });
  }
}
```

### **2. Background Job Logging**
```typescript
async function processJob(jobId) {
  sovdevLog(SOVDEV_LOGLEVELS.INFO, 'processJob', `Job ${jobId} started`, null);

  try {
    const input = await fetchJobData(jobId);
    const result = await executeJob(input);

    sovdevLog(
      SOVDEV_LOGLEVELS.INFO,
      'processJob',
      `Job ${jobId} completed`,
      null,
      { jobId, input },
      { status: 'success', result }
    );
  } catch (error) {
    sovdevLog(
      SOVDEV_LOGLEVELS.ERROR,
      'processJob',
      `Job ${jobId} failed`,
      error,
      { jobId }
    );
  } finally {
    await flushSovdevLogs();  // Flush at job completion
  }
}
```

### **3. Database Operation Logging**
```typescript
async function queryDatabase(query, params) {
  const startTime = Date.now();

  try {
    const result = await db.query(query, params);
    const duration = Date.now() - startTime;

    sovdevLog(
      SOVDEV_LOGLEVELS.INFO,
      'queryDatabase',
      'Query executed',
      null,
      { query, params, duration },
      { rowCount: result.rows.length }
    );

    return result;
  } catch (error) {
    sovdevLog(
      SOVDEV_LOGLEVELS.ERROR,
      'queryDatabase',
      'Query failed',
      error,
      { query, params }
    );
    throw error;
  }
}
```

---

**💡 Key Insight**: sovdev-logger bridges the gap between application code and the observability stack by providing a simple, consistent logging interface that automatically exports structured logs to OpenTelemetry. By standardizing log format across multiple languages, it enables cross-service correlation and unified querying in Grafana, regardless of the programming language used to build each service.

## 🔗 Related Documentation

**Monitoring Stack**:
- **[Monitoring Overview](./package-monitoring-readme.md)** - Complete observability stack
- **[OTLP Collector](./package-monitoring-otel.md)** - Telemetry ingestion gateway
- **[Loki Logs](./package-monitoring-loki.md)** - Log storage backend
- **[Grafana Visualization](./package-monitoring-grafana.md)** - Query and visualization

**Configuration & Rules**:
- **[Traefik IngressRoute](./rules-ingress-traefik.md)** - External access patterns
- **[Development Workflow](./rules-development-workflow.md)** - Application integration

**External Resources**:
- **OpenTelemetry Protocol Specification**: https://opentelemetry.io/docs/specs/otlp/
- **OpenTelemetry Logs API**: https://opentelemetry.io/docs/specs/otel/logs/
- **Grafana LogQL**: https://grafana.com/docs/loki/latest/query/
