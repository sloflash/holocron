# TTY Terminal MCP Server - Testing Guide

This guide walks through testing all functionality of the MCP server.

## Prerequisites

1. MCP server is configured in Claude Code
2. Claude Code has been restarted to load the server
3. Python 3.7+ is installed
4. Zellij is installed: `which zellij`
5. macOS with Terminal.app

## Quick Test

Run the basic server test:

```bash
./test-server.sh
```

This verifies the server starts and lists all tools correctly.

## Full Integration Tests

After restarting Claude Code, you can test the full workflow within Claude Code itself.

### Test 1: Basic Terminal Control

**Objective**: Verify we can open a terminal and send commands.

```
You (to Claude Code):
"Use the open_terminal tool to create a new terminal in /tmp"

Expected: Terminal opens, you get back terminal_id like "term-1"

"Use send_command to run 'echo Hello from MCP' in term-1"

Expected: Command executes in the terminal
```

**Verification**: Check that Terminal.app opened a new window and executed the command.

---

### Test 2: Terminal Handle Persistence

**Objective**: Verify same terminal can receive multiple commands.

```
You:
"Open a terminal in /tmp, then send these commands in sequence:
  1. mkdir test-mcp
  2. cd test-mcp
  3. touch file1.txt file2.txt
  4. ls -la"

Expected: All commands execute in the same terminal window
```

**Verification**: Use `list_terminals` to see the terminal is tracked.

---

### Test 3: Start Zellij Session

**Objective**: Verify we can launch Zellij with a layout.

```
You:
"Open a terminal in /Users/mayankketkar/claude-tools/tmux, then start a Zellij session called 'test-session' with the hyperpod layout"

Expected:
  - Terminal opens
  - Zellij launches with the layout
  - Session name is registered
```

**Verification**: Check Terminal.app shows Zellij UI with the expected layout.

---

### Test 4: Dump Layout

**Objective**: Verify we can capture Zellij layout state.

```
You:
"Start a Zellij session, wait 3 seconds, then use zellij_action to dump-layout"

Expected: Returns KDL layout text showing all panes and tabs
```

**Verification**: Check that output includes:
- `layout {`
- `tab` and `pane` definitions
- Configuration details

---

### Test 5: Capture and Parse State

**Objective**: Verify state capture and parsing works.

```
You:
"Start a Zellij session with hyperpod layout, then use capture_state to verify it"

Expected output should include:
  - Session name
  - List of tabs
  - List of panes by name
  - Total pane count
  - Raw KDL
```

**Verification**: Check that pane count matches expected (e.g., 8+ panes for hyperpod).

---

### Test 6: Write Characters to Pane

**Objective**: Verify we can send input to Zellij panes.

```
You:
"Start a Zellij session, then use zellij_action to write-chars with text 'echo Test\\n'"

Expected: The command appears in the active Zellij pane and executes
```

**Verification**: Look at the terminal and verify the command ran.

---

### Test 7: Create New Pane

**Objective**: Verify we can dynamically create panes.

```
You:
"Start a Zellij session, capture the initial state (note pane count),
then use zellij_action to create a new-pane to the right,
then capture state again to verify pane count increased"

Expected:
  - Initial state: N panes
  - After new-pane: N+1 panes
```

**Verification**: Visually confirm new pane appeared in Zellij.

---

### Test 8: List Terminals

**Objective**: Verify session tracking works.

```
You:
"Open 3 terminals in different directories, then list_terminals"

Expected: Shows all 3 terminals with their IDs, window IDs, and CWDs
```

---

### Test 9: Full Holocron Testing Pipeline

**Objective**: End-to-end test of Holocron layout verification.

```
You:
"Run the full Holocron test:
  1. Open terminal in /Users/mayankketkar/claude-tools/tmux
  2. Run: NO_CLEANUP=true ./src/scripts/test-setup.sh setup
  3. Find the generated layout path in /tmp/holocron-test-*
  4. Start Zellij with that layout
  5. Wait 3 seconds
  6. Capture state and verify:
     - At least 7 panes exist
     - Panes named Q1, Q2, Q3, Q4 or similar
     - Multiple tabs or stacked panes"

Expected: Complete verification report showing Holocron layout is correct
```

---

## Manual Testing Checklist

After running automated tests, manually verify:

- [ ] Terminal.app windows open correctly
- [ ] Commands execute in the right terminal windows
- [ ] Zellij launches with correct layouts
- [ ] Multiple terminals can be managed simultaneously
- [ ] `list_terminals` shows accurate information
- [ ] State capture includes all expected panes
- [ ] Layout parsing extracts pane names correctly
- [ ] New panes can be created dynamically
- [ ] Write-chars sends text to panes correctly

## Debugging Failed Tests

### Server Not Responding
- Check Claude Code logs
- Verify MCP config at `.claude/mcp.json`
- Restart Claude Code completely

### osascript Fails
- Grant Accessibility permissions to Terminal.app
- Check System Settings > Privacy & Security

### Zellij Commands Fail
- Verify Zellij installed: `zellij --version`
- Check session exists: `zellij list-sessions`
- Try commands manually first

### State Capture Empty
- Wait longer after starting Zellij (3-5 seconds)
- Verify session name is correct
- Check Zellij is actually running

## Performance Notes

- Each osascript call takes ~100-500ms
- Zellij commands take ~50-200ms
- Layout parsing is instant (regex-based)
- Opening terminals takes ~1-2 seconds

## Known Issues

1. **Session persistence**: Terminal sessions are lost if MCP server restarts
2. **macOS only**: No Linux/Windows support yet
3. **Basic KDL parsing**: May miss complex nested structures
4. **No visual capture**: Cannot take screenshots (yet)

## Next Steps

After successful testing:
- Use in your Holocron workflows
- Build automated test suites using these tools
- Integrate with CI/CD for layout validation
- Extend for other terminal multiplexers (tmux, screen)

## Success Criteria

All tests pass when:
- ✅ Terminals open and receive commands
- ✅ Multiple terminals tracked simultaneously
- ✅ Zellij sessions start with layouts
- ✅ Layout state can be captured and parsed
- ✅ Panes can be created dynamically
- ✅ Text can be written to specific panes
- ✅ Session metadata is accurate

---

**Ready to test?** Restart Claude Code and start with Test 1!
