---
name: zellij
description: Expert knowledge for building Zellij terminal workspace layouts, templates, configurations, and plugins. Use this skill when working with Zellij layout files (KDL), creating terminal multiplexer setups, configuring panes, tabs, pipes, or any Zellij-related development tasks.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Zellij Terminal Workspace Expert

## Purpose

This skill provides comprehensive expertise for building, configuring, and managing Zellij terminal workspaces. Use this skill whenever working with Zellij layouts, configurations, or terminal workspace automation.

## When to Use This Skill

- Creating or modifying Zellij layout files (.kdl)
- Building terminal workspace templates
- Configuring panes, tabs, and terminal splits
- Setting up Zellij pipes for inter-pane communication
- Troubleshooting Zellij configurations
- Optimizing developer workspace setups
- Creating portable terminal environments

## Core Instructions

### CRITICAL RULES

1. **ALL Zellij development MUST use this skill** - Never attempt to create Zellij configurations without referencing this skill's knowledge base
2. **Always use KDL format** - Zellij uses KDL (Kiss Document Language), not YAML or JSON
3. **Validate syntax** - KDL requires proper indentation, no tabs in values, valid `---` delimiters
4. **Test layouts** - Always provide commands to test the generated layouts
5. **Use templates** - Leverage pane_template and tab_template for reusable components

### Layout File Structure

All Zellij layouts follow this structure:

```kdl
layout {
    // Global settings
    default_tab_template {
        // Tab template configuration
        children
    }

    tab name="TabName" {
        // Tab-specific configuration
        pane {
            // Pane configuration
        }
    }
}
```

### Pane Configuration Properties

Reference the [pane-properties.md](pane-properties.md) file for comprehensive details on:

- **Layout properties**: `split_direction`, `size`, `borderless`, `stacked`, `expanded`
- **Content properties**: `command`, `args`, `edit`, `plugin`, `cwd`
- **Behavior properties**: `focus`, `name`, `close_on_exit`, `start_suspended`

### Creating Stacked Panes

For multiple overlapping panes (only one visible at a time):

```kdl
pane {
    stacked true
    pane {
        expanded true  // This pane is initially visible
        name "Primary"
        cwd "/path/to/dir"
    }
    pane {
        name "Secondary"
        cwd "/another/path"
    }
    pane {
        name "Tertiary"
        cwd "/third/path"
    }
}
```

### Using Pane Templates

Create reusable pane configurations:

```kdl
pane_template name="repo-pane" {
    command "bash"
    start_suspended false
}

// Usage
layout {
    tab {
        pane {
            stacked true
            repo-pane name="Repo1" cwd="~/repo1"
            repo-pane name="Repo2" cwd="~/repo2"
        }
    }
}
```

### Configuring Pipes

For inter-pane communication, see [pipes.md](pipes.md):

```kdl
pane {
    name "source-pane"
    // Pane that sends messages
}

pane {
    name "receiver-pane"
    // Pane that receives pipe messages
}
```

### Split Directions and Sizing

**Horizontal splits** (side by side):
```kdl
pane split_direction="vertical" {
    pane size="50%"
    pane size="50%"
}
```

**Vertical splits** (top and bottom):
```kdl
pane split_direction="horizontal" {
    pane size="80%"
    pane size="20%"
}
```

### Working Directory (CWD) Composition

Paths are composed hierarchically:
1. Pane-level `cwd`
2. Tab-level `cwd`
3. Global layout `cwd`
4. Execution directory

Relative paths combine; absolute paths override.

### Testing Layouts

Always provide test commands:

```bash
# Test layout
zellij --layout path/to/layout.kdl

# Dump default layout for reference
zellij setup --dump-layout default

# Validate KDL syntax
# (KDL doesn't have native validator, but Zellij will error on invalid syntax)
```

## Best Practices

1. **Start simple**: Build layouts incrementally, test each addition
2. **Use templates**: Reduce duplication with pane_template and tab_template
3. **Name everything**: Use `name` property for all panes and tabs
4. **Percentage sizing**: Prefer percentage sizes over fixed pixels for portability
5. **CWD per pane**: Set working directory explicitly for consistency
6. **Comment liberally**: KDL supports `//` comments, use them
7. **Version control**: Store layouts in git for team sharing
8. **Document setup**: Include README with dependencies and setup steps

## Common Patterns

### Development Workspace

```kdl
layout {
    tab name="Development" {
        pane split_direction="vertical" {
            pane size="70%" {
                // Editor
                edit "main.rs"
            }
            pane split_direction="horizontal" size="30%" {
                pane size="70%" {
                    // Build/test output
                    name "Output"
                }
                pane size="30%" {
                    // Logs
                    name "Logs"
                }
            }
        }
    }
}
```

### Kubernetes Monitoring

```kdl
pane_template name="k9s-pane" {
    command "k9s"
    args "--context"
}

layout {
    tab name="K8s" {
        pane {
            stacked true
            k9s-pane name="Prod" args "prod-context"
            k9s-pane name="Dev" args "dev-context"
        }
    }
}
```

## Troubleshooting

### Layout not loading
- Check KDL syntax (proper braces, no tabs in strings)
- Verify file paths are absolute or relative to execution directory
- Ensure Zellij version supports features used
- Check for typos in property names

### Panes not appearing
- Verify `split_direction` is set correctly
- Check size percentages sum to 100% (or use flexible sizing)
- Ensure `stacked` panes have at least one `expanded: true`

### Commands not running
- Verify command is in PATH
- Check `args` are in child braces
- Use `start_suspended: false` if needed
- Test command in regular shell first

### CWD not working
- Use absolute paths for clarity
- Check directory exists
- Verify permissions

## Reference Files

- [pane-properties.md](pane-properties.md) - Complete pane property reference
- [pipes.md](pipes.md) - Pipe configuration and usage
- [examples.md](examples.md) - Real-world layout examples

## Version Notes

This skill is based on Zellij's modern KDL-based configuration system (post-0.32.0). Older YAML-based configs are not covered.

## When Building Holocron

For this project specifically:
- Q1 and Q3 use `stacked: true` for overlapping panes
- Each quadrant is a pane with specific size constraints
- Use pane templates for repo and k8s contexts
- Configure pipes between Q3 and Q4 for cluster communication
- Generate layout from user configuration during setup
