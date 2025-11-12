# TMUX Personal Development Environment
## Design Specification v1.0

---

## 0. Development & Testing Workflow

### Overview
Establish a seamless, integrated feedback loop where Claude Code can launch preview sessions in new terminal windows and monitor user feedback in real-time without requiring back-and-forth context switching.

### The Integrated Testing Strategy

#### A. Automated Preview Launch Workflow

**Visual Layout of Preview Session:**
```
┌─────────────────────────────────────────────────────────────────┐
│  NEW TERMINAL WINDOW - tmux-preview session                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │         PREVIEW AREA                                    │    │
│  │    (Your tmux layout being tested)                      │    │
│  │                                                         │    │
│  │                                                         │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │  FEEDBACK PANE (Always visible at bottom)              │    │
│  │  > Type feedback here, Claude monitors in real-time    │    │
│  │  > Commands: "approve", "change X to Y", etc.          │    │
│  │  > Press Ctrl+C then type, or use prefix + f           │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### B. How It Works

**Step 1: Claude Creates & Launches**
```bash
# Claude runs:
1. Creates/updates tmux config
2. Opens new terminal window:
   - macOS: open -a Terminal.app
   - iTerm2: open -a iTerm.app
3. Launches tmux-preview with feedback pane
4. Starts monitoring feedback file
```

**Step 2: User Tests & Provides Feedback**
- Preview opens automatically in Cursor's integrated terminal
- Bottom pane is dedicated feedback area
- User types feedback directly: "looks good", "make pane bigger", "change color", etc.
- Feedback is logged to `/Users/mayankketkar/claude-tools/tmux/feedback.log` (in this repo)

**Step 3: Claude Monitors & Responds**
- Claude runs background process monitoring feedback log
- When user says "check feedback" or after making changes, Claude reads new entries
- Limitation: Claude can't truly "live monitor" - only checks when prompted or between iterations
- Solution: User can ping Claude with "check" or Claude auto-checks after each change

**Step 4: Iteration Loop**
- Claude makes changes
- Reloads preview session (or creates new version)
- User sees updates immediately
- Continues until user types "approve" or "lgtm"

#### C. Technical Implementation

**1. Feedback Pane Setup**
```bash
# Repository feedback log location
FEEDBACK_LOG="/Users/mayankketkar/claude-tools/tmux/feedback.log"

# Bottom pane configuration
tmux split-window -v -p 20 -t tmux-preview
tmux send-keys -t tmux-preview:bottom \
  'echo "=== FEEDBACK PANE ===" && \
   echo "Type your feedback below (Claude will check periodically):" && \
   while read line; do echo "[$(date +%H:%M:%S)] $line" | tee -a '"$FEEDBACK_LOG"'; done' C-m
```

**2. Auto-Launch Script** (`scripts/launch-preview.sh`)
```bash
#!/bin/bash
REPO_DIR="/Users/mayankketkar/claude-tools/tmux"
FEEDBACK_LOG="$REPO_DIR/feedback.log"

# Initialize feedback log
echo "=== New Preview Session: $(date) ===" >> "$FEEDBACK_LOG"

# Create preview session with feedback pane
tmux new-session -d -s tmux-preview -c "$REPO_DIR"

# Load preview config
tmux source-file "$REPO_DIR/configs/preview.conf"

# Split for feedback pane
tmux split-window -v -p 20
tmux select-pane -t 0 -T "PREVIEW"
tmux select-pane -t 1 -T "FEEDBACK - Type here, then tell Claude to 'check feedback'"

# Setup feedback collection in bottom pane
tmux send-keys -t tmux-preview:1 \
  'while read line; do echo "[$(date +%H:%M:%S)] $line" >> '"$FEEDBACK_LOG"'; done' C-m

# Attach to session (opens in current terminal/Cursor terminal)
tmux attach -t tmux-preview
```

**3. Claude's Monitoring Approach**
```bash
#!/bin/bash
# Since Claude can't "live monitor", this script tracks what's been read

FEEDBACK_LOG="/Users/mayankketkar/claude-tools/tmux/feedback.log"
LAST_READ_FILE="/Users/mayankketkar/claude-tools/tmux/.last-read-line"

