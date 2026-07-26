#!/usr/bin/env bash
# =============================================================================
# 安装 agent-experiment skill。
#
#   ./install.sh              -> ~/.claude/skills/agent-experiment   (对所有项目生效)
#   ./install.sh --project    -> ./.claude/skills/agent-experiment   (只对当前仓库生效)
#   ./install.sh --dir 路径   -> 路径/agent-experiment
#
# 从克隆下来的仓库里能跑, 直接单独拉这个脚本也能跑:
#   curl -fsSL https://raw.githubusercontent.com/hashiruu/agent-experiment/main/install.sh | bash
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/hashiruu/agent-experiment.git"
SKILL_NAME="agent-experiment"
DEST_ROOT="$HOME/.claude/skills"
TMP=""

die() { echo "错误: $*" >&2; exit 1; }
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP" || true; }
trap cleanup EXIT

while [ $# -gt 0 ]; do
    case $1 in
        --project) DEST_ROOT="$PWD/.claude/skills"; shift ;;
        --dir)     DEST_ROOT=${2:?--dir 需要一个路径}; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *)         die "无法识别的参数: $1" ;;
    esac
done

# --- 找 skill 源: 优先用本地克隆, 否则去拉 -----------------------------------
HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")
SRC=""
if [ -n "$HERE" ] && [ -f "$HERE/skills/$SKILL_NAME/SKILL.md" ]; then
    SRC="$HERE/skills/$SKILL_NAME"
else
    command -v git >/dev/null 2>&1 || die "找不到 git —— 手动克隆仓库后再跑 ./install.sh"
    echo "正在拉取 $REPO_URL ..."
    TMP=$(mktemp -d)
    git clone --depth 1 --quiet "$REPO_URL" "$TMP/repo" || die "克隆失败"
    SRC="$TMP/repo/skills/$SKILL_NAME"
fi
[ -f "$SRC/SKILL.md" ] || die "$SRC 里找不到 SKILL.md"

# --- 安装 --------------------------------------------------------------------
DEST="$DEST_ROOT/$SKILL_NAME"
mkdir -p "$DEST_ROOT"
[ -d "$DEST" ] && echo "覆盖已有安装: $DEST" || true
rm -rf "$DEST"
cp -R "$SRC" "$DEST"
chmod +x "$DEST/deploy.sh" "$DEST/assets/scaffold/run_task.sh"

# --- 校验 --------------------------------------------------------------------
for f in SKILL.md deploy.sh assets/CLAUDE.md assets/gitignore.snippet \
         assets/scaffold/RULES.md assets/scaffold/TODO.md \
         assets/scaffold/PROVENANCE.md assets/scaffold/run_task.sh \
         assets/practices/monitoring.md; do
    [ -f "$DEST/$f" ] || die "安装不完整: 缺少 $f"
done
bash -n "$DEST/deploy.sh" || die "deploy.sh 语法检查未通过"

cat <<EOF

已安装: $DEST

下一步:
  1. 重启 Claude Code (skill 在会话启动时才被发现)
  2. 在要设置的项目里点名调用:
       /agent-experiment
     或者直接说: "给这个项目装上长任务工作流"
  3. 也可以手动跑:
       bash $DEST/deploy.sh --dry-run
EOF
