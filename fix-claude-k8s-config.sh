#!/bin/bash

# Script to fix Claude Desktop Kubernetes MCP configuration
# This script updates the Claude Desktop config to include the correct kubectl PATH

CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
KUBECTL_PATH="/Users/terje.christensen/.rd/bin/kubectl"
KUBECONFIG_PATH="/Users/terje.christensen/.kube/config"

echo "Fixing Claude Desktop Kubernetes MCP configuration..."

# Check if kubectl exists at the expected location
if [ ! -f "$KUBECTL_PATH" ]; then
    echo "Error: kubectl not found at $KUBECTL_PATH"
    echo "Current kubectl location: $(which kubectl)"
    exit 1
fi

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Error: kubeconfig not found at $KUBECONFIG_PATH"
    echo "Please check your kubeconfig location"
    exit 1
fi

# Create Claude config directory if it doesn't exist
mkdir -p "$CLAUDE_CONFIG_DIR"

# Create the new configuration
cat > "$CLAUDE_CONFIG_FILE" << 'EOF'
{
  "mcpServers": {
    "kubernetes": {
      "command": "npx",
      "args": ["mcp-server-kubernetes"],
      "env": {
        "PATH": "/Users/terje.christensen/.rd/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin",
        "KUBECONFIG": "/Users/terje.christensen/.kube/config"
      }
    }
  }
}
EOF

echo "Configuration updated successfully!"
echo "Configuration file: $CLAUDE_CONFIG_FILE"
echo ""
echo "Next steps:"
echo "1. Completely quit Claude Desktop (Cmd+Q)"
echo "2. Restart Claude Desktop"
echo "3. Look for the MCP server indicator (🔌) in the bottom-right corner"
echo "4. Test by asking Claude to list your Kubernetes pods"
echo ""
echo "Configuration contents:"
cat "$CLAUDE_CONFIG_FILE"