# Initialize last read tracker
[ ! -f "$LAST_READ_FILE" ] && echo "0" > "$LAST_READ_FILE"

# Read only NEW lines since last check
LAST_LINE=$(cat "$LAST_READ_FILE")
NEW_FEEDBACK=$(tail -n +$((LAST_LINE + 1)) "$FEEDBACK_LOG")

if [ -n "$NEW_FEEDBACK" ]; then
  echo "📝 New feedback received:"
  echo "$NEW_FEEDBACK"

  # Update last read position
  wc -l < "$FEEDBACK_LOG" > "$LAST_READ_FILE"
else
  echo "No new feedback since last check"
fi
```

#### D. User Commands in Feedback Pane

**Quick Commands:**
- `approve` / `lgtm` → Claude promotes to production
- `rollback` → Revert to previous version
- `show config` → Display current config in popup
- `reload` → Reload preview with latest changes
- `quit` → Close preview session

**Feedback Examples:**
- "make the kubectl pane wider"
- "change status bar color to blue"
- "add a keybinding for logs"
- "k9s pane is too small"
- "this looks perfect, approve"

#### E. Iteration Protocol

**Version Management:**
1. Each iteration: `/Users/mayankketkar/claude-tools/tmux/configs/versions/v{N}.conf`
2. Feedback log: `/Users/mayankketkar/claude-tools/tmux/feedback.log` (timestamped)
3. Claude tracks changes in `/Users/mayankketkar/claude-tools/tmux/CHANGELOG.md`

**Workflow:**
```
┌──────────────────────────────────────────────────────────┐
│ 1. Claude: Creates config v1                             │
│ 2. Claude: Launches preview in Cursor terminal           │
│ 3. Claude: Initializes feedback tracking                 │
│    ↓                                                      │
│ 4. User: Tests in preview window                         │
│ 5. User: Types feedback in bottom pane                   │
│ 6. User: Says "check feedback" to Claude                 │
│    ↓                                                      │
│ 7. Claude: Runs check-feedback script                    │
│ 8. Claude: Reads only NEW feedback since last check      │
│ 9. Claude: Makes requested changes → creates v2          │
│10. Claude: Reloads preview session                       │
│11. Claude: Auto-checks feedback after reload             │
│    ↓                                                      │
│12. LOOP until user types "approve"                       │
│    ↓                                                      │
│13. Claude: Promotes to production config                 │
└──────────────────────────────────────────────────────────┘
```

**Key Improvements:**
- Feedback log lives in repo: `/Users/mayankketkar/claude-tools/tmux/feedback.log`
- Tracking file prevents re-reading old feedback: `.last-read-line`
- User can trigger checks with "check feedback" command
- Claude auto-checks after making changes
- If Claude "stops", just say "check feedback" to resume

#### F. Alternative: Tmux Popup Feedback (Even Faster)

Instead of a pane, use a keybinding to pop up a feedback form:

**Keybinding:** `prefix + f` (for feedback)

**What happens:**
```bash
tmux bind-key f display-popup -E \
  'echo "Enter feedback:" && \
   read feedback && \
   echo "[$(date +%H:%M:%S)] $feedback" >> ~/.tmux-feedback.log && \
   echo "Feedback sent to Claude!"'
