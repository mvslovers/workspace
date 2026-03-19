#!/bin/bash
# setup.sh — Bootstrap mvslovers workspace for Claude Code
#
# Run this once on any new system:
#   cd ~/repos        # or wherever your mvslovers projects live
#   git clone https://github.com/mvslovers/workspace.git .workspace
#   ./.workspace/setup.sh
#
# What it does:
#   1. Symlinks the Root CLAUDE.md into the repos folder
#   2. Installs shared Claude Code commands to ~/.claude/commands/
#   3. Verifies prerequisites (gh, git, zowe)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== mvslovers workspace setup ==="
echo "Workspace repo: $SCRIPT_DIR"
echo "Projects dir:   $REPOS_DIR"
echo ""

# --- 1. Root CLAUDE.md ---
if [ -f "$REPOS_DIR/CLAUDE.md" ] && [ ! -L "$REPOS_DIR/CLAUDE.md" ]; then
    echo "WARNING: $REPOS_DIR/CLAUDE.md exists and is not a symlink."
    echo "         Backing up to CLAUDE.md.bak"
    mv "$REPOS_DIR/CLAUDE.md" "$REPOS_DIR/CLAUDE.md.bak"
fi

ln -sf .workspace/CLAUDE.md "$REPOS_DIR/CLAUDE.md"
echo "✓ Root CLAUDE.md symlinked"

# --- 2. Shared Claude Code commands ---
mkdir -p ~/.claude/commands

for cmd in "$SCRIPT_DIR/commands/"*.md; do
    name="$(basename "$cmd")"
    ln -sf "$cmd" "$HOME/.claude/commands/$name"
    echo "✓ Command: /$(basename "$name" .md)"
done

echo ""

# --- 3. Verify prerequisites ---
echo "Checking prerequisites..."
ok=true

check() {
    if command -v "$1" &>/dev/null; then
        echo "  ✓ $1 $(command -v "$1")"
    else
        echo "  ✗ $1 — not found"
        ok=false
    fi
}

check git
check gh
check make
check c2asm370

# Optional tools
if command -v zowe &>/dev/null; then
    echo "  ✓ zowe $(command -v zowe)"
else
    echo "  ~ zowe — not installed (optional, needed for integration tests)"
fi

echo ""

if [ "$ok" = true ]; then
    echo "=== Setup complete ==="
else
    echo "=== Setup complete (with warnings) ==="
fi

echo ""
echo "Available commands in any mvslovers project:"
for cmd in "$SCRIPT_DIR/commands/"*.md; do
    echo "  /$(basename "$cmd" .md)"
done
echo ""
echo "To update commands later: cd $SCRIPT_DIR && git pull"
