# Zellij Pipes for Inter-Pane Communication

## Overview

Zellij pipes enable unidirectional communication channels between panes and plugins. Pipes transmit serializable text messages and are particularly useful for:
- Sending data from CLI commands to visual plugins
- Plugin-to-plugin communication
- Building interactive dashboards
- Creating data processing pipelines

## Pipe Architecture

```
┌─────────────┐
│   Source    │  (CLI, Plugin, or Pane)
│   Pane      │
└──────┬──────┘
       │
       │ Pipe Message
       │ { name, payload, args }
       │
       ▼
┌─────────────┐
│ Destination │  (Plugin or broadcast)
│   Plugin    │
└─────────────┘
```

## Pipe Message Structure

All pipe messages contain three optional components:

```rust
{
    name: String,        // Arbitrary identifier or UUID
    payload: String,     // Serializable content
    args: HashMap<String, String>  // Key-value metadata
}
```

## Pipe Destinations

### Specific Plugin
Target a plugin by URL and configuration:
```
destination: "https://example.com/my-plugin.wasm"
configuration: { key: "value" }
```

### Broadcast (No Destination)
When no destination is specified, messages are broadcast to **all plugins** that implement the `pipe` lifecycle method.

**Use Case**: Convention-based communication (e.g., all plugins listening for "notification" pipe)

### Plugin-to-Plugin
Plugins can send messages to other specific plugins using their internal Zellij ID.

**Use Case**: Multi-instance plugin communication, creating plugin pipelines

### Special Destination: `zellij:OWN_URL`
Allows plugins to launch new instances of themselves with unique configurations.

**Use Case**: Preventing message loops while enabling self-spawning

## Creating Pipes

### From CLI

Send messages to plugins from the command line:

```bash
# Basic pipe
echo "Hello World" | zellij pipe my-pipe-name

# With arguments
echo '{"data": "value"}' | zellij pipe my-pipe-name --plugin "file:/path/to/plugin.wasm" --args key1=value1 --args key2=value2

# Broadcast to all plugins
echo "notification: Build complete" | zellij pipe notifications
```

### From Keybindings

Configure keybindings to trigger pipes:

```kdl
keybindings {
    normal {
        bind "Ctrl p" {
            pipe {
                name "status-update"
                payload "refresh"
            }
        }
    }
}
```

### From Plugins

Plugins can send messages to other plugins programmatically:

```rust
// In your plugin code
pipe_message_to_plugin(
    destination_plugin_id,
    "message-name",
    "payload content",
    Some(hashmap!{"arg1" => "value1"})
);
```

## Receiving Pipe Messages

Plugins implement the `pipe` lifecycle method:

```rust
impl ZellijPlugin for MyPlugin {
    fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
        // pipe_message contains:
        // - name: String
        // - payload: String
        // - args: HashMap<String, String>
        // - source: PipeSource (plugin ID or CLI)

        match pipe_message.name.as_str() {
            "update-data" => {
                self.data = pipe_message.payload;
                true  // Request re-render
            }
            "refresh" => {
                self.fetch_latest();
                true  // Request re-render
            }
            _ => false  // No re-render needed
        }
    }
}
```

**Return Value:**
- `true`: Zellij should re-render the plugin
- `false`: No re-render needed

## Flow Control (CLI Pipes)

Plugins can apply backpressure to CLI pipes:

### Block Input
```rust
// Pause CLI pipe input
self.block_cli_pipe_input(&pipe_name);
```

### Unblock Input
```rust
// Resume CLI pipe input
self.unblock_cli_pipe_input(&pipe_name);
```

### Output to CLI
```rust
// Send data back to CLI stdout
self.cli_pipe_output(&pipe_name, "output data");
```

**Use Case**: Processing large data streams, rate limiting, interactive workflows

## Practical Examples

### Example 1: Log Viewer

**CLI Side:**
```bash
# Stream logs to a viewer plugin
tail -f /var/log/app.log | zellij pipe log-stream --plugin "file:~/plugins/log-viewer.wasm"
```

**Plugin Side:**
```rust
fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
    if pipe_message.name == "log-stream" {
        self.log_lines.push(pipe_message.payload);
        true  // Re-render to show new log line
    } else {
        false
    }
}
```

### Example 2: Kubernetes Event Monitor

**CLI Side:**
```bash
# Watch Kubernetes events and pipe to dashboard
kubectl get events --watch -o json | zellij pipe k8s-events --plugin "file:~/plugins/k8s-dashboard.wasm"
```

