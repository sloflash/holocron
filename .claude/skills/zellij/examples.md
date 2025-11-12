# Zellij Layout Examples

## Example 1: Simple Development Workspace

A basic two-pane layout with editor and terminal.

```kdl
layout {
    tab name="Dev" {
        pane split_direction="vertical" {
            pane size="70%" {
                edit "src/main.rs"
            }
            pane size="30%" {
                name "Terminal"
            }
        }
    }
}
```

**Result:**
```
┌──────────────────┬──────────┐
│                  │          │
│     Editor       │ Terminal │
│   (main.rs)      │          │
│                  │          │
└──────────────────┴──────────┘
```

---

## Example 2: Three-Column IDE Layout

Editor in center, file tree on left, terminal on right.

```kdl
layout {
    tab name="IDE" {
        pane split_direction="vertical" {
            pane size="20%" {
                name "Files"
                command "lsd"
                args "--tree"
            }
            pane size="60%" {
                focus true
                edit "README.md"
            }
            pane size="20%" {
                name "Terminal"
            }
        }
    }
}
```

**Result:**
```
┌──────┬─────────────────┬──────────┐
│      │                 │          │
│Files │     Editor      │ Terminal │
│Tree  │   (README.md)   │          │
│      │                 │          │
└──────┴─────────────────┴──────────┘
```

---

## Example 3: Stacked Repository Workspace

Three repositories in stacked panes (one visible at a time).

```kdl
layout {
    tab name="Repos" {
        pane {
            stacked true
            pane {
                expanded true
                name "Driving Repo"
                cwd "~/driving"
                focus true
            }
            pane {
                name "K8s Repo"
                cwd "~/k8s"
            }
            pane {
                name "Deploy Repo"
                cwd "~/k8s-deploy"
            }
        }
    }
}
```

**Result:**
```
┌────────────────────────────────┐
│  [Driving] [K8s] [Deploy]      │ ← Tab indicators
├────────────────────────────────┤
│                                │
│      Driving Repo              │
│      (Only this visible)       │
│      ~/driving                 │
│                                │
└────────────────────────────────┘
```

---

## Example 4: Multi-Tab Project Workspace

Separate tabs for development, testing, and monitoring.

```kdl
layout {
    tab name="Dev" focus=true {
        pane split_direction="vertical" {
            pane size="70%" edit="src/main.rs"
            pane size="30%" command="cargo" args="watch" "-x" "check"
        }
    }

    tab name="Test" {
        pane split_direction="horizontal" {
            pane size="50%" {
                command "cargo"
                args "test" "--" "--nocapture"
                start_suspended true
            }
            pane size="50%" {
                command "cargo"
                args "bench"
                start_suspended true
            }
        }
    }

    tab name="Monitor" {
        pane {
            command "htop"
        }
    }
}
```

---

## Example 5: Kubernetes Multi-Cluster Dashboard

Stacked k9s panes for different clusters with context isolation.

```kdl
pane_template name="k9s-cluster" {
    command "k9s"
    close_on_exit false
}

layout {
    tab name="K8s Clusters" {
        pane {
            stacked true
            k9s-cluster {
                expanded true
                name "Production"
                args "--context" "prod-eks-cluster"
            }
            k9s-cluster {
                name "Development"
                args "--context" "dev-eks-cluster"
            }
            k9s-cluster {
                name "Staging"
                args "--context" "staging-eks-cluster"
            }
        }
    }
}
```

---

## Example 6: Full-Screen Editor with Bottom Terminal

Classic editor-over-terminal layout.

```kdl
layout {
    tab name="Code" {
        pane split_direction="horizontal" {
            pane size="80%" {
                focus true
                edit "app.py"
            }
            pane size="20%" {
                name "Shell"
            }
        }
    }
}
```

**Result:**
```
┌────────────────────────────────┐
│                                │
│          Editor                │
│          (app.py)              │
│                                │
├────────────────────────────────┤
│         Terminal               │
└────────────────────────────────┘
```

---

## Example 7: Quadrant Layout (Holocron-style)

Four quadrants with specific purposes.

```kdl
layout {
    tab name="Workspace" {
        pane split_direction="vertical" {
            // Left side (50%)
            pane split_direction="horizontal" size="50%" {
                pane size="80%" {
                    name "Code"
                    focus true
                }
                pane size="20%" {
                    name "Logs"
                }
            }
            // Right side (50%)
            pane split_direction="horizontal" size="50%" {
                pane size="80%" {
                    name "Monitoring"
                    command "htop"
                }
                pane size="20%" {
                    name "Utilities"
                }
            }
        }
    }
}
```

**Result:**
```
┌─────────────────┬─────────────────┐
│                 │                 │
│      Code       │   Monitoring    │
│                 │     (htop)      │
│                 │                 │
├─────────────────┼─────────────────┤
│      Logs       │   Utilities     │
└─────────────────┴─────────────────┘
```

---

## Example 8: Tab Template with Custom Header

Consistent tab styling across all tabs.

```kdl
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="Main" {
        pane edit="README.md"
    }

    tab name="Terminal" {
        pane
    }
}
```

---

## Example 9: Build Automation Workspace

Separate panes for build, test, and lint watching.

```kdl
layout {
    tab name="Build Tools" {
        pane split_direction="horizontal" {
            pane size="34%" {
                name "Build"
                command "cargo"
                args "watch" "-x" "build"
            }
            pane size="33%" {
                name "Test"
                command "cargo"
                args "watch" "-x" "test"
            }
            pane size="33%" {
                name "Lint"
                command "cargo"
                args "watch" "-x" "clippy"
            }
        }
    }
}
```

