#!/usr/bin/env python3
"""
Simple MCP Server for opening a TTY terminal and running commands
"""
import json
import sys
import subprocess
import os
import tempfile
import time

def main():
    """Simple stdio MCP server"""
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
                    "version": "1.0.0"
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
                                "description": "Open a new terminal window",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "cwd": {
                                            "type": "string",
                                            "description": "Working directory"
                                        }
                                    }
                                }
                            }
                        ]
                    }
                }
                print(json.dumps(response), flush=True)

            elif method == "tools/call":
                tool_name = request["params"]["name"]
                args = request["params"].get("arguments", {})

                if tool_name == "open_terminal":
                    cwd = args.get("cwd", "/Users/mayankketkar/claude-tools/tmux")

                    # Open terminal using macOS 'open' command
                    try:
                        subprocess.Popen(
                            ["open", "-a", "Terminal", cwd],
                            start_new_session=True
                        )
                        result_text = f"Terminal opened in: {cwd}"
                    except Exception as e:
                        result_text = f"Error: {str(e)}"

                    response = {
                        "jsonrpc": "2.0",
                        "id": request["id"],
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": result_text
                                }
                            ]
                        }
                    }
                    print(json.dumps(response), flush=True)

if __name__ == "__main__":
    main()
