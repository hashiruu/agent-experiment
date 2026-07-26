# agent-workflow

简体中文 · [English](README.en.md)

> 一个 7 × 24 小时不间断运行，帮你跑实验、用 Git 维护公开仓库、更新 LaTeX（Overleaf）论文的科研自动化工作流。

三件事同时在转：实验在跑，仓库在推，论文在改。人只在决策点出现。

这种活最贵的失败从来不是代码写错，是记账出错。上一轮的完成标记被当成这一轮的；两条链同时往一个目录里写；
表格数字换了，讨论它的正文没换；`git push` 悄悄失败了，没人发现。它们有个共同点：
出事的时候没人在场，等发现已经是很久以后，中间那几十个小时全白跑。

这个仓库是一个 Claude Code Skill，一条命令把这套纪律装进任意项目。

## 实战

原本按月算的工作量，压进了一周。排队不停、断点续跑、结果一出立刻落地，7 天做完的量接近过去半年。

下面每条都不是设想，是规则文件里真实记录过的事故换来的：

- 一次 OOM 不再毁掉整条链。阶段化落盘加独立 pass 开关，最后一步炸了只重跑那一步，
  代价从几十小时变成几分钟。（L2 第 15 条）
- 不会再对着旧标记报"全部完成"。完成标记只在全部成功后写，监控只认 mtime 晚于启动时刻的标记。
  这条是因为失败批次留下的旧标记真的把监控骗过一次。（L1 第 2 条）
- 不会两条链撞进同一个输出目录。起任务前先查队列，别只看进程列表：卡在等待里的调度脚本，
  看起来什么都没在跑。（L1 第 3 条）
- 改完表格不会漏掉正文。重跑换掉表格数值之后，全文 grep 每一个被替换的旧值。
  那次主导论断的强度缩水了一大截，照抄旧句就等于虚报。（L1 第 5 条）
- 推送不会静默失败。每次 push 之后断言本地和远端一致。这行断言之所以存在，是因为真的静默失败过。（L3 第 20 条）
- 改完 LaTeX 一定编译。有一次编辑把 `figure` 插进了别的表格体内，括号配对、环境闭合、引用定义、列数，
  静态检查全过，文档却是坏的。只有真编译才发现。（L3 第 21 条）
- 错误结论会被留下并撤回。一次基于 6 个样本的误判杀掉了一个配置完全正确的运行；
  那段撤回记录留在原地，没删。（L1 第 6 / 11 条）

素材来自一个长期无人值守运行的真实项目。那里攒下约 800 行规则，其中 26 条经得起换一个项目。
本仓库装的就是这 26 条，加上让它们真正被执行的脚手架。

## 安装

```bash
git clone https://github.com/hashiruu/agent-workflow-template.git
cd agent-workflow-template
./install.sh                    # 装到 ~/.claude/skills/agent-workflow
```

不想克隆：

```bash
curl -fsSL https://raw.githubusercontent.com/hashiruu/agent-workflow-template/main/install.sh | bash
```

装完重启 Claude Code。skill 是在会话启动时被发现的，不重启看不见。

另外两个选项：`./install.sh --project` 装进当前目录的 `./.claude/skills/`，只对这个仓库生效，
可以提交给团队共用；`./install.sh --dir 路径` 装到别的地方。

## 使用

在要设置的项目里：

```
/agent-workflow
```

或者直接说"给这个项目装上长任务工作流"。skill 会判断该用哪几层，然后调部署脚本。想手动开：

```bash
bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run          # 先看会写什么
bash ~/.claude/skills/agent-workflow/deploy.sh                    # 全部三层
bash ~/.claude/skills/agent-workflow/deploy.sh --layers l1,l2     # 只要其中几层
bash ~/.claude/skills/agent-workflow/deploy.sh --target ../其他   # 装到别处
```

不用 Claude Code 也能用。`skills/agent-workflow/assets/` 里全是纯 Markdown 和 Bash，
`deploy.sh` 可以独立跑，部署出来的 `CLAUDE.md` 喂给任何 agent 都行。

## 部署下去的东西

