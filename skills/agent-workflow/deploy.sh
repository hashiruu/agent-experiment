#!/usr/bin/env bash
# =============================================================================
# agent-workflow —— 把长任务工作纪律部署进一个项目。
#
#   ./deploy.sh [--target 目录] [--layers l1,l2,l3] [--force] [--dry-run]
#
# 会写进 <目标目录> 的东西:
#   CLAUDE.md            规则本体, 放在托管块里(可反复重跑刷新)
#   docs/RULES.md        本项目特有的踩坑记录            (永不覆盖)
#   docs/TODO.md         FIFO 队列 + 阻塞项 + 已取消项   (永不覆盖)
#   docs/PROVENANCE.md   可追溯性索引 + 判据             (永不覆盖)
#   scripts/run_task.sh  可断点续跑的任务骨架            (永不覆盖)
#   .gitignore           追加模板的忽略规则              (只追加一次)
#
# 幂等: 重跑只刷新 CLAUDE.md 的托管块。四份台账建成后就归项目自己所有,
# 真要覆盖用 --force。
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

die() { echo "错误: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case $1 in
        --target)  TARGET=${2:?--target 需要一个目录}; shift 2 ;;
        --layers)  LAYERS=${2:?--layers 需要一个值};      shift 2 ;;
        --force)   FORCE=1; shift ;;
        --dry-run) DRY=1;   shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *)         die "无法识别的参数: $1" ;;
    esac
done

[ -d "$ASSETS" ]  || die "deploy.sh 旁边找不到 assets/ (找的是 $HERE)"
[ -d "$TARGET" ]  || die "目标目录不存在: $TARGET"
TARGET=$(cd "$TARGET" && pwd)

# 层名必须真实存在, 否则会静默部署出一份零规则的 CLAUDE.md
[ -n "${LAYERS//,/}" ] || die "--layers 是空的 (可选: l1, l2, l3)"
for tok in ${LAYERS//,/ }; do
    case $(printf '%s' "$tok" | tr 'A-Z' 'a-z') in
        l1|l2|l3) ;;
        *) die "无法识别的层 '$tok' (可选: l1, l2, l3)" ;;
    esac
done

say() { echo "  $*"; }
act() { [ "$DRY" -eq 1 ] && say "[dry-run] $*" || say "$*"; }

# --- 1. 生成 CLAUDE.md 托管块, 只保留选中的层 --------------------------------
BLOCK=$(mktemp); trap 'rm -f "$BLOCK" "$BLOCK.body"' EXIT
awk -v layers="$LAYERS" '
    BEGIN { n = split(toupper(layers), a, ","); for (i = 1; i <= n; i++) sel[a[i]] = 1; keep = 1 }
    /^## / { if ($2 ~ /^L[123]$/) keep = ($2 in sel) ? 1 : 0; else keep = 1 }
    keep
' "$ASSETS/CLAUDE.md" > "$BLOCK.body"
grep -q '^### [0-9]' "$BLOCK.body" || die "分层过滤后一条规则都没剩下 —— 检查 --layers"

{ echo "$BEGIN_MARK"; cat "$BLOCK.body"; echo "$END_MARK"; } > "$BLOCK"

CLAUDE="$TARGET/CLAUDE.md"
if [ ! -f "$CLAUDE" ]; then
    act "新建   CLAUDE.md            (层: $LAYERS)"
    [ "$DRY" -eq 0 ] && cp "$BLOCK" "$CLAUDE" || true
elif grep -qF "$BEGIN_MARK" "$CLAUDE"; then
    act "刷新   CLAUDE.md            (托管块已替换, 层: $LAYERS)"
    if [ "$DRY" -eq 0 ]; then
        awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v f="$BLOCK" '
            index($0, b) { skip = 1; while ((getline l < f) > 0) print l; close(f); next }
            skip         { if (index($0, e)) skip = 0; next }
                         { print }
        ' "$CLAUDE" > "$CLAUDE.tmp" && mv "$CLAUDE.tmp" "$CLAUDE"
    fi
else
    act "追加   CLAUDE.md            (原有内容保留在上方, 层: $LAYERS)"
    [ "$DRY" -eq 0 ] && { printf '\n'; cat "$BLOCK"; } >> "$CLAUDE" || true
fi

# --- 2. 三份台账 + 任务骨架 --------------------------------------------------
place() {  # $1=源文件  $2=目标路径  $3=权限
    local src=$1 dst=$2 mode=${3:-644} rel=${2#"$TARGET"/}
    if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
        say "保留   $rel (已存在, 未改动)"
        return
    fi
    if [ -e "$dst" ]; then act "覆盖   $rel (--force)"; else act "新建   $rel"; fi
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
    say "保留   .gitignore (agent-workflow 规则已存在)"
else
    act "追加   .gitignore"
    if [ "$DRY" -eq 0 ]; then
        { [ -f "$GI" ] && printf '\n' || true; echo "$GI_MARK"; cat "$ASSETS/gitignore.snippet"; } >> "$GI"
    fi
fi

echo
echo "完成 —— 目标: $TARGET"
[ "$DRY" -eq 1 ] && echo "(预览模式: 什么都没写)" || true
echo "下一步: 在看到任何结果之前, 先把 docs/PROVENANCE.md 的判据填掉。"
