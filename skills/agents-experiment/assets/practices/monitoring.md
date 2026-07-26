# 监控长任务

## 核心矛盾

任务跑几十小时, agent 不能一直盯着; 但**失败往往是静默的** ——
进程死了、产物计数停住、日志不再增长, 这些从外面看和"正在跑"一模一样。

## 一、监控与计算必须分离

```bash
# 计算: setsid nohup 起, 与会话解耦
setsid nohup ./run_task.sh mytag 0 > logs/mytag.boot.log 2>&1 < /dev/null &

# 监控: 单独挂, 只读产物, 不碰计算
```

**为什么**: 本项目的监控进程被杀过一次, 计算链毫发无损, 因为它是 `setsid nohup` 起的。
如果监控和计算在同一进程树里, 停监控就等于停实验。

## 二、只 grep 成功标记 = 对崩溃完全静默

```bash
# ❌ 错: 进程 crash / 挂死 / OOM 时, 它一句话都不会说
tail -f run.log | grep --line-buffered "step="

# ✅ 对: 一个 alternation 覆盖进度 + 所有你会采取行动的失败签名
tail -f run.log | grep -E --line-buffered "step=|Traceback|CUDA out of memory|Killed|FAILED|assert"
```

**自检**: *如果这个进程现在崩了, 我的过滤器会输出任何东西吗?* 答不出"会"就把 grep 放宽。
宁可多噪声, 不可对 crashloop 静默。

## 三、完成标记必须验时间戳

```bash
T0=$(date +%s)
# ...
[ -f DONE ] && [ "$(stat -c %Y DONE)" -gt "$T0" ] && echo 真完成
```

**踩法**: 上一轮失败留下的 `ALLDONE` 没清, 新一轮起跑后监控看到旧标记, 报"全部完成"。
两个错叠加: 脚本失败后仍 touch 标记 + 监控只看文件是否存在。

## 四、产物计数不能单独作为存活判据

**踩法**: 某步 OOM 后整条链退出、进程消失, 而输出目录的文件数**停在某个值不动**。
只看计数会误判成"还在跑", 白等一小时。

```bash
# 每次巡检同时看两样
echo "产物 $(ls out/ | wc -l)   进程 $(pgrep -f run_task.sh | wc -l)"
```

## 五、监控必须有终止条件

**踩法**: 一个 `while pgrep -f "某脚本"; do sleep; done` 的 watcher, 在目标脚本早已结束后
仍在轮询, **空转了 1 天 20 小时**才被发现。它不报错、不占资源、不会自己退出。

**做法**: 每个 watcher 要么有明确的退出条件(等到了就 break), 要么设超时上限。
收尾时主动 `ps` 列一遍, 不要相信"应该都停了"。

## 六、触发后立刻补挂

监控报了一次事件之后, 后面的阶段就没人看着了。事件处理完**立即重新挂一个**盯下一阶段,
否则会盯丢。多个 watcher 用错开的阈值(如 50%/90%/完成), 比单个 watcher 更早暴露异常。

## 七、事件去重

轮询式 watcher 每轮都会看到同样的状态。用一个 `prev` 变量比较, 只在**状态变化**时输出,
否则会被自己刷屏(输出过多的监控会被自动停掉)。

```bash
prev=""
while true; do
  msg=$(收集状态)
  if [ "$msg" != "$prev" ] && [ -n "$msg" ]; then echo "$msg"; prev=$msg; fi
  sleep 120
done
```

## 八、轮询间隔

- 本地文件/进程检查: 30-120s
- 远程 API: 30s 以上(限流)
- 长任务的完成信号: 120s 足够, 更密只是噪声
