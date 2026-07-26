#!/bin/bash
# =============================================================================
# 长任务脚本骨架 —— 把踩过的坑固化成代码, 不靠人记。
#
# 已内建的防护(对应 CLAUDE.md 的规则编号):
#   [2]  完成标记只在全部成功后写; 失败写 FAILED_*; 校验 mtime > T0
#   [14] 所有输出相对本目录, 不写全局路径
#   [15] 每步一个断点戳, 支持从中断处续跑
#   [16] 结果文件写完后立即断言其内容与新鲜度
#
# 用法: ./run_task.sh <tag> [gpu]
# 改本文件前先确认没有 run 正在执行它:  ps -eo cmd | grep run_task.sh   [规则 1]
# =============================================================================
set -u
cd "$(dirname "$0")" || exit 1

TAG=${1:?用法: $0 <tag> [gpu]}
GPU=${2:-0}
START=$(date +%s)
LOG="logs/$TAG.log"
STAMP=".stamps/$TAG"
mkdir -p logs results "$STAMP"

# 起新批次先清掉上一轮的标记, 否则监控会认旧标记  [规则 2]
rm -f "ALLDONE_$TAG" "FAILED_$TAG"

say()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
fail() { say "FAILED at: $*"; { date '+%F %T'; echo "step: $*"; } > "FAILED_$TAG"; exit 1; }
done_step() { [ -f "$STAMP/$1" ]; }
mark_step() { date '+%F %T' > "$STAMP/$1"; }

# 产物断言: 存在 + 非空 + 含预期字段 + 是本轮产生的  [规则 2/16]
assert_fresh() {   # $1=文件 $2=必须包含的字符串 $3=该步起始时刻
    [ -s "$1" ]                       || fail "$1 缺失或为空"
    grep -q "$2" "$1"                 || fail "$1 不含 '$2'"
    [ "$(stat -c %Y "$1")" -ge "$3" ] || fail "$1 未刷新(是上一轮的残留)"
}

step() {           # $1=步骤名  $2...=要执行的命令
    local name=$1; shift
    if done_step "$name"; then say "跳过 $name (已完成)"; return; fi
    say "--- $name"
    local t0=$(date +%s)
    "$@" >> "$LOG" 2>&1 || fail "$name"
    mark_step "$name"
    say "    $name 用时 $(( $(date +%s) - t0 ))s"
}

# ------------------------------- 任务主体 -------------------------------
say "=== $TAG 开始  gpu=$GPU  pid=$$"

# 示例: 把每一步写成 step "<名字>" <命令...>
# step 1_prepare  python code/prepare.py --out ./out_$TAG
# step 2_train    python code/train.py   --gpu "$GPU" --out ./results/$TAG
#
# 需要断言产物新鲜度时:
# T0=$(date +%s)
# step 3_eval python code/eval.py --weights ./results/$TAG/best.pth --out ./results/$TAG/RESULT.txt
# assert_fresh "./results/$TAG/RESULT.txt" "score=" "$T0"

# ------------------------------- 完成标记 -------------------------------
# 只有走到这里才算全部成功  [规则 2]
{ echo "tag=$TAG  gpu=$GPU  started=$(date -d @$START '+%F %T')"
  echo "finished=$(date '+%F %T')  elapsed_min=$(( ($(date +%s)-START)/60 ))"
  echo "# 在此逐行写下本次的关键配置与结果, 供事后核对声明与实际是否一致"
} > "ALLDONE_$TAG"
say "=== $TAG 完成"
