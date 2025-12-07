# Feature Request: Web-Based UI for DevContainer Additions System

## Background

The devcontainer-toolbox project has a terminal-based menu system using `dialog` that allows developers to interactively install tools, configure services, and manage their development environment. The system uses **self-discovering scripts** with embedded metadata.

### Current Architecture

Scripts in `.devcontainer/additions/` are discovered by filename pattern and contain metadata:

```bash
SCRIPT_ID="dev-golang"
SCRIPT_NAME="Go Runtime & Development"
SCRIPT_DESCRIPTION="Install Go runtime"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="command -v go"

SCRIPT_COMMANDS=(
  "Action||Install with default version||false|"
  "Action|--version|Install specific version||true|Enter version"
  "Action|--uninstall|Remove installation||false|"
)
```

The terminal menu (`dev-setup.sh`) uses `component-scanner.sh` to discover scripts, parse metadata, and present interactive menus via `dialog`.

### Documentation Reference

Full architecture documentation: https://github.com/terchris/devcontainer-toolbox/blob/main/.devcontainer/docs/additions-system-architecture.md

## Goal

Create a **web-based UI** that provides the same functionality as the terminal menu, reusing the same scripts and metadata system. This gives developers two ways to manage their environment:

1. **Terminal menu** (dialog) - for SSH/direct access
2. **Web interface** (browser) - for visual management

## Requirements

### Must Have

- **Lightweight** - No npm install, no pip install, use only built-in Node.js or Python modules
- **Single-file server** - Minimal footprint (~100 lines)
- **Reuse existing scripts** - Call the same `install-*.sh`, `config-*.sh`, `service-*.sh` scripts
- **Reuse metadata** - Parse the same `SCRIPT_*` variables
- **Live output streaming** - Show script output in real-time (use Server-Sent Events)
- **Status indicators** - Show checkmark/X based on `SCRIPT_CHECK_COMMAND`

### Nice to Have

- Dark theme (developer-friendly)
- Mobile responsive
- Websocket for bidirectional communication

## Proposed Architecture

```
+-------------------------------------------------------------+
|                    User Interfaces                           |
+------------------------+------------------------------------+
|   Terminal Menu        |         Web Interface              |
|   (dialog-based)       |     (browser-based)                |
|   dev-setup.sh         |     web-manager.js                 |
+-----------+------------+------------------+-----------------+
            |                               |
            v                               v
+-------------------------------------------------------------+
|              Shared Script Discovery Layer                   |
|  component-scanner.sh                                        |
|  - Existing mode: text output for dialog                     |
|  - New mode: --json output for web API                       |
+-----------------------------+-------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|              Additions Scripts (unchanged)                   |
|  install-*.sh, config-*.sh, service-*.sh, cmd-*.sh          |
|  Same metadata, same commands, same behavior                 |
+-------------------------------------------------------------+
```

## File Structure

```
.devcontainer/
├── additions/              # Existing - unchanged
│   ├── install-*.sh
│   ├── config-*.sh
│   ├── service-*.sh
│   └── cmd-*.sh
├── manage/                 # Existing directory
│   ├── component-scanner.sh  # MODIFY: add --json output mode
│   ├── dev-setup.sh          # Existing terminal menu
│   ├── web-manager.js        # NEW: single-file web server
│   └── web-ui.html           # NEW: single-file web interface
└── docs/
    └── web-ui-architecture.md  # NEW: documentation
```

## Technical Implementation

### 1. Enhance component-scanner.sh

Add `--json` flag to output discovered scripts as JSON:

```bash
# New output mode
if [[ "$1" == "--json" ]]; then
  echo '['
  # For each script, output JSON object with:
  # { "id": "...", "name": "...", "description": "...",
  #   "category": "...", "status": "installed|not_installed",
  #   "commands": [...] }
  echo ']'
fi
```

### 2. Web Server (Node.js, no dependencies)