```

User can press `prefix + f` anytime, type feedback, and continue testing.

#### G. Advantages of This Approach

✅ **No context switching** - User stays in preview window
✅ **Real-time iteration** - Claude responds immediately to feedback
✅ **Visual + textual** - See changes AND describe them
✅ **Automated** - Claude handles terminal launching, monitoring
✅ **Persistent log** - All feedback saved with timestamps
✅ **Non-intrusive** - Feedback pane at bottom, doesn't interfere with preview
✅ **Fast approval** - Just type "approve" when done

---

## 1. Session Architecture

### Primary Objective
Create a persistent, auto-configured tmux session named `tmux-main` that launches with predefined windows and panes optimized for Kubernetes development.

### Session Properties
- **Session Name**: `tmux-main`
- **Auto-start**: On terminal launch (optional)
- **Persistence**: Survives disconnects, restorable
- **Base Directory**: `~/workspace`

---

## 2. Window Structure

### Global Keybinding
- **Cheatsheet Overlay**: `prefix + ?` (or custom binding like `prefix + h`)
  - Display translucent popup with all custom keybindings
  - Organized by category (Navigation, Kubernetes, Git, etc.)
  - Implementation: Tmux popup with formatted text file
  - Style: Semi-transparent, centered, large enough for readability

### Window List

#### 3.a Window: `kubernetes` (Index 0)
**Purpose**: Primary Kubernetes development and monitoring environment

**Pane Layout**:
```
┌─────────────────────────────────┬──────────────────────┐
│                                 │                      │
│         k9s                     │                      │
│    (Kubernetes TUI)             │                      │
│                                 │    Claude Code       │
│                                 │    (AI Assistant)    │
├─────────────────────────────────┤                      │
│                                 │                      │
│    kubectl Smart Shell          │                      │
│    (Enhanced kubectl CLI)       │                      │
│                                 │                      │
└─────────────────────────────────┴──────────────────────┘
```

**Pane Details**:

- **Pane 0 (Top-Left)**: k9s
  - Full Kubernetes cluster visualization
  - Auto-connects to current context
  - Read-only mode option for safety

- **Pane 1 (Bottom-Left)**: kubectl Smart Shell
  - **Enhanced Features**:
    - Custom prompt showing current context/namespace
    - Kubectl autocomplete enabled
    - Predefined aliases:
      ```bash
      alias k='kubectl'
      alias kgp='kubectl get pods'
      alias kgpa='kubectl get pods --all-namespaces'
      alias kd='kubectl describe'
      alias ke='kubectl edit'
      alias kdel='kubectl delete'
      ```
    - **Utility Functions**:

      1. **Bulk Port Forwarding**:
         ```bash
         # Forward all HyperPod EKS pods to sequential ports starting 8081
         port-forward-hyperpod() {
           local start_port=8081
           kubectl get pods -l app=hyperpod -o name | while read pod; do
             kubectl port-forward "$pod" "$start_port:8080" &
             ((start_port++))
           done
         }
         ```

      2. **Interactive Pod Selector**:
         ```bash
         # FZF-based pod selection for exec/logs/describe
         kpod() {
           local pod=$(kubectl get pods -o name | fzf)
           kubectl exec -it "$pod" -- /bin/bash
         }
         ```

      3. **Context Switcher**:
         ```bash
         # Quick context switching with preview
         kctx() {
           kubectl config get-contexts -o name | fzf --preview \
             'kubectl config view --context={} | grep -A5 "^- context:"'
         }
         ```

      4. **Resource Monitor**:
         ```bash
         # Watch resource usage for specific namespace
         kwatch-resources() {
           watch -n 2 "kubectl top pods -n ${1:-default}"
         }
         ```

      5. **Quick Deploy Form** (Future):
         - Interactive TUI form for common operations
         - Fill fields: pod selector, local port, remote port
         - Generate and execute kubectl commands
         - Built with `dialog` or `whiptail`

- **Pane 2 (Right)**: Claude Code
  - Full-height vertical pane
  - Running: `claude` or `cc` command
  - AI assistance for kubectl commands, YAML debugging, etc.
  - Persistent session for context retention

#### 3.b Window: `driving` (Index 1)
**Purpose**: General development workspace
- TBD: Define specific purpose (general shell? specific project?)

#### 3.c Window: `k8s-deploy` (Index 2)
**Purpose**: k8s-deploy repository workspace
- **Pane Layout**: Single pane or split (TBD)
- **Auto-actions**:
  - Navigate to k8s-deploy repo directory
  - Auto-run `git status` on window creation
  - Display recent commits

#### 3.d Window: `k8s` (Index 3)
**Purpose**: Main Kubernetes repository workspace
- Similar setup to k8s-deploy
- Dedicated for core k8s repo work

#### 3.x Additional Windows (Future)
- To be defined based on workflow needs
- Potential: `monitoring`, `logs`, `testing`, `docs`

---

## 3. Configuration Files Structure

```
~/.tmux/
├── tmux.conf              # Main configuration
├── keybindings.conf       # All custom keybindings
├── theme.conf             # Visual theme and status bar
├── cheatsheet.txt         # Keybinding reference for popup
├── scripts/
│   ├── launch-main.sh     # Launch production session
│   ├── launch-preview.sh  # Launch test session
│   ├── kubectl-utils.sh   # Kubectl helper functions
│   └── promote-to-production.sh
└── versions/              # Version history
    ├── tmux.conf.v1
    ├── tmux.conf.v2
    └── ...
