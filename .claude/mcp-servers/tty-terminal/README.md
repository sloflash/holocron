# TTY Terminal MCP Server

Advanced MCP (Model Context Protocol) server that provides comprehensive TTY terminal control and Zellij testing capabilities. This server enables Claude Code to open persistent terminal sessions, execute commands, manage Zellij layouts, and verify state changes.

## Features

- **Persistent Terminal Handles**: Open terminals and maintain references for repeated operations
- **macOS Terminal.app Integration**: Control Terminal.app via osascript (AppleScript)
- **Zellij Session Management**: Start, control, and monitor Zellij sessions
- **Command Execution**: Send commands to specific terminals
- **State Capture & Verification**: Dump layouts, parse KDL, and verify pane configurations
- **Multi-Session Support**: Manage multiple terminal and Zellij sessions simultaneously

## Installation

### 1. Install the MCP Server

The server is already in this directory. Ensure Python 3 is installed:

```bash
python3 --version
```

### 2. Register with Claude Code

Add to your Claude Code MCP configuration file (`~/.claude/mcp.json` or project-level `.claude/mcp.json`):

```json
{
  "mcpServers": {
    "tty-terminal": {
      "type": "stdio",
      "command": "python3",
      "args": [
        "/Users/mayankketkar/claude-tools/tmux/.claude/mcp-servers/tty-terminal/server.py"
      ]
    }
  }
}
```

Or copy the provided config:

```bash
# For global access
cp config.json ~/.claude/mcp.json

# For project-only access
cp config.json .claude/mcp.json
```

### 3. Restart Claude Code

For the MCP server to be loaded, restart Claude Code or reload the window.

## Available Tools

### 1. `open_terminal`
Opens a new Terminal.app window and returns a persistent handle for future operations.

**Parameters:**
- `cwd` (string, optional): Working directory (default: current directory)

**Returns:** Terminal ID, Window ID, and working directory

**Example:**
```json
{
  "cwd": "/Users/mayankketkar/claude-tools/tmux"
}
```

**Use case:** Start of every workflow - get a terminal handle to work with

---

### 2. `send_command`
Sends a command to a specific terminal using its ID. The command executes via osascript.

**Parameters:**
- `terminal_id` (string, required): Terminal ID from `open_terminal`
- `command` (string, required): Shell command to execute

**Returns:** Command execution status

**Example:**
```json
{
  "terminal_id": "term-1",
  "command": "echo 'Hello from MCP'"
}
```

**Use case:** Execute any shell command in a managed terminal

---

### 3. `start_zellij_session`
Starts a Zellij session in a terminal with optional layout file.

**Parameters:**
- `terminal_id` (string, required): Terminal ID to start Zellij in
- `session_name` (string, optional): Zellij session name (auto-generated if not provided)
- `layout_path` (string, optional): Path to Zellij layout KDL file

**Returns:** Session name and status

**Example:**
```json
{
  "terminal_id": "term-1",
  "session_name": "hyperpod-test",
  "layout_path": "/Users/mayankketkar/.config/holocron/layouts/hyperpod.kdl"
}
```

**Use case:** Launch your Zellij workspace in a controlled terminal

---

### 4. `zellij_action`
Executes Zellij CLI actions (dump-layout, write-chars, new-pane, list-sessions) on a running session.

**Parameters:**
- `terminal_id` (string, required): Terminal ID with active Zellij session
- `action` (string, required): One of: `dump-layout`, `write-chars`, `new-pane`, `list-sessions`
- `action_args` (object, optional): Action-specific arguments
  - For `write-chars`: `{ "text": "string", "pane_id": "optional" }`
  - For `new-pane`: `{ "direction": "right|down", "cwd": "/path" }`

**Returns:** Action output (KDL for dump-layout, status for others)

**Examples:**

Dump layout:
```json
{
  "terminal_id": "term-1",
  "action": "dump-layout"
}
```

Write to a pane:
```json
{
  "terminal_id": "term-1",
  "action": "write-chars",
  "action_args": {
    "text": "ls -la\\n"
  }
}
```

Create new pane:
```json
{
  "terminal_id": "term-1",
  "action": "new-pane",
  "action_args": {
    "direction": "right",
    "cwd": "/tmp"
  }
}
```

**Use case:** Test Zellij operations and manipulate layouts

---

