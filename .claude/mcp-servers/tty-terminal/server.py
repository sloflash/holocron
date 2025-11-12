#!/usr/bin/env python3
"""
Advanced MCP Server for TTY terminal control and Zellij testing
Provides persistent terminal handles, Zellij session management, and state verification
"""
import json
import sys
import subprocess
import os
import time
import re
from typing import Dict, Optional, List
from dataclasses import dataclass, asdict
from enum import Enum

@dataclass
class TerminalSession:
    """Represents a managed terminal session"""
    terminal_id: str
    window_id: Optional[str]
    zellij_session: Optional[str]
    cwd: str
    created_at: float

class TerminalManager:
    """Manages persistent terminal sessions"""

    def __init__(self):
        self.sessions: Dict[str, TerminalSession] = {}
        self.next_id = 1

    def create_session(self, cwd: str = None) -> TerminalSession:
        """Create a new terminal session"""
        terminal_id = f"term-{self.next_id}"
        self.next_id += 1

        if cwd is None:
            cwd = os.getcwd()

        session = TerminalSession(
            terminal_id=terminal_id,
            window_id=None,
            zellij_session=None,
            cwd=cwd,
            created_at=time.time()
        )

        self.sessions[terminal_id] = session
        return session

    def get_session(self, terminal_id: str) -> Optional[TerminalSession]:
        """Get a session by ID"""
        return self.sessions.get(terminal_id)

    def update_session(self, terminal_id: str, **kwargs):
        """Update session properties"""
        if terminal_id in self.sessions:
            session = self.sessions[terminal_id]
            for key, value in kwargs.items():
                if hasattr(session, key):
                    setattr(session, key, value)

    def list_sessions(self) -> List[TerminalSession]:
        """List all sessions"""
        return list(self.sessions.values())

    def remove_session(self, terminal_id: str):
        """Remove a session"""
        if terminal_id in self.sessions:
            del self.sessions[terminal_id]