```

---

## 4. Keybindings Reference

### Navigation
- `prefix + h/j/k/l`: Navigate panes (Vim-style)
- `prefix + H/J/K/L`: Resize panes
- `prefix + 0-9`: Switch to window by index

### Custom Operations
- `prefix + ?` or `prefix + h`: Show cheatsheet popup (translucent overlay)
- `prefix + R`: Reload tmux configuration
- `prefix + K`: Open kubectl command palette (future)
- `prefix + P`: Launch port-forward wizard (future)

### Kubernetes-Specific (Window 0 only)
- `prefix + p`: Quick port-forward current pod
- `prefix + l`: Tail logs of selected pod
- `prefix + e`: Execute shell in selected pod

---

## 5. Visual Enhancements

### Status Bar
- Left: Session name, Window list
- Right: Current Kubernetes context, namespace, timestamp
- Colors: Distinguish between contexts (prod=red, staging=yellow, dev=green)

### Pane Borders
- Active pane: Highlighted border (bright color)
- Inactive panes: Dimmed border
- Pane titles showing: pane purpose (k9s, kubectl, claude)

### Cheatsheet Popup
- **Trigger**: `prefix + ?`
- **Style**:
  - Semi-transparent background (if terminal supports)
  - Centered, 80% viewport width
  - Categorized sections with headers
  - Color-coded by category
  - Exit: Any key or ESC

---

## 6. Future Enhancements

### Phase 2
- [ ] Common git configurations for all repo windows
- [ ] Pane-specific command history viewer (last 20 commands)
  - Trigger: `prefix + H` in any pane
  - Translucent overlay showing history
  - Select to re-run command
- [ ] Synchronized panes for multi-cluster operations
- [ ] Auto-save/restore session state on reboot

### Phase 3
- [ ] Integration with external tools:
  - Helm command palette
  - Terraform workspace switcher
  - Docker container manager pane
- [ ] Smart notifications:
  - Pod crash alerts
  - Deployment completion
  - Resource threshold warnings

### Phase 4
- [ ] Session templates for different project types
- [ ] Export/import session configurations
- [ ] Team-shared tmux configurations via git repo
- [ ] AI-suggested layout optimizations based on usage patterns

---

## 7. Implementation Phases

### Phase 1: Foundation (Week 1)
1. ✅ Establish testing workflow (Step 0)
2. Basic tmux.conf with 4 windows
3. Kubernetes window with 3-pane layout
4. Basic keybindings
5. Simple cheatsheet popup

### Phase 2: Enhancement (Week 2)
1. Kubectl smart shell with utility functions
2. Port-forwarding automation
3. Enhanced status bar with k8s context
4. All repo windows with auto-navigation

### Phase 3: Advanced Features (Week 3+)
1. Interactive forms for kubectl operations
2. Advanced pane command history
3. Resource monitoring integrations
4. Polish and optimization

---

## 8. Success Criteria

- [ ] Session launches consistently with all windows/panes configured
- [ ] All keybindings work as documented
- [ ] Cheatsheet popup displays correctly
- [ ] Kubectl utilities function properly
- [ ] User can visually approve all changes before production deployment
- [ ] Configuration is version-controlled and rollback-capable
- [ ] Documentation is complete and accessible via cheatsheet

---

## Notes & Decisions

- **Terminal Emulator**: Confirm which terminal you use (iTerm2, Alacritty, etc.) for transparency feature support
- **Tmux Version**: Verify tmux version for popup support (requires 3.2+)
- **Shell**: Confirm zsh/bash for kubectl autocomplete setup
- **Kubernetes Contexts**: List your typical contexts for status bar configuration

---

**Document Version**: 1.0
**Last Updated**: 2025-11-09
**Status**: Draft - Pending User Review


Special Panels (that have hot keys for each)
easy single 0, 1, 2... to move i should be able to do opt (then 0, 1.. should light up for moving)
------- ------- -------- ---------
NCCL quick test                        |   resources for GPU nodes
 when u see methods here 
 then you can select from options
 opens node list so u can do 
 magic on them (nvdia driver>>>)
                                            only G5 ---> high level
                                            if possible also tell me who 
                                            what job is running.. for how long
a repo which just 
does very fast checks on nodes         |    hot key: kill like claude does
this is not anything but online        | 
easy way to get latest code 
and bootstrap

------- ------- -------- ---------
 k9s   | subnets | diagnostics for subnets | 
 new??? terraform to add new ???

------- ------- -------- ---------
> send logs from pod to analysis to claude or AI? 
one shot ... smart agent so we dont kill the context???
gpu diagnostics?

subnets is 


nvitop on one of those 
(1) cursor install on a pod and open .. 
(2) what gpu


Key monitoring:
$ nccl-tests/build/all_reduce_perf -b 8 -e 8G -f 2 -g 8

# Test NCCL performance across nodes
Size     Time   Algbw   Busbw
8 B      32.5us  0.00   0.00
16 B     32.7us  0.00   0.00
...
8 GB     21.2ms 385.6  674.3   ← This number matters!

What you look for:
├─ Busbw (Bus bandwidth): Should be 350-400 GB/s for H100 + EFA
├─ Consistent across sizes: No sudden drops
└─ Similar across all node pairs: No network imbalance


Traffic

RDMA (Remote Direct Memory Access):
├─ Bypass OS kernel for network I/O
├─ GPUs talk directly to network card
├─ Low latency (~2-5 microseconds)
└─ Essential for distributed training

TCP/IP (Traditional):
├─ Goes through OS kernel
├─ High latency (~50-100 microseconds)
├─ Used for: Management, storage access
└─ NOT suitable for GPU-to-GPU



Good Topology (EFA/InfiniBand):
        ┌────────────┐
        │   Switch   │
        │ (Non-      │
        │ blocking)  │
        └────────────┘
          ╱  │  │  ╲
         ╱   │  │   ╲
    ┌────┐ ┌────┐ ┌────┐ ┌────┐
    │Node│ │Node│ │Node│ │Node│
    │ 1  │ │ 2  │ │ 3  │ │ 4  │
    └────┘ └────┘ └────┘ └────┘
Solution: All nodes connect to high-speed switch
Bandwidth: 400 Gbps per connection (fast!)


SYMPTOM: Training slow during data loading
├─ Check: FSx IOPS exhausted?
├─ Check: Too many random reads? (should be sequential)
├─ Check: Network congestion to storage?
└─ Solution: Increase FSx capacity, add caching layer

SYMPTOM: Checkpoint saves take forever
├─ Check: Writing from all nodes simultaneously?
├─ Check: Correct file striping on Lustre?
└─ Solution: Optimize parallel I/O patterns


KUBERNETES (for ML jobs):
┌────────────────────────────────────────┐
│ Control Plane                          │
│ ├─ API Server (receives job requests) │
│ ├─ Scheduler (assigns to nodes)       │
│ └─ Controllers (manage job lifecycle) │
└────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────┐
│ Worker Nodes                           │
│ ├─ Kubelet (runs containers)          │
│ ├─ GPU Plugin (exposes GPUs)          │
│ └─ CNI (networking)                   │
└────────────────────────────────────────┘

SLURM (traditional HPC scheduler):
┌────────────────────────────────────────┐
│ Controller Node                        │
│ ├─ Job queue                           │
│ └─ Resource allocation                 │
└────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────┐
│ Compute Nodes                          │
│ └─ slurmstepd (job execution)         │
└────────────────────────────────────────┘

TYPICAL INCIDENT FLOW:

Alert: "GPU utilization dropped to 30% on training job"

Your investigation process:
├─ 1. Check job logs
│   └─ See: "NCCL timeout" errors
├─ 2. Check network connectivity
│   └─ Run: nccl-tests between nodes
│   └─ Find: Node 5 not responding
├─ 3. Check node health
│   └─ SSH to node 5
│   └─ Find: EFA interface down
├─ 4. Remediation
│   └─ Restart EFA driver
│   └─ Rerun NCCL tests (passes)
├─ 5. Resume training
│   └─ Job restarts from last checkpoint
└─ 6. Post-mortem
    └─ Root cause: Known EFA driver bug
    └─ Action: Update driver version across cluster