```javascript
// web-manager.js - uses only built-in modules
const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');

const PORT = process.env.WEB_MANAGER_PORT || 3000;
const ADDITIONS_DIR = '/workspaces/.devcontainer/additions';
const MANAGE_DIR = '/workspaces/.devcontainer/manage';

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  // Serve UI
  if (url.pathname === '/') {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.end(fs.readFileSync(`${MANAGE_DIR}/web-ui.html`));
    return;
  }

  // API: List all services with status
  if (url.pathname === '/api/services') {
    const proc = spawn(`${MANAGE_DIR}/component-scanner.sh`, ['--json']);
    let output = '';
    proc.stdout.on('data', d => output += d);
    proc.on('close', () => {
      res.writeHead(200, {'Content-Type': 'application/json'});
      res.end(output);
    });
    return;
  }

  // API: Run script with streaming output (SSE)
  if (url.pathname.startsWith('/api/run/')) {
    const scriptPath = decodeURIComponent(url.pathname.replace('/api/run/', ''));
    const args = url.searchParams.get('args')?.split(' ') || [];

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    });

    const proc = spawn(scriptPath, args, { cwd: ADDITIONS_DIR });
    proc.stdout.on('data', d => res.write(`data: ${d.toString()}\n\n`));
    proc.stderr.on('data', d => res.write(`data: ${d.toString()}\n\n`));
    proc.on('close', code => {
      res.write(`data: [EXIT:${code}]\n\n`);
      res.end();
    });
    return;
  }

  // API: Check single service status
  if (url.pathname.startsWith('/api/status/')) {
    const scriptId = url.pathname.replace('/api/status/', '');
    // Run SCRIPT_CHECK_COMMAND and return result
    // ...
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`DevContainer Manager: http://localhost:${PORT}`);
});
```

### 3. Web UI (Single HTML file)

```html
<!DOCTYPE html>
<html>
<head>
  <title>DevContainer Manager</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://unpkg.com/htmx.org@1.9.10"></script>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', system-ui, sans-serif;
      background: #0d1117; color: #e6edf3;
      margin: 0; padding: 20px;
    }
    h1 { color: #58a6ff; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }
    .card {
      background: #161b22; border: 1px solid #30363d;
      border-radius: 8px; padding: 16px;
    }
    .card h3 { margin: 0 0 8px 0; }
    .card p { color: #8b949e; margin: 0 0 12px 0; font-size: 14px; }
    .status { font-size: 12px; margin-bottom: 8px; }
    .ok { color: #3fb950; }
    .err { color: #f85149; }
    button {
      background: #238636; color: white; border: none;
      padding: 6px 12px; border-radius: 6px; cursor: pointer;
      margin-right: 8px; font-size: 13px;
    }
    button:hover { background: #2ea043; }
    button.danger { background: #da3633; }
    button.danger:hover { background: #f85149; }
    #output {
      background: #0d1117; border: 1px solid #30363d;
      padding: 12px; margin-top: 20px; border-radius: 8px;
      font-family: monospace; font-size: 13px;
      height: 300px; overflow-y: auto; white-space: pre-wrap;
    }
    .category { margin-top: 24px; }
    .category h2 {
      font-size: 14px; text-transform: uppercase;
      color: #8b949e; border-bottom: 1px solid #30363d;
      padding-bottom: 8px;
    }
  </style>
</head>
<body>
  <h1>DevContainer Manager</h1>

  <div id="services">Loading...</div>

  <h2>Output</h2>
  <div id="output">Ready.</div>

  <script>
    // Load services on page load
    async function loadServices() {
      const res = await fetch('/api/services');
      const services = await res.json();

      // Group by category
      const categories = {};
      services.forEach(s => {
        if (!categories[s.category]) categories[s.category] = [];
        categories[s.category].push(s);
      });

      // Render
      let html = '';
      for (const [cat, items] of Object.entries(categories)) {
        html += `<div class="category"><h2>${cat}</h2><div class="grid">`;
        items.forEach(s => {
          const statusClass = s.status === 'installed' ? 'ok' : 'err';
          const statusIcon = s.status === 'installed' ? '[OK]' : '[X]';
          html += `
            <div class="card">
              <div class="status ${statusClass}">${statusIcon} ${s.status}</div>
              <h3>${s.name}</h3>
              <p>${s.description}</p>
              <div>
                ${s.commands.map(cmd =>
                  `<button onclick="runScript('${s.path}', '${cmd.flag}')">${cmd.description}</button>`
                ).join('')}
              </div>
            </div>`;
        });
        html += '</div></div>';
      }
      document.getElementById('services').innerHTML = html;
    }

    // Run script with streaming output
    function runScript(script, args = '') {
      const output = document.getElementById('output');
      output.textContent = `Running: ${script} ${args}\n\n`;

      const es = new EventSource(`/api/run/${encodeURIComponent(script)}?args=${args}`);
      es.onmessage = (e) => {
        if (e.data.startsWith('[EXIT:')) {
          const code = e.data.match(/\d+/)[0];
          output.textContent += `\n[Completed with exit code ${code}]`;
          es.close();
          loadServices(); // Refresh status
          return;
        }
        output.textContent += e.data;
        output.scrollTop = output.scrollHeight;
      };
      es.onerror = () => {
        output.textContent += '\n[Connection lost]';
        es.close();
      };
    }

    loadServices();
  </script>
</body>
</html>
```

## JSON Schema for Services API

```json
[
  {
    "id": "dev-golang",
    "name": "Go Runtime & Development",
    "description": "Install Go runtime and development tools",
    "category": "LANGUAGE_DEV",
    "status": "installed",
    "path": "/workspaces/.devcontainer/additions/install-dev-golang.sh",
    "commands": [
      { "flag": "", "description": "Install", "requiresArg": false },
      { "flag": "--version", "description": "Install version", "requiresArg": true, "prompt": "Enter version" },
      { "flag": "--uninstall", "description": "Uninstall", "requiresArg": false }
    ]
  }
]
```

## Implementation Steps

### Phase 1: Core Infrastructure

1. Modify `component-scanner.sh` to support `--json` output
2. Create `web-manager.js` with basic API endpoints
3. Create `web-ui.html` with service listing

### Phase 2: Full Functionality

4. Add streaming output (SSE) for script execution
5. Add status refresh after script completion
6. Handle scripts that require input/arguments
7. Add error handling and timeout management

### Phase 3: Polish

8. Add categories collapsible sections
9. Add search/filter functionality
10. Add service logs viewing
11. Document the web UI in `docs/`

## Future Use: Provision-Host (urbalurba-infrastructure)

This same web UI system will later be adapted for the `urbalurba-infrastructure` project's provision-host container to manage Kubernetes deployments. The architecture is intentionally identical:

- Same `web-manager.js` (just change paths)
- Same `web-ui.html` (maybe different branding/theme)
- Same metadata pattern in scripts
- Different scripts (K8s deployment instead of dev tools)

### Mapping to Provision-Host

| DevContainer | Provision-Host |
|--------------|----------------|
| `install-*.sh` | `[NN]-setup-[service].sh` |
| `service-*.sh` | Service lifecycle (deploy/remove/status) |
| `config-*.sh` | Secrets management scripts |
| `cmd-*.sh` | Utility/diagnostic commands |
| `.devcontainer/additions/` | `provision-host/kubernetes/additions/` |
| `enabled-tools.conf` | `enabled-services.conf` |

## Starting the Web UI

Add to container startup or run manually:

```bash
# Start web manager
node .devcontainer/manage/web-manager.js &

# Access at
# http://localhost:3000
```

Or add to `devcontainer.json`:

```json
{
  "postStartCommand": "node .devcontainer/manage/web-manager.js &"
}
```

## Security Considerations

- Web UI runs locally in the container
- No authentication needed (trusted local environment)
- Scripts run with container user permissions
- Consider adding confirmation dialogs for destructive actions

## Summary

Create a lightweight web interface for the devcontainer additions system that:

- Reuses existing scripts and metadata (no duplication)
- Uses only Node.js built-in modules (no npm dependencies)
- Provides real-time output streaming
- Shows installation status at a glance
- Can be reused later for Kubernetes cluster management in provision-host
