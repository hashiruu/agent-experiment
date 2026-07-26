---
name: agent-workflow
description: 用于给 7×24 小时不间断运行的科研自动化项目装上工作纪律：常驻实验队列、无人值守批处理、用 Git 维护的公开仓库、持续更新的 LaTeX/Overleaf 论文。用户说"装工作流""设置长任务纪律""加任务台账""setup the workflow"时用；长时间运行中出了事故、教训要当场记下来时也用。部署 CLAUDE.md 规则、三份台账（RULES / TODO / PROVENANCE）和可断点续跑的任务骨架。Use when setting up a 24/7 unattended research automation project - long-running experiment queues, Git-maintained public repos, continuously updated LaTeX/Overleaf papers.
---

# 长任务工作纪律

面向三件事同时在转的项目：实验在跑，仓库在推，论文在改，而人只在决策点出现。
这种场景下最贵的失败不是代码写错，是记账出错。出事的时候没人在场，等发现已经很晚。

素材来自一个长期无人值守运行的真实项目。那里攒下约 800 行规则，26 条经得起换一个项目。
这个 skill 部署的就是这 26 条，加上让它们真正被执行的脚手架。

规则正文是中文。事故是用中文记下来的，翻译会丢掉让它们可用的那点精确度。

## 什么时候部署

在长任务开始前部署，不要等第一次事故之后。每条规则都是"已经出过的事"的写法：
采纳一条花几分钟，学会一条花几小时。

## 怎么部署

跑脚本，不要手工拷文件。

```bash
# 在要设置的项目根目录下
bash ~/.claude/skills/agent-workflow/deploy.sh

# 先预览
bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run

# 指定目标和层
bash ~/.claude/skills/agent-workflow/deploy.sh --target /path/to/project --layers l1,l2
```

### 选哪几层

| 层 | 什么时候留 | 内容 |
|---|---|---|
| `l1` | 永远 | 11 条任何跑长任务的 agent 都需要的：绝不编辑正在执行的脚本、带时间戳校验的完成标记、起任务前先查队列、判据先于数据、承认推翻 |
| `l2` | 跑 GPU / 长批处理 | 8 条：设备编号的三套口径、`nvidia-smi` 的假故障、管线隔离、阶段断点、平凡基线、先查上游、baseline 公平性协议 |
| `l3` | LaTeX + 远程协作仓库 | 7 条：推前先拉且推后断言、编译而不是静态检查、页数只信编译器、表格与正文同步、可追溯性、声明所有偏离 |

默认三层全上。项目类型不明显时问用户；拿不准就只留 `l1`，之后再加，重跑脚本会原地刷新。

丢掉某一层时规则编号不变，所以"见 L1 第 5 条"这类交叉引用仍然指对。

## 落到项目里的东西

```
CLAUDE.md            规则，写在托管块里，重跑即刷新
docs/RULES.md        本项目特有的踩坑记录，边跑边追加
docs/TODO.md         FIFO 队列 + 阻塞项 + 已取消项
docs/PROVENANCE.md   数字 → 权重 + 代码 + 日志，以及判据
scripts/run_task.sh  任务骨架：断点续跑、旧标记防误判、失败标记
.gitignore           实验产物、断点戳、LaTeX 中间文件
```

`docs/` 和 `scripts/` 下的四份文件一旦存在就永不覆盖，它们会变成这个项目自己的记录。
被脚本管的只有 `CLAUDE.md` 里的托管块。

## 部署之后

三件事，按这个顺序做：

1. 在看到任何结果之前，先把 `docs/PROVENANCE.md` 里的判据填掉。显著性阈值、
   baseline 公平性协议、可证伪的预测。事后再写的不是判据，是给结论配尺子。
2. 把真正的活写进 `docs/TODO.md`。用户新给的指令入队，手上正在做的事不丢，
   除非用户明确说先停下。
3. 接好 `scripts/run_task.sh`。一个阶段一个 `step` 调用，这样最后一步失败的代价是几分钟，
   而不是整条链。

## 让它保持活着

规则是产物，产生规则的机制才是重点。

- 踩坑当场写进 `docs/RULES.md`，附上怎么踩到的。没有实例的规则是噪音，会把真教训淹掉。
- 推翻时在原地追加更正，不删旧的。看得见"曾经错过"比看起来一贯正确有用：
  下一个读它的人（通常就是同一个 agent）否则会把同样的推理再走一遍。
- 一个数字要对外，先能指到三样东西：权重、代码、日志。
- 不造任务。队列空了、没有可跑的东西时，正确动作是什么都不做。