### 5. `capture_state`
Captures and parses Zellij layout state and terminal content for verification.

**Parameters:**
- `terminal_id` (string, required): Terminal ID to capture state from

**Returns:** Parsed layout information (panes, tabs, counts) and raw KDL

**Example:**
```json
{
  "terminal_id": "term-1"
}
```

**Output format:**
```
=== Zellij Layout State ===
Session: hyperpod-test
Tabs: Tab1, Tab2
Panes: Repo1, Repo2, K9s-Prod
Total Pane Count: 8

Raw Layout:
layout {
  ...
}
```

**Use case:** Verify that your Zellij operations worked correctly

---

### 6. `list_terminals`
Lists all managed terminal sessions with their metadata.

**Parameters:** None

**Returns:** List of all terminal sessions with IDs, window IDs, Zellij sessions, CWDs, and creation times

**Example:**
```json
{}
```

**Use case:** Debug what terminals are active and their associated sessions

## Complete Workflow Examples

### Example 1: Basic Terminal Control

```
1. Open terminal
   → open_terminal({ "cwd": "/Users/mayankketkar/projects" })
   ← Returns: { terminal_id: "term-1", window_id: "12345", cwd: "..." }

2. Execute commands
   → send_command({ "terminal_id": "term-1", "command": "ls -la" })
   → send_command({ "terminal_id": "term-1", "command": "git status" })

3. List active sessions
   → list_terminals({})
```

### Example 2: Test Holocron Hyperpod Layout

```
1. Open terminal in project directory
   → open_terminal({ "cwd": "/Users/mayankketkar/claude-tools/tmux" })
   ← terminal_id: "term-1"

2. Start Zellij with Hyperpod layout
   → start_zellij_session({
       "terminal_id": "term-1",
       "session_name": "hyperpod-test",
       "layout_path": "/Users/mayankketkar/.config/holocron/layouts/hyperpod.kdl"
     })

3. Wait 2-3 seconds for layout to initialize

4. Dump and verify layout
   → zellij_action({
       "terminal_id": "term-1",
       "action": "dump-layout"
     })
   ← Returns full KDL layout

5. Parse and verify
   → capture_state({ "terminal_id": "term-1" })
   ← Returns: Parsed info with pane counts, names, tabs

6. Verify: Check that pane_count matches expected (e.g., 8 panes for Hyperpod)
```

### Example 3: Test Zellij Write and New Pane

```
1. Open terminal and start Zellij
   → open_terminal({ "cwd": "/tmp" })
   → start_zellij_session({ "terminal_id": "term-1", "session_name": "test-session" })

2. Write command to current pane
   → zellij_action({
       "terminal_id": "term-1",
       "action": "write-chars",
       "action_args": { "text": "echo 'Testing write-chars'\\n" }
     })

3. Create a new pane to the right
   → zellij_action({
       "terminal_id": "term-1",
       "action": "new-pane",
       "action_args": { "direction": "right" }
     })

4. Capture state to verify new pane was created
   → capture_state({ "terminal_id": "term-1" })
   ← Verify: pane_count increased by 1

5. Dump layout to see structure
   → zellij_action({ "terminal_id": "term-1", "action": "dump-layout" })
```

### Example 4: Automated Holocron Testing Pipeline

```
1. Setup test environment
   → send_command({
       "terminal_id": "term-1",
       "command": "NO_CLEANUP=true ./src/scripts/test-setup.sh setup"
     })

2. Launch test Holocron instance
   → start_zellij_session({
       "terminal_id": "term-1",
       "session_name": "holocron-test",
       "layout_path": "/tmp/holocron-test-XXXX/.config/holocron/layouts/hyperpod.kdl"
     })

3. Wait for initialization (2-3 seconds)

4. Verify quadrants
   → capture_state({ "terminal_id": "term-1" })

   Expected state:
   - Q1: 3 stacked panes (Repo1, Repo2, Repo3)
   - Q2: 1 pane (placeholder)
   - Q3: 2-3 stacked panes (K8s clusters with k9s)
   - Q4: 2-3 panes (cluster utilities)
   - Total: 7-10 panes

5. Test stacked pane switching in Q1
   → zellij_action({
       "action": "write-chars",
       "action_args": { "text": "\\u001b[t" }  // Zellij keybinding to cycle panes
     })

6. Verify pane switched
   → capture_state({ "terminal_id": "term-1" })

7. Clean up
   → send_command({ "command": "./src/scripts/test-setup.sh teardown" })
```

