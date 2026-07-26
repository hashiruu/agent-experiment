# agent-workflow

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-8A63D2)](https://docs.claude.com/en/docs/claude-code/skills)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-lightgrey)](#requirements)

[简体中文](README.md) · English

> A research automation workflow that runs 24/7: it runs your experiments,
> maintains your public repos through Git, and keeps your LaTeX (Overleaf) paper
> up to date.

Two steps: install the skill, then run one deployment inside your project. What
lands there is 26 rules of long-horizon working discipline, three ledgers, and a
task skeleton that resumes from checkpoints. The rules were not invented. They
were paid for by a real project that ran unattended for a long stretch.

Who it is for: people who leave an agent running for days or weeks. Experiments
running, repos being pushed, the paper being revised, a human showing up only at
decision points.

## Quick start

```bash
git clone https://github.com/hashiruu/agent-workflow-template.git
cd agent-workflow-template
./install.sh                 # -> ~/.claude/skills/agent-workflow
```

Without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/hashiruu/agent-workflow-template/main/install.sh | bash
```

Restart Claude Code afterwards. Skills are loaded at session start, so you will
not see it until you do.

Then, in the project you want to set up:

```
/agent-workflow
```

or just say "set up the long-task workflow in this project". The skill works out
which layers apply, asks you when it is unsure, and calls the deploy script.

**Without Claude Code**: skip that step. In the project root, run
`bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run` to see what would
happen, then drop `--dry-run`.

## What it puts in your project

Previewed here in an **empty project**; with an existing `CLAUDE.md` the first
line becomes "append" instead.

```console
$ bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run
  [dry-run] 新建   CLAUDE.md            (层: l1,l2,l3)
  [dry-run] 新建   docs/RULES.md
  [dry-run] 新建   docs/TODO.md
  [dry-run] 新建   docs/PROVENANCE.md
  [dry-run] 新建   scripts/run_task.sh
  [dry-run] 追加   .gitignore

完成 —— 目标: /path/to/your/project
(预览模式: 什么都没写)
下一步: 在看到任何结果之前, 先把 docs/PROVENANCE.md 的判据填掉。
```

The script speaks Chinese, like the rules it deploys.

| File | What it does | Overwritten on re-run? |
|---|---|---|
| `CLAUDE.md` | the rules, inside a managed block | Only the block is refreshed. Anything you wrote outside it is untouched |
| `docs/RULES.md` | project-specific incidents, appended as you go | No |
| `docs/TODO.md` | FIFO queue + blocked items + cancelled items | No |
| `docs/PROVENANCE.md` | number -> weights + code + logs, plus the criteria | No |
| `scripts/run_task.sh` | task skeleton: resume, stale-marker guard, failure marks | No |
| `.gitignore` | run artifacts, stamps, LaTeX intermediates | Appended once |

Once those four files under `docs/` and `scripts/` exist they belong to the
project. Changing that takes `--force`.

`run_task.sh` treats its own directory as the run root and writes only relative
paths, so logs, results and checkpoint stamps land next to it under `scripts/`.
That is deliberate: never write a global path (see L2 rule 14). Move the script
if you want the artifacts elsewhere.

## The three layers

Rules are tagged by scope, so a frontend project does not inherit GPU advice.

**Numbering is global 1-26, not per layer**: L1 is rules 1-11, L2 is 12-19, L3 is
20-26. So "L3 rule 21" means global rule 21, not the 21st rule of L3 (L3 only has
7). Numbers do not shift when a layer is dropped, so cross-references never break.

| Layer | Rules | Keep it when | One example |
|---|---|---|---|
| L1 general | 11 | always | Never edit a script that is currently executing. bash reads it incrementally by byte offset, so an edit mid-run shifts the bytes under the interpreter and it resumes inside a token |
| L2 compute | 8 | GPU / long batch jobs | `CUDA_VISIBLE_DEVICES` values and the card numbers in OOM messages are visible indices, not physical cards; the only reliable mapping is `ls -l /proc/<pid>/fd \| grep nvidia` |
| L3 writing | 7 | LaTeX + shared remote | Trust only `Output written ... (N pages)`. The largest page number in `.aux` is where the last float landed, not the length of the document |

<details>
<summary><b>All 26 rules</b> (titles only; full text with the "how it was hit" notes lives in <a href="skills/agent-workflow/assets/CLAUDE.md">assets/CLAUDE.md</a>, in Chinese)</summary>

**L1 general (1-11)**

1. Never edit a script that is currently executing
2. Completion markers need a timestamp check; a failure path never writes one
3. Check the existing queue before launching, not just the process list
4. After adding a flag or changing an interface, sweep every call site
5. After changing any number, grep the whole document for every old value
6. Confirm the sample size before judging a distribution-like metric
7. "These two numbers are identical" requires a full-precision recompute
8. If two points differ in more than one variable, you have a hypothesis, not a conclusion
9. Criteria before data
10. Stop when diagnosis costs more than it returns, and write down where to resume
11. Admit reversals; do not quietly rewrite

**L2 compute (12-19)**

12. There are three GPU numbering schemes and only one is reliable
13. An `nvidia-smi` error does not mean the card is broken
14. Pipeline isolation: one directory per run, relative output paths only
15. Staged scripts must let every step be rerun on its own
16. A failure kills the whole chain while the file count still looks like progress
17. Report the trivial baseline alongside any metric
18. Measure the intermediate artifact before explaining the final metric
19. Fairness protocol for baseline tuning (fixed up front, never revised afterwards)

**L3 writing (20-26)**

20. The remote is shared; always pull before you push (the rule body also covers the post-push consistency assertion)
21. LaTeX must be installed locally, and every edit must be compiled
22. Trust only the page count the compiler reports
23. Changing a table number means changing the prose that discusses it
24. Every figure and table sits next to the paragraph discussing it
25. Traceability: every published number points at three things
26. Declare every deviation

</details>

## Using run_task.sh

The skeleton runs nothing by itself. You write each stage as one `step` line:

```bash
step 1_prepare  python code/prepare.py --out ./out_$TAG
step 2_train    python code/train.py   --gpu "$GPU" --out ./results/$TAG

T0=$(date +%s)
step 3_eval     python code/eval.py    --weights ./results/$TAG/best.pth \
                                       --out ./results/$TAG/RESULT.txt
assert_fresh "./results/$TAG/RESULT.txt" "score=" "$T0"   # exists, non-empty, has the field, produced this round
```

Those lines go into the "任务主体" (task body) section of `scripts/run_task.sh`;
a comment marks the spot. Then run `./scripts/run_task.sh myrun 0`. The first
argument is the tag (`$TAG` in the script, which keeps this run's output
directory, log and stamps separate); the second is the GPU (`$GPU`, default 0).
It does four things:

- each successful `step` drops a stamp in `.stamps/`, so a rerun skips what is done;
- any failing step writes `FAILED_<tag>` and exits, and **never writes a completion marker**;
- only a full success writes `ALLDONE_<tag>`, holding start/end times and the key config you fill in;
- `assert_fresh` confirms the artifact came from this round. Check only that a file exists and last round's leftover gets accepted as a new result.

For long runs, launch with `setsid nohup ./scripts/run_task.sh myrun 0 &` so that
killing the monitor does not kill the compute chain.

**Rerunning a step after you change the code**: stamps live in
`scripts/.stamps/<tag>/`, one file per step. Delete a stamp and that step runs
again; delete the directory and the whole chain does.

```bash
rm scripts/.stamps/myrun/2_train      # changed train.py, rerun training
rm -rf scripts/.stamps/myrun          # start over
```

Do not skip this. Change the code without deleting the stamp and the script
quietly skips training, then hands you last round's weights as a fresh result,
which is exactly the "it looked like it succeeded" failure rule 2 exists to prevent.

## Commands

```bash
bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run          # preview
bash ~/.claude/skills/agent-workflow/deploy.sh                    # all layers
bash ~/.claude/skills/agent-workflow/deploy.sh --layers l1,l2     # subset
bash ~/.claude/skills/agent-workflow/deploy.sh --target ../other  # elsewhere
bash ~/.claude/skills/agent-workflow/deploy.sh --force            # overwrite those four files too
```

| Flag | Default | What it does |
|---|---|---|
| `--target DIR` | current directory | which project to deploy into |
| `--layers l1,l2,l3` | all three | which layers to keep; an unknown layer name is an error, never a silently empty ruleset |
| `--dry-run` | off | print what would happen, write nothing |
| `--force` | off | allow overwriting those four existing files (three ledgers + `run_task.sh`) |

For the installer: `--project` installs into `./.claude/skills/` of the **current
directory**, scoped to that repo and committable for a team. It goes by where you
run it from, so run it in **your own project root** and call the template script
by absolute path:

```bash
cd ~/my-project
bash ~/where-you-cloned/agent-workflow-template/install.sh --project
```

`--dir PATH` installs wherever you point it.

## In practice

Queue never idle, resume from checkpoint, land every result the moment it exists.
Seven days covered close to what half a year used to.

The caveat, so nobody reads it as a benchmark: this is the author's own
before-and-after with no control group, and "work" means experiment batches plus
paper revision rounds, not any single metric. Keep two things apart. **The speed
comes from never stopping** - no babysitting the machine, no restart from zero
after a crash, no results piling up until the weekend - and any 24/7 setup gets
that. **What the 26 rules buy is that the output is trustworthy**, instead of
another round of "the marker was from last time and the table disagrees with the
prose". Unattended without the rules just raises your error rate at the same
speed. Your own multiplier depends on how interruptible your tasks are.

None of the points below is aspirational. Each was paid for by an incident
recorded in the rule file:

- One OOM no longer destroys the whole chain. Staged artifacts plus per-pass
  switches mean a failure in the last step reruns only that step, and the cost
  drops from tens of hours to minutes. (L2 rule 15)
- No more "all done" read off a stale marker. The completion marker is written
  only after every subtask succeeds, and monitoring accepts it only if its mtime
  is later than launch. A leftover marker from a failed batch really did fool the
  monitor once. (L1 rule 2)
- No two chains colliding in one output directory. Check the queue before
  launching, not just the process list: a scheduler blocked in a wait loop looks
  like nothing is running. (L1 rule 3)
- Updating a table never leaves the prose behind. After a rerun replaces the
  numbers, grep the whole document for every old value. That time the headline
  claim had shrunk a lot, and copying the old sentence would have overstated it.
  (L1 rule 5)
- Pushes do not fail silently. Assert local equals remote after every push. That
  assertion exists because a push really did fail silently. (L3 rule 20)
- LaTeX edits are always compiled. One edit dropped a `figure` inside another
  table's body. Bracket matching, environment closure, reference definitions,
  column counts, every static check passed, and the document was still broken.
  Only a real compile caught it. (L3 rule 21)
- Wrong conclusions are kept and retracted, not erased. A judgement made on 6
  samples killed a run that was configured correctly, and the retraction is still
  sitting there. (L1 rules 6 and 11)

## Design principles

The rules will age. What transfers is the mechanism that produced them:

1. Write the incident down when it happens, into `docs/RULES.md`, with how it was
   hit. A rule with no instance is noise that buries the real ones.
2. Allow self-reversal. When a rule turns out to be wrong, append the correction
   in place and keep the original. A visible "I was wrong here" beats apparent
   consistency: the next reader, usually the same agent, will otherwise reproduce
   the reasoning that failed.
3. Criteria before data. Significance thresholds and fairness protocols get
   written down before results are seen, or they are not criteria, they are
   picking the ruler to fit the answer.
4. Every published number traces to a file. Weights, code, log.

Point 2 is the counterintuitive one. The source project's rule file still carries
a whole retracted conclusion: a judgement made on 6 samples killed a run that was
configured correctly. Keeping that retraction is worth more than a clean rewrite.

## Requirements

- **bash 3.2+** (what macOS ships is enough). It uses `BASH_SOURCE` and `${var//,/ }`, so `sh` will not do.
- **awk / grep / sed / mktemp**, whatever your system ships.
- **git**, only for the `curl | bash` path, where the script clones itself.
- **Claude Code**, optional. `deploy.sh` runs without it; see the FAQ.
- **Platform: Linux.** `install.sh` and `deploy.sh` are portable. Two lines of the
  `run_task.sh` skeleton are GNU-only: `stat -c %Y` in `assert_fresh()` (BSD:
  `stat -f %m`) and `date -d @$START` in the completion marker (BSD: `date -r
  $START`). Editing those two lines is the simplest fix. Homebrew coreutils works
  too, but it installs them as `gstat` / `gdate`, so `gnubin` has to be on your
  PATH before `stat -c` resolves. Windows: use WSL.

## FAQ

**I already have a `CLAUDE.md`. Will it be overwritten?**
No. The block is appended below your content, and later runs replace only that
block. What you wrote is never touched.

**Can I install L1 only and add layers later?**
Yes. `--layers l1` installs 11 rules; change the flag and re-run to add more, and
the block refreshes in place. Rule numbers are identical in every combination, so
cross-references never break.

**I have half-filled ledgers. Will a re-run wipe them?**
No. The four files under `docs/` and `scripts/` are never overwritten once they
exist, unless you pass `--force` yourself.

**Can I use this without Claude Code?**
Yes. Everything under `skills/agent-workflow/assets/` is plain Markdown and Bash,
`deploy.sh` runs standalone, and the `CLAUDE.md` it produces can be handed to any
agent.

**How do I update?**
`git pull`, then re-run `./install.sh`, which **replaces the whole skill
directory** - back up first if you edited the rules under
`~/.claude/skills/agent-workflow/assets/`.
Projects you already deployed into are unaffected; re-run `deploy.sh` there if you
want the newer rules.

**How do I uninstall?**
`rm -rf ~/.claude/skills/agent-workflow`, or `./.claude/skills/agent-workflow` if
you installed with `--project`. Files already deployed into a project are your
records, so keep or delete them as you like. Removing every trace takes two
edits: in `CLAUDE.md`, delete everything between `<!-- agent-workflow:begin ... -->`
and `<!-- agent-workflow:end -->`, markers included; in `.gitignore`, delete the
block starting at `# --- agent-workflow ---` (that line is also how the script
knows it already appended).

**I installed with `--project`. What path do the commands use?**
Replace every `~/.claude/skills/agent-workflow/` below with
`./.claude/skills/agent-workflow/`.

**I do not trust `curl | bash`.**
You should not. Split it: `curl -fsSL <url> -o install.sh`, read it, then
`bash install.sh`. The script does three things: copy `skills/agent-workflow/`
into your skills directory, `chmod +x`, and verify nothing is missing. The script
that writes into your project is `deploy.sh`, and it has `--dry-run`.

**Will it push on its own, or edit my code?**
Two separate layers, do not conflate them. **The template itself will not.**
`deploy.sh` writes six files into your project (one of which appends a block to
`.gitignore`), touches no git config, goes nowhere online, and asks for no
permissions. The only network call is `install.sh` cloning this repo on the
`curl | bash` path, and `run_task.sh` runs nothing until you put your own
commands in it.

**But the seven L3 rules are precisely about teaching an agent to push**, which
is their purpose, not a side effect. So what actually decides whether something
gets pushed at 3am is how you launch your agent and what you granted it, not this
template. If you do not want it near Git, do not install L3: `--layers l1` or
`--layers l1,l2`.

## Honest notes

The rules are in Chinese. They were recorded in the language the incidents
happened in, and translating them costs the precision that makes them usable.

Dataset names and metric values in the examples are placeholders. The shape and
magnitude of each incident is real; the specific numbers are not the source
project's results.

What was deliberately left out: dataset names, path conventions, thresholds,
hyperparameters, GPU topology, quirks of one upstream repo. Those belong in a
project's own `docs/RULES.md`. Mixed into `CLAUDE.md` they drown the general
rules, and the next agent stops reading.

The test for whether a rule belongs here: change the dataset, change the paper,
does it still hold? If not, it stays where it was learned.

## Layout

```
install.sh                       installs the skill
skills/agent-workflow/
  SKILL.md                       entry point: when to deploy, which layers
  deploy.sh                      idempotent deployment, layer filtering
  assets/
    CLAUDE.md                    the 26 rules, L1 / L2 / L3
    gitignore.snippet
    scaffold/{RULES,TODO,PROVENANCE}.md
    scaffold/run_task.sh
```

## License

MIT, see [LICENSE](LICENSE).
