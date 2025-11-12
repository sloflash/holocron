# TTY Terminal MCP Server

MCP (Model Context Protocol) server that provides TTY terminal access to Claude Code, enabling execution of interactive commands like Zellij, tmux, and other TUI applications.

## Features

- **Real TTY terminals**: Creates actual pseudo-terminals (PTY) for full interactivity
- **Multiple sessions**: Manage multiple terminal sessions simultaneously
- **Command execution**: Run commands and capture output
- **Session persistence**: Keep terminals alive between commands

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

### `tty_open`
Open a new TTY terminal session.

**Parameters:**
- `shell` (string, optional): Shell to use (default: "bash")
- `cwd` (string, optional): Working directory (default: current directory)

**Returns:** Terminal ID and initial output

**Example:**
```
Use tty_open tool with:
{
  "shell": "bash",
  "cwd": "/Users/mayankketkar/projects"
}
```

### `tty_exec`
Execute a command in an open terminal.

**Parameters:**
- `terminal_id` (string, required): Terminal ID from tty_open
- `command` (string, required): Command to execute
- `timeout` (number, optional): Timeout in seconds (default: 30)

**Returns:** Command output

**Example:**
```
Use tty_exec tool with:
{
  "terminal_id": "tty-1",
  "command": "ls -la"
}
```

### `tty_read`
Read current output from a terminal.

**Parameters:**
- `terminal_id` (string, required): Terminal ID
- `timeout` (number, optional): How long to wait for output (default: 5)

**Returns:** Available output

### `tty_close`
Close a terminal session.

**Parameters:**
- `terminal_id` (string, required): Terminal ID to close

**Returns:** Confirmation message

### `tty_list`
List all open terminal sessions.

**Returns:** List of terminal IDs with their status

## Usage Examples

### Example 1: Test Zellij Layout

```
Claude: I want to test the Zellij layout
1. Use tty_open to create a terminal
2. Use tty_exec with command "zellij --layout /path/to/layout.kdl"
3. Use tty_read to check output
4. Use tty_close when done
```

### Example 2: Interactive Shell Session

```
1. Open terminal: tty_open with cwd="/Users/mayankketkar/projects"
2. Run command: tty_exec with command="git status"
3. Another command: tty_exec with command="ls -la"
4. Close: tty_close with terminal_id
```

### Example 3: Long-Running Process

```
1. Open terminal
2. Start process: tty_exec with command="npm run dev"
3. Check output periodically: tty_read
4. Stop when done: tty_close
```

## Testing Holocron with TTY

Once this MCP is registered, Claude Code can:

```python
# 1. Open terminal
terminal = tty_open(cwd="/Users/mayankketkar/claude-tools/tmux")

# 2. Create test environment
tty_exec(terminal_id, "NO_CLEANUP=true ./src/scripts/test-setup.sh setup")

# 3. Launch Zellij
tty_exec(terminal_id, "zellij --layout /tmp/holocron-test-XXXX/.config/holocron/layouts/hyperpod.kdl")

# 4. Capture screen/layout
tty_exec(terminal_id, "zellij action dump-layout")

# 5. Verify quadrants
tty_read(terminal_id)

# 6. Close
tty_close(terminal_id)
```

## Troubleshooting

### MCP Server Not Loading

1. Check Claude Code MCP config is valid JSON
2. Verify Python 3 path: `which python3`
3. Check server.py is executable: `chmod +x server.py`
4. Restart Claude Code completely

### Terminal Commands Hang

- Increase timeout parameter
- Some interactive prompts may not work (use non-interactive flags)
- Check if command requires user input

### Output Incomplete

- Use tty_read with longer timeout
- Some programs buffer output (add flush or use unbuffered mode)

## Technical Details

- Uses Python's `pty` module for pseudo-terminal creation
- Implements MCP stdio transport protocol
- Handles multiple concurrent terminal sessions
- Automatic buffer management and cleanup

## Limitations

- Some fully interactive TUI apps may not work perfectly
- Terminal size is default (not customizable yet)
- No terminal resizing support
- Output capture is text-only (no ANSI escape sequence interpretation)

## Future Enhancements

- Terminal size configuration
- ANSI escape code parsing for better output visualization
- Screen capture/dump to image
- Terminal recording (session replay)
- Bidirectional streaming

## License

Part of the Holocron project - MIT License
