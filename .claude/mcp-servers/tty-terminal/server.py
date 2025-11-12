#!/usr/bin/env python3
"""
MCP Server for TTY Terminal Access
Allows Claude Code to open real terminals and run interactive commands
"""

import asyncio
import json
import os
import pty
import select
import subprocess
import sys
from typing import Any, Dict, Optional

# MCP Protocol messages
class MCPServer:
    def __init__(self):
        self.terminals: Dict[str, Any] = {}
        self.terminal_counter = 0

    async def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle incoming MCP requests"""
        method = request.get("method")
        params = request.get("params", {})

        if method == "tools/list":
            return self.list_tools()
        elif method == "tools/call":
            return await self.call_tool(params)
        else:
            return {"error": {"code": -32601, "message": f"Method not found: {method}"}}

    def list_tools(self) -> Dict[str, Any]:
        """List available tools"""
        return {
            "tools": [
                {
                    "name": "tty_open",
                    "description": "Open a new TTY terminal session",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "shell": {
                                "type": "string",
                                "description": "Shell to use (default: bash)",
                                "default": "bash"
                            },
                            "cwd": {
                                "type": "string",
                                "description": "Working directory (default: current)",
                                "default": os.getcwd()
                            }
                        }
                    }
                },
                {
                    "name": "tty_exec",
                    "description": "Execute a command in an open TTY terminal",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "terminal_id": {
                                "type": "string",
                                "description": "Terminal ID from tty_open"
                            },
                            "command": {
                                "type": "string",
                                "description": "Command to execute"
                            },
                            "timeout": {
                                "type": "number",
                                "description": "Timeout in seconds (default: 30)",
                                "default": 30
                            }
                        },
                        "required": ["terminal_id", "command"]
                    }
                },
                {
                    "name": "tty_read",
                    "description": "Read output from a TTY terminal",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "terminal_id": {
                                "type": "string",
                                "description": "Terminal ID"
                            },
                            "timeout": {
                                "type": "number",
                                "description": "Timeout in seconds (default: 5)",
                                "default": 5
                            }
                        },
                        "required": ["terminal_id"]
                    }
                },
                {
                    "name": "tty_close",
                    "description": "Close a TTY terminal session",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "terminal_id": {
                                "type": "string",
                                "description": "Terminal ID to close"
                            }
                        },
                        "required": ["terminal_id"]
                    }
                },
                {
                    "name": "tty_list",
                    "description": "List all open TTY terminals",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                }
            ]
        }

    async def call_tool(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a tool"""
        tool_name = params.get("name")
        arguments = params.get("arguments", {})

        try:
            if tool_name == "tty_open":
                return await self.tty_open(arguments)
            elif tool_name == "tty_exec":
                return await self.tty_exec(arguments)
            elif tool_name == "tty_read":
                return await self.tty_read(arguments)
            elif tool_name == "tty_close":
                return await self.tty_close(arguments)
            elif tool_name == "tty_list":
                return await self.tty_list(arguments)
            else:
                return {
                    "content": [
                        {
                            "type": "text",
                            "text": f"Unknown tool: {tool_name}"
                        }
                    ],
                    "isError": True
                }
        except Exception as e:
            return {
                "content": [
                    {
                        "type": "text",
                        "text": f"Error executing {tool_name}: {str(e)}"
                    }
                ],
                "isError": True
            }

    async def tty_open(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Open a new TTY terminal"""
        shell = args.get("shell", "bash")
        cwd = args.get("cwd", os.getcwd())

        # Create a new pseudo-terminal
        master_fd, slave_fd = pty.openpty()

        # Start the shell process
        process = subprocess.Popen(
            [shell],
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            cwd=cwd,
            preexec_fn=os.setsid,
            env=os.environ.copy()
        )

        # Close slave fd in parent (process has it)
        os.close(slave_fd)

        # Generate terminal ID
        self.terminal_counter += 1
        terminal_id = f"tty-{self.terminal_counter}"

        # Store terminal info
        self.terminals[terminal_id] = {
            "master_fd": master_fd,
            "process": process,
            "shell": shell,
            "cwd": cwd,
            "buffer": ""
        }

        # Give it a moment to start
        await asyncio.sleep(0.1)

        # Read initial output (prompt, etc.)
        initial_output = self._read_available(master_fd, timeout=0.5)

        return {
            "content": [
                {
                    "type": "text",
                    "text": f"TTY Terminal opened: {terminal_id}\nShell: {shell}\nCWD: {cwd}\n\nInitial output:\n{initial_output}"
                }
            ]
        }

    async def tty_exec(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute command in TTY"""
        terminal_id = args["terminal_id"]
        command = args["command"]
        timeout = args.get("timeout", 30)

        if terminal_id not in self.terminals:
            return {
                "content": [{"type": "text", "text": f"Terminal not found: {terminal_id}"}],
                "isError": True
            }

        terminal = self.terminals[terminal_id]
        master_fd = terminal["master_fd"]

        # Clear buffer
        self._read_available(master_fd, timeout=0.1)

        # Write command
        os.write(master_fd, f"{command}\n".encode())

        # Wait a bit for command to execute
        await asyncio.sleep(0.5)

        # Read output
        output = self._read_available(master_fd, timeout=timeout)

        return {
            "content": [
                {
                    "type": "text",
                    "text": f"Command: {command}\n\nOutput:\n{output}"
                }
            ]
        }

    async def tty_read(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Read from TTY"""
        terminal_id = args["terminal_id"]
        timeout = args.get("timeout", 5)

        if terminal_id not in self.terminals:
            return {
                "content": [{"type": "text", "text": f"Terminal not found: {terminal_id}"}],
                "isError": True
            }

        terminal = self.terminals[terminal_id]
        output = self._read_available(terminal["master_fd"], timeout=timeout)

        return {
            "content": [
                {
                    "type": "text",
                    "text": output if output else "(no output)"
                }
            ]
        }

    async def tty_close(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Close TTY terminal"""
        terminal_id = args["terminal_id"]

        if terminal_id not in self.terminals:
            return {
                "content": [{"type": "text", "text": f"Terminal not found: {terminal_id}"}],
                "isError": True
            }

        terminal = self.terminals[terminal_id]

        # Close the terminal
        os.close(terminal["master_fd"])
        terminal["process"].terminate()
        terminal["process"].wait(timeout=5)

        del self.terminals[terminal_id]

        return {
            "content": [
                {
                    "type": "text",
                    "text": f"Terminal closed: {terminal_id}"
                }
            ]
        }

    async def tty_list(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """List open terminals"""
        if not self.terminals:
            return {
                "content": [
                    {
                        "type": "text",
                        "text": "No open terminals"
                    }
                ]
            }

        info = []
        for tid, term in self.terminals.items():
            status = "running" if term["process"].poll() is None else "stopped"
            info.append(f"{tid}: {term['shell']} ({status}) in {term['cwd']}")

        return {
            "content": [
                {
                    "type": "text",
                    "text": "\n".join(info)
                }
            ]
        }

    def _read_available(self, fd: int, timeout: float = 1.0) -> str:
        """Read all available data from fd"""
        output = ""
        end_time = asyncio.get_event_loop().time() + timeout

        while asyncio.get_event_loop().time() < end_time:
            # Check if data is available
            ready, _, _ = select.select([fd], [], [], 0.1)
            if ready:
                try:
                    chunk = os.read(fd, 4096).decode('utf-8', errors='replace')
                    if chunk:
                        output += chunk
                    else:
                        break
                except OSError:
                    break
            else:
                # No more data immediately available
                if output:
                    # Give a short grace period
                    ready, _, _ = select.select([fd], [], [], 0.1)
                    if not ready:
                        break

        return output

    async def run(self):
        """Run the MCP server"""
        # Read from stdin, write to stdout (MCP stdio transport)
        reader = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(reader)
        await asyncio.get_event_loop().connect_read_pipe(lambda: protocol, sys.stdin)

        writer_transport, writer_protocol = await asyncio.get_event_loop().connect_write_pipe(
            asyncio.streams.FlowControlMixin, sys.stdout
        )
        writer = asyncio.StreamWriter(writer_transport, writer_protocol, reader, asyncio.get_event_loop())

        while True:
            try:
                # Read JSON-RPC message
                line = await reader.readline()
                if not line:
                    break

                request = json.loads(line.decode())
                response = await self.handle_request(request)
                response["jsonrpc"] = "2.0"
                response["id"] = request.get("id")

                # Write response
                writer.write((json.dumps(response) + "\n").encode())
                await writer.drain()

            except Exception as e:
                error_response = {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {
                        "code": -32603,
                        "message": f"Internal error: {str(e)}"
                    }
                }
                writer.write((json.dumps(error_response) + "\n").encode())
                await writer.drain()

if __name__ == "__main__":
    server = MCPServer()
    asyncio.run(server.run())
