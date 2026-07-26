#!/usr/bin/env bash
# =============================================================================
# Install the agent-workflow skill.
#
#   ./install.sh              -> ~/.claude/skills/agent-workflow   (all projects)
#   ./install.sh --project    -> ./.claude/skills/agent-workflow   (this repo only)
#   ./install.sh --dir PATH   -> PATH/agent-workflow
#
# Works from a clone, and also standalone:
#   curl -fsSL https://raw.githubusercontent.com/hashiruu/agent-workflow-template/main/install.sh | bash
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/hashiruu/agent-workflow-template.git"
SKILL_NAME="agent-workflow"
DEST_ROOT="$HOME/.claude/skills"
TMP=""

die() { echo "error: $*" >&2; exit 1; }
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP" || true; }
trap cleanup EXIT

while [ $# -gt 0 ]; do
    case $1 in
        --project) DEST_ROOT="$PWD/.claude/skills"; shift ;;
        --dir)     DEST_ROOT=${2:?--dir needs a path}; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *)         die "unknown argument: $1" ;;
    esac
done

# --- locate the skill source: local clone, else fetch -----------------------
HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")
SRC=""
if [ -n "$HERE" ] && [ -f "$HERE/skills/$SKILL_NAME/SKILL.md" ]; then
    SRC="$HERE/skills/$SKILL_NAME"
else
    command -v git >/dev/null 2>&1 || die "git not found — clone the repo manually and run ./install.sh"
    echo "fetching $REPO_URL ..."
    TMP=$(mktemp -d)
    git clone --depth 1 --quiet "$REPO_URL" "$TMP/repo" || die "clone failed"
    SRC="$TMP/repo/skills/$SKILL_NAME"
fi
[ -f "$SRC/SKILL.md" ] || die "SKILL.md not found in $SRC"

# --- install ----------------------------------------------------------------
DEST="$DEST_ROOT/$SKILL_NAME"
mkdir -p "$DEST_ROOT"
[ -d "$DEST" ] && echo "replacing existing install at $DEST" || true
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
chmod +x "$DEST/deploy.sh" "$DEST/assets/scaffold/run_task.sh"

# --- verify -----------------------------------------------------------------
for f in SKILL.md deploy.sh assets/CLAUDE.md assets/gitignore.snippet \
         assets/scaffold/RULES.md assets/scaffold/TODO.md \
         assets/scaffold/PROVENANCE.md assets/scaffold/run_task.sh; do
    [ -f "$DEST/$f" ] || die "install incomplete: missing $f"
done
bash -n "$DEST/deploy.sh" || die "deploy.sh failed its syntax check"

cat <<EOF

installed: $DEST

next:
  1. restart Claude Code (skills are picked up at session start)
  2. in the project you want to set up, ask for the skill by name:
       /agent-workflow
     or just: "set up the long-task workflow in this project"
  3. or run it directly:
       bash $DEST/deploy.sh --dry-run
EOF