class ZellijController:
    """Controls Zellij sessions and captures state"""

    @staticmethod
    def start_session(session_name: str, layout_path: Optional[str] = None, cwd: Optional[str] = None) -> str:
        """Generate command to start a Zellij session"""
        cmd_parts = ["zellij"]

        if layout_path:
            cmd_parts.extend(["--layout", layout_path])

        # Use 'attach' command with session name to create or attach
        cmd_parts.extend(["attach", "-c", session_name])

        return " ".join(cmd_parts)

    @staticmethod
    def dump_layout(session_name: str) -> tuple[bool, str]:
        """Dump the current layout of a Zellij session

        Note: This requires being inside the Zellij session to work properly.
        The MCP server should use send_command to inject the dump command into the session.
        """
        try:
            # Try using the 'pipe' mechanism to dump layout
            # This is a workaround since dump-layout doesn't support --session
            result = subprocess.run(
                ["zellij", "--session", session_name, "action", "dump-layout"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0 and result.stdout:
                return True, result.stdout

            # Fallback: return error explaining the issue
            return False, "dump-layout requires being inside the Zellij session. Use send_command to inject 'zellij action dump-layout > /tmp/layout.kdl' then read the file."
        except Exception as e:
            return False, str(e)

    @staticmethod
    def write_chars(session_name: str, text: str, pane_id: Optional[str] = None) -> tuple[bool, str]:
        """Write characters to a Zellij pane"""
        try:
            cmd = ["zellij", "action", "write-chars", text, "--session", session_name]
            if pane_id:
                cmd.extend(["--pane-id", pane_id])

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0, result.stdout if result.returncode == 0 else result.stderr
        except Exception as e:
            return False, str(e)

    @staticmethod
    def list_sessions() -> tuple[bool, str]:
        """List all Zellij sessions"""
        try:
            result = subprocess.run(
                ["zellij", "list-sessions"],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0, result.stdout
        except Exception as e:
            return False, str(e)

    @staticmethod
    def new_pane(session_name: str, direction: Optional[str] = None, cwd: Optional[str] = None) -> tuple[bool, str]:
        """Create a new pane in a Zellij session"""
        try:
            cmd = ["zellij", "action", "new-pane", "--session", session_name]
            if direction:
                cmd.extend(["--direction", direction])
            if cwd:
                cmd.extend(["--cwd", cwd])

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0, result.stdout if result.returncode == 0 else result.stderr
        except Exception as e:
            return False, str(e)

    @staticmethod
    def parse_layout(kdl_output: str) -> Dict:
        """Parse Zellij layout KDL output into structured data"""
        # Simple parser to extract key information
        # This is a basic implementation - can be enhanced

        info = {
            "panes": [],
            "tabs": [],
            "raw": kdl_output
        }

        # Extract pane names
        pane_matches = re.findall(r'pane\s+name="([^"]+)"', kdl_output)
        info["panes"] = pane_matches

        # Extract tab names
        tab_matches = re.findall(r'tab\s+name="([^"]+)"', kdl_output)
        info["tabs"] = tab_matches

        # Count panes
        info["pane_count"] = len(re.findall(r'\bpane\s*{', kdl_output))

        return info

class MacTerminalController:
    """Controls macOS Terminal.app via osascript"""

    @staticmethod
    def open_terminal(cwd: str) -> tuple[bool, str]:
        """Open a new Terminal window and return its ID"""
        # AppleScript to open terminal and get window ID
        script = f'''
        tell application "Terminal"
            activate
            set newWindow to do script "cd {cwd}"
            set windowID to id of window 1
            return windowID
        end tell
        '''

        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                window_id = result.stdout.strip()
                return True, window_id
            else:
                return False, result.stderr
        except Exception as e:
            return False, str(e)

    @staticmethod
    def send_command(window_id: str, command: str) -> tuple[bool, str]:
        """Send a command to a specific Terminal window"""
        script = f'''
        tell application "Terminal"
            do script "{command}" in window id {window_id}
        end tell
        '''

        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0, result.stdout if result.returncode == 0 else result.stderr
        except Exception as e:
            return False, str(e)

    @staticmethod
    def get_window_content(window_id: str) -> tuple[bool, str]:
        """Get the content of a Terminal window"""
        script = f'''
        tell application "Terminal"
            get contents of window id {window_id}
        end tell
        '''

        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0, result.stdout if result.returncode == 0 else result.stderr
        except Exception as e:
            return False, str(e)

# Global terminal manager instance
terminal_manager = TerminalManager()

def handle_open_terminal(args: Dict) -> Dict:
    """Handle open_terminal tool call"""
    cwd = args.get("cwd", os.getcwd())

    # Create session in manager
    session = terminal_manager.create_session(cwd)

    # Open actual terminal
    success, window_id = MacTerminalController.open_terminal(cwd)

    if success:
        terminal_manager.update_session(session.terminal_id, window_id=window_id)
        result_text = f"Terminal opened successfully\nTerminal ID: {session.terminal_id}\nWindow ID: {window_id}\nCWD: {cwd}"
    else:
        result_text = f"Failed to open terminal: {window_id}"

    return {
        "content": [
            {
                "type": "text",
                "text": result_text
            }
        ]
    }

def handle_send_command(args: Dict) -> Dict:
    """Handle send_command tool call"""
    terminal_id = args.get("terminal_id")
    command = args.get("command", "")

    if not terminal_id:
        return {
            "content": [{"type": "text", "text": "Error: terminal_id is required"}]
        }

    session = terminal_manager.get_session(terminal_id)
    if not session:
        return {
            "content": [{"type": "text", "text": f"Error: Terminal session '{terminal_id}' not found"}]
        }

    if not session.window_id:
        return {
            "content": [{"type": "text", "text": f"Error: No window ID for terminal '{terminal_id}'"}]
        }

    success, output = MacTerminalController.send_command(session.window_id, command)

    if success:
        result_text = f"Command sent to terminal {terminal_id}\nCommand: {command}\nOutput: {output}"
    else:
        result_text = f"Failed to send command: {output}"

    return {
        "content": [{"type": "text", "text": result_text}]
    }

def handle_start_zellij(args: Dict) -> Dict:
    """Handle start_zellij_session tool call"""
    terminal_id = args.get("terminal_id")
    session_name = args.get("session_name", f"zellij-{int(time.time())}")
    layout_path = args.get("layout_path")

    if not terminal_id:
        return {
            "content": [{"type": "text", "text": "Error: terminal_id is required"}]
        }

    session = terminal_manager.get_session(terminal_id)
    if not session:
        return {
            "content": [{"type": "text", "text": f"Error: Terminal session '{terminal_id}' not found"}]
        }

    # Generate Zellij command
    zellij_cmd = ZellijController.start_session(session_name, layout_path, session.cwd)

    # Send command to terminal
    success, output = MacTerminalController.send_command(session.window_id, zellij_cmd)

    if success:
        terminal_manager.update_session(terminal_id, zellij_session=session_name)
        result_text = f"Zellij session started\nTerminal ID: {terminal_id}\nSession Name: {session_name}\nLayout: {layout_path or 'default'}"
    else:
        result_text = f"Failed to start Zellij: {output}"

    return {
        "content": [{"type": "text", "text": result_text}]
    }

def handle_zellij_action(args: Dict) -> Dict:
    """Handle zellij_action tool call"""
    terminal_id = args.get("terminal_id")
    action = args.get("action")
    action_args = args.get("action_args", {})

    if not terminal_id:
        return {
            "content": [{"type": "text", "text": "Error: terminal_id is required"}]
        }

    session = terminal_manager.get_session(terminal_id)
    if not session or not session.zellij_session:
        return {
            "content": [{"type": "text", "text": f"Error: No Zellij session for terminal '{terminal_id}'"}]
        }

    success = False
    output = ""

    if action == "dump-layout":
        success, output = ZellijController.dump_layout(session.zellij_session)
    elif action == "write-chars":
        text = action_args.get("text", "")
        pane_id = action_args.get("pane_id")
        success, output = ZellijController.write_chars(session.zellij_session, text, pane_id)
    elif action == "new-pane":
        direction = action_args.get("direction")
        cwd = action_args.get("cwd")
        success, output = ZellijController.new_pane(session.zellij_session, direction, cwd)
    elif action == "list-sessions":
        success, output = ZellijController.list_sessions()
    else:
        return {
            "content": [{"type": "text", "text": f"Error: Unknown action '{action}'"}]
        }

    result_text = f"Zellij action executed\nAction: {action}\nSuccess: {success}\nOutput:\n{output}"

    return {
        "content": [{"type": "text", "text": result_text}]
    }

def handle_capture_state(args: Dict) -> Dict:
    """Handle capture_state tool call"""
    terminal_id = args.get("terminal_id")

    if not terminal_id:
        return {
            "content": [{"type": "text", "text": "Error: terminal_id is required"}]
        }

    session = terminal_manager.get_session(terminal_id)
    if not session:
        return {
            "content": [{"type": "text", "text": f"Error: Terminal session '{terminal_id}' not found"}]
        }

    results = []

    # Capture Zellij layout if session exists
    if session.zellij_session and session.window_id:
        # Use workaround: inject dump command into terminal, write to temp file, then read
        import tempfile
        temp_file = tempfile.mktemp(suffix=".kdl", prefix="zellij_layout_")

        # Use write-chars to inject the command into the current pane
        dump_cmd = f"zellij action dump-layout > {temp_file}\n"
        success, msg = ZellijController.write_chars(session.zellij_session, dump_cmd)

        if not success:
            results.append(f"Failed to inject dump command: {msg}")
        else:
            # Wait for file to be created
            time.sleep(0.8)

            # Read the temp file
            try:
                if os.path.exists(temp_file):
                    with open(temp_file, 'r') as f:
                        layout_kdl = f.read()

                    if layout_kdl:
                        parsed = ZellijController.parse_layout(layout_kdl)
                        results.append(f"=== Zellij Layout State ===")
                        results.append(f"Session: {session.zellij_session}")
                        results.append(f"Tabs: {', '.join(parsed['tabs']) if parsed['tabs'] else 'default'}")
                        results.append(f"Panes: {', '.join(parsed['panes']) if parsed['panes'] else 'unnamed'}")
                        results.append(f"Total Pane Count: {parsed['pane_count']}")
                        results.append(f"\nRaw Layout:\n{layout_kdl[:2000]}")  # Limit to first 2000 chars
                    else:
                        results.append("Failed to capture layout: Empty output")

                    # Clean up temp file
                    os.remove(temp_file)
                else:
                    results.append(f"Failed to capture layout: Temp file not created at {temp_file}")
            except Exception as e:
                results.append(f"Failed to read layout: {str(e)}")

    # Capture terminal content
    if session.window_id:
        success, content = MacTerminalController.get_window_content(session.window_id)
        if success:
            results.append(f"\n=== Terminal Content ===")
            results.append(content[:1000])  # Limit to first 1000 chars
        else:
            results.append(f"\nFailed to get terminal content: {content}")

    return {
        "content": [{"type": "text", "text": "\n".join(results)}]
    }

def handle_list_terminals(args: Dict) -> Dict:
    """Handle list_terminals tool call"""
    sessions = terminal_manager.list_sessions()

    if not sessions:
        return {
            "content": [{"type": "text", "text": "No active terminal sessions"}]
        }

    results = ["=== Active Terminal Sessions ===\n"]
    for session in sessions:
        results.append(f"Terminal ID: {session.terminal_id}")
        results.append(f"  Window ID: {session.window_id or 'N/A'}")
        results.append(f"  Zellij Session: {session.zellij_session or 'N/A'}")
        results.append(f"  CWD: {session.cwd}")
        results.append(f"  Created: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(session.created_at))}")
        results.append("")

    return {
        "content": [{"type": "text", "text": "\n".join(results)}]
    }

def main():
    """Main MCP server loop"""
    # Read initialize request
    line = sys.stdin.readline()
    request = json.loads(line)

    if request.get("method") == "initialize":
        response = {
            "jsonrpc": "2.0",
            "id": request["id"],
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "tty-terminal",
                    "version": "2.0.0"
                }
            }
        }
        print(json.dumps(response), flush=True)

        # Read initialized notification
        line = sys.stdin.readline()

        # Main loop
        while True:
            line = sys.stdin.readline()
            if not line:
                break

            request = json.loads(line)
            method = request.get("method")

            if method == "tools/list":
                response = {
                    "jsonrpc": "2.0",
                    "id": request["id"],
                    "result": {
                        "tools": [
                            {
                                "name": "open_terminal",
                                "description": "Open a new terminal window and return a persistent handle",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "cwd": {
                                            "type": "string",
                                            "description": "Working directory"
                                        }
                                    }
                                }
                            },
                            {
                                "name": "send_command",
                                "description": "Send a command to a specific terminal by ID",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "terminal_id": {
                                            "type": "string",
                                            "description": "Terminal ID from open_terminal"
                                        },
                                        "command": {
                                            "type": "string",
                                            "description": "Command to execute"
                                        }
                                    },
                                    "required": ["terminal_id", "command"]
                                }
                            },
                            {
                                "name": "start_zellij_session",
                                "description": "Start a Zellij session in a terminal with optional layout",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "terminal_id": {
                                            "type": "string",
                                            "description": "Terminal ID to start Zellij in"
                                        },
                                        "session_name": {
                                            "type": "string",
                                            "description": "Zellij session name (auto-generated if not provided)"
                                        },
                                        "layout_path": {
                                            "type": "string",
                                            "description": "Path to Zellij layout file (optional)"
                                        }
                                    },
                                    "required": ["terminal_id"]
                                }
                            },
                            {
                                "name": "zellij_action",
                                "description": "Execute Zellij actions (dump-layout, write-chars, new-pane, list-sessions)",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "terminal_id": {
                                            "type": "string",
                                            "description": "Terminal ID with active Zellij session"
                                        },
                                        "action": {
                                            "type": "string",
                                            "enum": ["dump-layout", "write-chars", "new-pane", "list-sessions"],
                                            "description": "Zellij action to perform"
                                        },
                                        "action_args": {
                                            "type": "object",
                                            "description": "Action-specific arguments (text, pane_id, direction, cwd)"
                                        }
                                    },
                                    "required": ["terminal_id", "action"]
                                }
                            },
                            {
                                "name": "capture_state",
                                "description": "Capture and parse Zellij layout state and terminal content for verification",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "terminal_id": {
                                            "type": "string",
                                            "description": "Terminal ID to capture state from"
                                        }
                                    },
                                    "required": ["terminal_id"]
                                }
                            },
                            {
                                "name": "list_terminals",
                                "description": "List all managed terminal sessions",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {}
                                }
                            }
                        ]
                    }
                }
                print(json.dumps(response), flush=True)

            elif method == "tools/call":
                tool_name = request["params"]["name"]
                args = request["params"].get("arguments", {})

                # Route to appropriate handler
                handlers = {
                    "open_terminal": handle_open_terminal,
                    "send_command": handle_send_command,
                    "start_zellij_session": handle_start_zellij,
                    "zellij_action": handle_zellij_action,
                    "capture_state": handle_capture_state,
                    "list_terminals": handle_list_terminals
                }

                if tool_name in handlers:
                    result = handlers[tool_name](args)
                else:
                    result = {
                        "content": [{"type": "text", "text": f"Unknown tool: {tool_name}"}]
                    }

                response = {
                    "jsonrpc": "2.0",
                    "id": request["id"],
                    "result": result
                }
                print(json.dumps(response), flush=True)

if __name__ == "__main__":
    main()