**Result:**
```
┌──────────┬──────────┬──────────┐
│          │          │          │
│  Build   │   Test   │   Lint   │
│ (watch)  │ (watch)  │ (watch)  │
│          │          │          │
└──────────┴──────────┴──────────┘
```

---

## Example 10: Full Holocron Hyperpod Layout

Complete implementation of the Holocron specification.

```kdl
pane_template name="repo-pane" {
    command "bash"
    close_on_exit false
}

pane_template name="k9s-pane" {
    command "k9s"
    close_on_exit false
}

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="Hyperpod" focus=true {
        pane split_direction="vertical" {
            // Left Half (50%)
            pane split_direction="horizontal" size="50%" {
                // Q1: Stacked Repository Panes (80% height)
                pane size="80%" {
                    stacked true
                    repo-pane {
                        expanded true
                        name "Driving"
                        cwd "~/driving"
                        focus true
                    }
                    repo-pane {
                        name "K8s"
                        cwd "~/k8s"
                    }
                    repo-pane {
                        name "Deploy"
                        cwd "~/k8s-deploy"
                    }
                }
                // Q2: Placeholder (20% height)
                pane size="20%" {
                    name "Q2-Placeholder"
                }
            }

            // Right Half (50%)
            pane split_direction="horizontal" size="50%" {
                // Q3: Stacked K8s Monitoring (80% height)
                pane size="80%" {
                    stacked true
                    k9s-pane {
                        expanded true
                        name "Prod EKS"
                        args "--context" "prod-eks"
                    }
                    k9s-pane {
                        name "Dev EKS"
                        args "--context" "dev-eks"
                    }
                    k9s-pane {
                        name "Ray EKS"
                        args "--context" "prod-ray-eks"
                    }
                }
                // Q4: Cluster Utilities (20% height)
                pane size="20%" {
                    name "Cluster Utils"
                }
            }
        }
    }
}
```

**Result:**
```
┌─────────────────────────────────┬──────────────┐
│  [Driving] [K8s] [Deploy]       │ [Prod] [Dev] │
├─────────────────────────────────┤  [Ray]       │
│                                 │              │
│  Q1: Driving Repo               │ Q3: Prod EKS │
│      ~/driving                  │    (k9s)     │
│      (stacked, 80% height)      │ (80% height) │
│                                 │              │
├─────────────────────────────────┼──────────────┤
│  Q2: Placeholder                │ Q4: Utils    │
│      (20% height)               │ (20% height) │
└─────────────────────────────────┴──────────────┘
```

---

## Example 11: Floating Panes

Create floating panes for temporary tasks.

```kdl
layout {
    tab name="Main" {
        pane
        floating_panes {
            pane {
                name "Scratch"
                x "10%"
                y "10%"
                width "80%"
                height "80%"
            }
        }
    }
}
```

---

## Example 12: Complex Nested Layout

Deep nesting with mixed split directions.

```kdl
layout {
    tab name="Complex" {
        pane split_direction="vertical" {
            // Left column
            pane size="60%" split_direction="horizontal" {
                pane size="70%" edit="main.rs"
                pane size="30%" split_direction="vertical" {
                    pane size="50%" name="Tests"
                    pane size="50%" name="Bench"
                }
            }
            // Right column
            pane size="40%" split_direction="horizontal" {
                pane size="60%" command="htop"
                pane size="40%" name="Logs"
            }
        }
    }
}
```

---

## Example 13: CWD Composition

Hierarchical working directory composition.

```kdl
layout cwd="/home/user/projects" {
    tab name="App" cwd="myapp" {
        pane split_direction="horizontal" {
            pane cwd="src" {
                // Final CWD: /home/user/projects/myapp/src
                edit "main.rs"
            }
            pane cwd="tests" {
                // Final CWD: /home/user/projects/myapp/tests
                command "cargo" args "test" "--" "--nocapture"
            }
        }
    }

    tab name="Docs" cwd="docs" {
        // Final CWD: /home/user/projects/docs
        pane edit="README.md"
    }
}
```

---

## Tips for Creating Layouts

1. **Start simple**: Begin with single pane, add splits incrementally
2. **Test frequently**: Run `zellij --layout layout.kdl` after each change
3. **Use percentages**: More portable than fixed sizes
4. **Name everything**: Makes navigation and debugging easier
5. **Leverage templates**: Reduce duplication with pane_template
6. **Comment liberally**: Future you will thank present you
7. **Version control**: Keep layouts in git
8. **Document dependencies**: Note required tools, contexts, directories

## Testing Layouts

```bash
# Test a layout
zellij --layout path/to/layout.kdl

# Dump default layout for reference
zellij setup --dump-layout default > reference.kdl

# Kill existing sessions before testing
zellij kill-all-sessions

# Test with specific session name
zellij --layout layout.kdl --session test-session
```

## Common Layout Patterns

### Editor + Terminal (Classic)
```kdl
pane split_direction="horizontal" {
    pane size="80%" edit="file.txt"
    pane size="20%"
}
```

### Three-Column (Tree + Editor + Terminal)
```kdl
pane split_direction="vertical" {
    pane size="20%"  // File tree
    pane size="60%"  // Editor
    pane size="20%"  // Terminal
}
```

### Quad Split (Four Equal Panes)
```kdl
pane split_direction="vertical" {
    pane split_direction="horizontal" {
        pane size="50%"
        pane size="50%"
    }
    pane split_direction="horizontal" {
        pane size="50%"
        pane size="50%"
    }
}
```

### Stacked Views (Multiple Options, One Visible)
```kdl
pane {
    stacked true
    pane expanded=true name="View 1"
    pane name="View 2"
    pane name="View 3"
}
```
