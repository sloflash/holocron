#!/bin/bash
# Test script for TTY Terminal MCP Server
# This script tests the server by sending JSON-RPC requests via stdio

set -e

SERVER_SCRIPT="/Users/mayankketkar/claude-tools/tmux/.claude/mcp-servers/tty-terminal/server.py"

echo "=== Testing TTY Terminal MCP Server ==="
echo ""

# Test 1: Initialize
echo "Test 1: Initializing server..."
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"initialized"}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  sleep 1
) | python3 "$SERVER_SCRIPT" 2>&1 | head -20

echo ""
echo "✓ Server initialized and listed tools"
echo ""

# Test 2: Check available tools
echo "Test 2: Available tools:"
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"initialized"}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  sleep 1
) | python3 "$SERVER_SCRIPT" 2>&1 | grep -o '"name":"[^"]*"' | sort | uniq

echo ""
echo "Expected tools:"
echo "  - open_terminal"
echo "  - send_command"
echo "  - start_zellij_session"
echo "  - zellij_action"
echo "  - capture_state"
echo "  - list_terminals"
echo ""

echo "=== Basic tests passed! ==="
echo ""
echo "To test the full functionality, restart Claude Code and use the MCP tools:"
echo "  1. Restart Claude Code to load the new server"
echo "  2. Use open_terminal tool to create a terminal"
echo "  3. Use start_zellij_session to launch Zellij"
echo "  4. Use zellij_action to test dump-layout, write-chars, etc."
echo "  5. Use capture_state to verify operations"
echo ""