**Plugin Side:**
```rust
fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
    if pipe_message.name == "k8s-events" {
        let event: K8sEvent = serde_json::from_str(&pipe_message.payload).unwrap();
        self.events.push(event);
        true
    } else {
        false
    }
}
```

### Example 3: Multi-Context K8s Dashboard (Holocron Q3 → Q4)

**Q3 Pane (k9s):**
```bash
# Script that watches cluster events and pipes them
kubectl --context prod-eks get pods --watch -o json | \
    zellij pipe cluster-events --args context=prod-eks
```

**Q4 Pane (Dashboard Plugin):**
```rust
fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
    match pipe_message.name.as_str() {
        "cluster-events" => {
            let context = pipe_message.args.get("context").unwrap();
            let event = pipe_message.payload;

            self.cluster_data
                .entry(context.clone())
                .or_insert(Vec::new())
                .push(event);

            true  // Re-render dashboard
        }
        _ => false
    }
}
```

### Example 4: Build Status Notifier

**Keybinding in config.kdl:**
```kdl
keybindings {
    normal {
        bind "Ctrl b" {
            pipe {
                name "trigger-build"
            }
        }
    }
}
```

**Build Script:**
```bash
#!/bin/bash
# Listen for build triggers
zellij pipe trigger-build | while read -r line; do
    cargo build && \
        zellij pipe build-status --payload "success" || \
        zellij pipe build-status --payload "failed"
done
```

**Status Plugin:**
```rust
fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
    match pipe_message.name.as_str() {
        "build-status" => {
            self.last_build_status = pipe_message.payload;
            true
        }
        _ => false
    }
}
```

## Pipe Naming Conventions

For Holocron and general best practices:

- **cluster-{context-name}-events**: K8s cluster event streams
- **cluster-{context-name}-metrics**: Cluster metrics
- **repo-{name}-status**: Repository status updates
- **build-{project}-output**: Build tool output
- **notification**: Global notifications (broadcast)
- **command-{name}**: User-triggered commands

## Integration with Holocron Layout

In Holocron's Hyperpod layout, pipes connect Q3 (K8s monitoring) to Q4 (utilities):

```kdl
layout {
    tab name="Hyperpod" {
        // Q3: K8s Monitoring Pane
        pane {
            name "Prod EKS"
            command "bash"
            args "-c" "kubectl --context prod-eks get events --watch -o json | zellij pipe cluster-prod-eks-events"
        }

        // Q4: Utilities Pane (would run a plugin listening to pipes)
        pane {
            plugin location="file:~/.config/zellij/plugins/cluster-dashboard.wasm"
        }
    }
}
```

## Troubleshooting Pipes

### Messages not received
- Verify plugin implements `pipe()` lifecycle method
- Check pipe name matches exactly (case-sensitive)
- Ensure plugin is loaded and running
- Use broadcast first to test reception

### CLI pipe hangs
- Plugin may have applied backpressure with `block_cli_pipe_input`
- Check plugin logs for errors
- Verify pipe destination is correct

### Too many messages
- Implement debouncing in plugin
- Use backpressure to rate limit
- Filter messages by name or args

### Message format errors
- Validate JSON payloads with serde
- Check argument keys exist before accessing
- Handle parse errors gracefully

## Best Practices

1. **Name pipes clearly**: Use descriptive, namespaced names
2. **Structure payloads**: Use JSON for complex data
3. **Use args for metadata**: Context, timestamp, source info
4. **Handle errors gracefully**: Invalid messages shouldn't crash plugins
5. **Rate limit**: Apply backpressure for high-volume streams
6. **Document conventions**: Team should agree on pipe names and formats
7. **Test incrementally**: Start with broadcast, then narrow to specific plugins
8. **Version messages**: Include version field in payload for compatibility

## Limitations

- **Unidirectional**: Pipes only send one way (use separate pipes for two-way)
- **No guarantees**: Messages may be lost if plugin isn't ready
- **Text only**: Binary data must be encoded (base64, hex)
- **Plugin dependency**: Requires plugin to receive messages
- **No queuing**: Messages aren't buffered if plugin is slow

## Future Enhancements (Potential)

- Bidirectional pipes
- Message acknowledgment
- Persistent message queues
- Binary message support
- Pipe discovery/introspection
- Pipe middleware/filters
