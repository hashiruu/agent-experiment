#!/usr/bin/env bash
# =============================================================================
# agent-workflow — deploy the long-horizon task discipline into a project.
#
#   ./deploy.sh [--target DIR] [--layers l1,l2,l3] [--force] [--dry-run]
#
# What it writes into <target>:
#   CLAUDE.md            discipline rules, inside a managed block (re-runnable)
#   docs/RULES.md        project-specific incident log      (never overwritten)
#   docs/TODO.md         FIFO queue + blocked + cancelled    (never overwritten)
#   docs/PROVENANCE.md   traceability index + criteria       (never overwritten)
#   scripts/run_task.sh  resumable task skeleton             (never overwritten)
#   .gitignore           appends the template's ignore rules (once)
#
# Idempotent: re-running refreshes only the managed CLAUDE.md block. The four
# ledger files are yours once created — use --force to overwrite them.
# =============================================================================
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ASSETS="$HERE/assets"

TARGET=$PWD
LAYERS="l1,l2,l3"
FORCE=0
DRY=0

BEGIN_MARK="<!-- agent-workflow:begin — managed block, re-run the skill to update -->"
END_MARK="<!-- agent-workflow:end -->"

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case $1 in
        --target)  TARGET=${2:?--target needs a directory}; shift 2 ;;
        --layers)  LAYERS=${2:?--layers needs a value};      shift 2 ;;
        --force)   FORCE=1; shift ;;
        --dry-run) DRY=1;   shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *)         die "unknown argument: $1" ;;
    esac
done

[ -d "$ASSETS" ]  || die "assets/ not found next to deploy.sh (looked in $HERE)"
[ -d "$TARGET" ]  || die "target directory does not exist: $TARGET"
TARGET=$(cd "$TARGET" && pwd)

# every requested layer must exist, or the deploy silently ships zero rules
[ -n "${LAYERS//,/}" ] || die "--layers is empty (valid: l1, l2, l3)"
for tok in ${LAYERS//,/ }; do
    case $(printf '%s' "$tok" | tr 'A-Z' 'a-z') in
        l1|l2|l3) ;;
        *) die "unknown layer '$tok' (valid: l1, l2, l3)" ;;
    esac
done

say() { echo "  $*"; }
act() { [ "$DRY" -eq 1 ] && say "[dry-run] $*" || say "$*"; }

# --- 1. build the CLAUDE.md block, keeping only the requested layers ---------
BLOCK=$(mktemp); trap 'rm -f "$BLOCK" "$BLOCK.body"' EXIT
awk -v layers="$LAYERS" '
    BEGIN { n = split(toupper(layers), a, ","); for (i = 1; i <= n; i++) sel[a[i]] = 1; keep = 1 }
    /^## / { if ($2 ~ /^L[123]$/) keep = ($2 in sel) ? 1 : 0; else keep = 1 }
    keep
' "$ASSETS/CLAUDE.md" > "$BLOCK.body"
grep -q '^### [0-9]' "$BLOCK.body" || die "layer filter kept zero rules — check --layers"

{ echo "$BEGIN_MARK"; cat "$BLOCK.body"; echo "$END_MARK"; } > "$BLOCK"

CLAUDE="$TARGET/CLAUDE.md"
if [ ! -f "$CLAUDE" ]; then
    act "create  CLAUDE.md            (layers: $LAYERS)"
    [ "$DRY" -eq 0 ] && cp "$BLOCK" "$CLAUDE" || true
elif grep -qF "$BEGIN_MARK" "$CLAUDE"; then
    act "refresh CLAUDE.md            (managed block replaced, layers: $LAYERS)"
    if [ "$DRY" -eq 0 ]; then
        awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v f="$BLOCK" '
            index($0, b) { skip = 1; while ((getline l < f) > 0) print l; close(f); next }
            skip         { if (index($0, e)) skip = 0; next }
                         { print }
        ' "$CLAUDE" > "$CLAUDE.tmp" && mv "$CLAUDE.tmp" "$CLAUDE"
    fi
else
    act "append  CLAUDE.md            (existing content kept above, layers: $LAYERS)"
    [ "$DRY" -eq 0 ] && { printf '\n'; cat "$BLOCK"; } >> "$CLAUDE" || true
fi

# --- 2. the three ledgers + the task skeleton -------------------------------
place() {  # $1=source  $2=destination  $3=mode
    local src=$1 dst=$2 mode=${3:-644} rel=${2#"$TARGET"/}
    if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
        say "keep    $rel (already exists — not touched)"
        return
    fi
    if [ -e "$dst" ]; then act "OVERWRITE $rel (--force)"; else act "create  $rel"; fi
    if [ "$DRY" -eq 0 ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        chmod "$mode" "$dst"
    fi
}

place "$ASSETS/scaffold/RULES.md"      "$TARGET/docs/RULES.md"
place "$ASSETS/scaffold/TODO.md"       "$TARGET/docs/TODO.md"
place "$ASSETS/scaffold/PROVENANCE.md" "$TARGET/docs/PROVENANCE.md"
place "$ASSETS/scaffold/run_task.sh"   "$TARGET/scripts/run_task.sh" 755

# --- 3. .gitignore ----------------------------------------------------------
GI="$TARGET/.gitignore"
GI_MARK="# --- agent-workflow ---"
if [ -f "$GI" ] && grep -qF "$GI_MARK" "$GI"; then
    say "keep    .gitignore (agent-workflow rules already present)"
else
    act "append  .gitignore"
    if [ "$DRY" -eq 0 ]; then
        { [ -f "$GI" ] && printf '\n' || true; echo "$GI_MARK"; cat "$ASSETS/gitignore.snippet"; } >> "$GI"
    fi
fi

echo
echo "done — target: $TARGET"
[ "$DRY" -eq 1 ] && echo "(dry run: nothing was written)" || true
echo "next: fill docs/PROVENANCE.md 判据 BEFORE looking at any results."
