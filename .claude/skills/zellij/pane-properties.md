# Zellij Pane Properties Reference

## Layout Properties

### split_direction
- **Type**: String
- **Values**: `"vertical"` | `"horizontal"`
- **Default**: `"horizontal"`
- **Description**: Controls how child panes are arranged
  - `"horizontal"`: Stacks children vertically (top/bottom)
  - `"vertical"`: Places children side by side (left/right)

```kdl
pane split_direction="vertical" {
    pane size="50%"  // Left
    pane size="50%"  // Right
}
```

### size
- **Type**: String
- **Values**: Percentage (`"50%"`) or fixed pixels (`"80"`)
- **Default**: Flexible (shares remaining space)
- **Description**: Defines how much space the pane occupies

```kdl
pane size="70%"  // Takes 70% of parent
pane size="100"  // Takes 100 pixels (not recommended)
```

### borderless
- **Type**: Boolean
- **Values**: `true` | `false`
- **Default**: `false`
- **Description**: Removes the pane's border/frame

```kdl
pane borderless=true {
    // Borderless pane
}
```

### stacked
- **Type**: Boolean
- **Values**: `true` | `false`
- **Default**: `false`
- **Description**: Arranges children in an overlapping stack where only one pane is fully visible

```kdl
pane {
    stacked true
    pane expanded=true name="Visible"
    pane name="Hidden1"
    pane name="Hidden2"
}
```

### expanded
- **Type**: Boolean
- **Values**: `true` | `false`
- **Default**: `false`
- **Description**: In a stacked container, marks which pane is initially visible
- **Note**: Only used within `stacked` parent, first `expanded` pane wins if multiple specified

```kdl
pane stacked=true {
    pane expanded=true  // This one shows
    pane                // Hidden
}
```

## Content Properties

### command
- **Type**: String
- **Description**: Specifies an executable to run in the pane
- **Note**: Must be in PATH or use absolute path

```kdl
pane {
    command "nvim"
}

pane {
    command "/usr/local/bin/k9s"
}
```

### args
- **Type**: String or Array (in child braces)
- **Description**: Arguments passed to the command
- **Note**: Must be wrapped in child braces when used with pane

```kdl
pane {
    command "tail"
    args "-f" "/var/log/system.log"
}

pane {
    command "kubectl"
    args "get" "pods" "--watch"
}
```

### edit
- **Type**: String (file path)
- **Description**: Opens a file in the configured $EDITOR or default editor
- **Note**: Mutually exclusive with `command`

```kdl
pane {
    edit "README.md"
}

pane {
    edit "/path/to/config.yaml"
}
```

### plugin
- **Type**: String (URL or path)
- **Description**: Loads a Zellij plugin (WebAssembly)
- **Note**: Can be URL or file path

```kdl
pane {
    plugin location="zellij:tab-bar"
}

pane {
    plugin location="file:/path/to/plugin.wasm"
}
```

### cwd
- **Type**: String (directory path)
- **Description**: Sets the current working directory for the pane
- **Note**: Can be relative or absolute, composes hierarchically

```kdl
pane cwd="/home/user/project" {
    // Commands run from this directory
}

// Relative path composition
layout cwd="/home/user" {
    tab cwd="projects" {
        pane cwd="app" {
            // Final CWD: /home/user/projects/app
        }
    }
}
```

## Behavior Properties

### focus
- **Type**: Boolean
- **Values**: `true` | `false`
- **Default**: `false`
- **Description**: Designates which pane receives focus on startup
- **Note**: First pane with `focus=true` wins if multiple specified

```kdl
pane focus=true {
    // This pane is focused on startup
}
```

### name
- **Type**: String
- **Description**: Custom title displayed in pane header
- **Note**: Useful for identification and navigation

```kdl
pane name="Editor" {
    edit "main.rs"
}

pane name="Build Output" {
    command "cargo" args "watch"
}
```

### close_on_exit
- **Type**: Boolean
- **Values**: `true` | `false`
- **Default**: `true`
- **Description**: Closes the pane when the command exits
- **Note**: Set to `false` to keep pane open after command completes

```kdl
pane {
    command "cargo" args "build"
    close_on_exit false  // Keep pane open to view output
}
```

### start_suspended
- **Type**: Boolean
- **Values**: `true` | `false`
- **Default**: `false`
- **Description**: Delays command execution until user presses Enter
- **Note**: Useful for commands that need user interaction or careful timing

```kdl
pane {
    command "cargo" args "test"
    start_suspended true  // Wait for user to press Enter
}
```

## Property Combinations

### Code Repository Pane
```kdl
pane {
    name "Main Repo"
    cwd "~/projects/main"
    focus true
}
```

### Long-Running Command with Output
```kdl
pane {
    name "Server"
    command "npm" args "run" "dev"
    close_on_exit false
    cwd "~/projects/app"
}
```

### Stacked Repository Views
```kdl
pane {
    stacked true
    pane {
        expanded true
        name "Repo 1"
        cwd "~/driving"
    }
    pane {
        name "Repo 2"
        cwd "~/k8s"
    }
    pane {
        name "Repo 3"
        cwd "~/k8s-deploy"
    }
}
```

### Kubernetes Context Pane
```kdl
pane {
    name "Prod EKS"
    command "k9s"
    args "--context" "prod-eks-cluster"
    close_on_exit false
}
```

### Suspended Build Task
```kdl
pane {
    name "Build"
    command "make" args "all"
    start_suspended true
    close_on_exit false
}
```

## CWD (Current Working Directory) Resolution

Paths compose hierarchically from global to specific:

1. **Execution directory** (where zellij was launched)
2. **Global layout `cwd`** (top-level in layout block)
3. **Tab-level `cwd`** (in tab block)
4. **Pane-level `cwd`** (in pane block)

**Rules:**
- Relative paths combine with parent paths
- Absolute paths override all parent paths
- Missing `cwd` inherits from parent or execution directory

**Example:**
```kdl
layout cwd="/home/user" {
    tab cwd="projects" {
        pane cwd="app" {
            // Resolved CWD: /home/user/projects/app
        }
        pane cwd="/tmp" {
            // Resolved CWD: /tmp (absolute overrides)
        }
    }
}
```

## Property Priority

When properties conflict:
1. More specific beats generic (pane > tab > layout > default)
2. First occurrence wins for boolean flags (focus, expanded)
3. Explicit values override defaults

## Common Mistakes

1. **Using `command` and `edit` together** - They're mutually exclusive
2. **Forgetting `expanded=true` in stacked panes** - Nothing will be visible
3. **Using tabs in string values** - KDL doesn't allow tabs
4. **Missing `stacked=true` with `expanded`** - `expanded` only works in stacked containers
5. **Percentage sizes not summing to 100%** - Can cause layout issues
6. **Relative paths without understanding composition** - Check full resolved path