## Key Design Decisions

### Why Persistent Handles?
Traditional MCP servers create new terminals for each operation, losing context. This server maintains a `TerminalManager` that tracks terminal sessions, allowing you to:
- Send multiple commands to the same terminal
- Start Zellij and continue interacting with it
- Verify state changes across operations

### Why osascript for Mac?
- Direct control of Terminal.app windows by ID
- Ability to send commands to specific windows
- Read terminal content for verification
- Native macOS integration

### Why Separate capture_state?
Separating state capture from action execution allows you to:
- Verify operations worked correctly
- Parse KDL layouts programmatically
- Test business logic without manual inspection
- Build automated test suites

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code                          │
│              (calls MCP tools via IPC)                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              MCP Server (server.py)                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │         TerminalManager                           │  │
│  │  - Tracks terminal_id → session mappings          │  │
│  │  - Maintains window IDs and Zellij session names  │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │      MacTerminalController                        │  │
│  │  - open_terminal() via osascript                  │  │
│  │  - send_command() to specific window ID           │  │
│  │  - get_window_content() for verification          │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │       ZellijController                            │  │
│  │  - start_session() builds zellij commands         │  │
│  │  - dump_layout() captures KDL                     │  │
│  │  - write_chars(), new_pane() for manipulation     │  │
│  │  - parse_layout() extracts structured data        │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              macOS System Layer                         │
│  ┌──────────────────┐    ┌──────────────────────────┐  │
│  │  Terminal.app    │◄───┤  osascript (AppleScript) │  │
│  │  (window 12345)  │    └──────────────────────────┘  │
│  │                  │                                    │
│  │  ┌────────────┐  │                                    │
│  │  │  Zellij    │  │◄───── zellij CLI (subprocess)     │
│  │  │  Session   │  │                                    │
│  │  └────────────┘  │                                    │
│  └──────────────────┘                                    │
└─────────────────────────────────────────────────────────┘
```

## Troubleshooting

### MCP Server Not Loading
1. Verify config at `~/.claude/mcp.json` or `.claude/mcp.json`
2. Check Python 3 installed: `python3 --version`
3. Restart Claude Code completely (not just reload)
4. Check Claude Code logs for MCP connection errors

### osascript Permission Denied
- macOS may require Accessibility permissions for Terminal control
- Go to System Settings > Privacy & Security > Accessibility
- Add Terminal.app and Claude Code if prompted

### Zellij Commands Fail
- Ensure Zellij is installed: `which zellij`
- Verify layout file paths are absolute
- Check that Zellij session exists before running actions

### State Capture Returns Empty
- Wait 2-3 seconds after starting Zellij for initialization
- Verify Zellij session name matches what was used in `start_zellij_session`
- Check Zellij is actually running: `zellij list-sessions`

### Window ID Not Found
- Terminal window may have been closed manually
- Use `list_terminals` to see active sessions
- Open new terminal if needed

## Technical Details

- **Language**: Python 3.7+
- **Protocol**: MCP stdio transport (JSON-RPC)
- **Terminal Control**: osascript (AppleScript) for macOS Terminal.app
- **Zellij Control**: Direct CLI subprocess calls
- **State Management**: In-memory session tracking (resets on server restart)
- **Parsing**: Regex-based KDL parsing (sufficient for verification, not full KDL parser)

## Limitations

- **macOS only**: Uses Terminal.app and osascript (no Linux/Windows support yet)
- **Session persistence**: Terminal sessions lost if MCP server restarts
- **KDL parsing**: Basic regex parsing, may miss complex KDL structures
- **No streaming**: Commands execute and return; no real-time output streaming
- **Terminal size**: Uses default terminal size (no configuration yet)

## Future Enhancements

- [ ] Linux support (iTerm2, Kitty, Alacritty via other methods)
- [ ] Cross-platform PTY-based terminal control
- [ ] Full KDL parser for robust layout parsing
- [ ] Persistent session storage (survive MCP server restarts)
- [ ] Streaming command output
- [ ] Terminal size configuration
- [ ] Screenshot/visual capture for verification
- [ ] Zellij plugin integration for advanced control

## Contributing

This MCP server is part of the Holocron project. Contributions welcome!

## License

MIT License - Part of the Holocron terminal workspace system