```
CLAUDE.md            规则本体，写在托管块里，重跑即刷新
docs/RULES.md        本项目特有的踩坑记录，边跑边追加
docs/TODO.md         FIFO 队列 + 阻塞项 + 已取消项
docs/PROVENANCE.md   数字 → 权重 + 代码 + 日志，以及判据
scripts/run_task.sh  任务骨架：断点续跑、旧标记防误判、失败标记
.gitignore           实验产物、断点戳、LaTeX 中间文件
```

重跑是安全的。归脚本管的只有 `CLAUDE.md` 里的托管块；四份台账一旦建成就永不覆盖，
真要覆盖得加 `--force`。已经存在的 `CLAUDE.md` 不会被动，托管块追加在你的内容下面，
以后重跑就在原地替换。

`run_task.sh` 把自己所在的目录当成运行根，只写相对路径，所以日志、结果、断点戳都落在 `scripts/` 下面。
这是有意的，绝不写全局路径（见 L2 第 14 条）。想让产物去别处，把脚本挪个位置就行。

## 三层规则

规则按适用范围分层，免得一个纯前端项目也被灌一堆 GPU 建议。
丢掉某一层时规则编号不变，所以"见 L1 第 5 条"这类交叉引用不会错位。

| 层 | 条数 | 什么时候留 | 举一条 |
|---|---|---|---|
| L1 通用 | 11 | 永远 | 绝不编辑正在被执行的脚本。bash 按字节偏移增量读取脚本，运行期间编辑会顶移后续字节，恢复执行时落在 token 中间 |
| L2 计算实验 | 8 | 跑 GPU / 长批处理 | `CUDA_VISIBLE_DEVICES` 的值和 OOM 报错里的卡号都是可见索引，不是物理卡号；唯一可靠的是 `ls -l /proc/<pid>/fd \| grep nvidia` |
| L3 论文写作 | 7 | LaTeX + 远程协作仓库 | 只信 `Output written ... (N pages)`。`.aux` 里最大的页码是最后一个浮动体落在哪页，不是文档总页数 |

## 这套东西真正的价值

条文会过期，可移植的是产生条文的机制：

1. 踩坑即写入。当场写进 `docs/RULES.md`，附上怎么踩到的。没有实例的规则是噪音，只会把真教训淹掉。
2. 允许自我推翻。规则写错了就在原地追加更正，保留原文。看得见"曾经错过"比看起来一贯正确有用：
   下一个读它的人（通常就是同一个 agent）否则会把同样的推理再走一遍。
3. 判据先于数据。显著性阈值、公平性协议必须在看到结果之前写下，否则那不是判据，是拿结论挑尺子。
4. 每个对外的数字都能指到文件。权重、代码、日志，三样。

第 2 条最反直觉。原项目的规则文件里留着一整段被撤回的结论：一次基于 6 个样本的误判，
杀掉了一个配置完全正确的运行。留着这段撤回，比删干净重写有用得多。

## 几句实话

规则正文是中文。事故是用中文记下来的，翻译会丢掉让它们真正可用的那点精确度。

例子里的数据集名和指标数值是示意值。每个事故的形态和量级是真的，具体数字不是原项目的结果。

被刻意剔除的东西：数据集名、路径约定、阈值、超参、GPU 拓扑、某个上游仓库的特定缺陷。
这些属于项目自己的 `docs/RULES.md`。混进 `CLAUDE.md` 会淹掉通用规则，
下一个 agent 读到一堆无关条文，干脆就不看了。

判断一条规则该不该进这里，标准很简单：换一个数据集、换一篇论文，这条还成立吗？
不成立的，就留在它被学到的地方。

## 目录

```
install.sh                       安装 skill
skills/agent-workflow/
  SKILL.md                       入口：何时部署、选哪几层
  deploy.sh                      幂等部署 + 分层过滤
  assets/
    CLAUDE.md                    26 条规则，分 L1 / L2 / L3
    gitignore.snippet
    scaffold/{RULES,TODO,PROVENANCE}.md
    scaffold/run_task.sh
```

## 许可

MIT，见 [LICENSE](LICENSE)。
