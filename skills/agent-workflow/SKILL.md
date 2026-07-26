---
name: agent-workflow
description: Use when a project involves a long-horizon task an agent must survive - multi-hour or multi-day compute runs, GPU batch jobs, background pipelines, or paper/LaTeX work against a shared remote repo. Also use when the user asks to "set up the workflow", "install the discipline rules", "add the task ledgers", or when an incident happens during a long run and the lesson needs to be written down. Deploys CLAUDE.md discipline rules, three ledgers (RULES / TODO / PROVENANCE), and a resumable task-script skeleton.
---

# Long-horizon task workflow

Distilled from a real paper-rerun project: dozens of hours of experiments, a
journal paper revised in place, continuous pushes to a shared remote. About 800
lines of project rules accumulated there; 26 of them survive a change of project.
This skill deploys those 26 plus the scaffolding that keeps them enforced.

The rules are written in Chinese, because that is the language the incidents were
recorded in and rewriting them loses precision. Everything else is English.

## When to deploy

Deploy at the **start** of a long task, not after the first accident. The rules
are phrased as things that already went wrong; each one costs minutes to adopt
and cost hours to learn.

## How to deploy

Run the script. Do not hand-copy the files.

```bash
# from the project root you want to set up
bash ~/.claude/skills/agent-workflow/deploy.sh

# preview first
bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run

# explicit target and a subset of layers
bash ~/.claude/skills/agent-workflow/deploy.sh --target /path/to/project --layers l1,l2
```

### Choosing layers

| Layer | Keep it when | Contents |
|---|---|---|
| `l1` | always | 11 rules any agent running a long task needs: never edit a running script, timestamp-checked completion markers, check the queue before launching, criteria-before-data, admit reversals |
| `l2` | GPU / long batch jobs | 8 rules on device indices, `nvidia-smi` false alarms, pipeline isolation, stage checkpoints, trivial baselines, upstream-first diagnosis, baseline fairness protocol |
| `l3` | LaTeX + shared remote repo | 7 rules on pull-before-push with a push assertion, compile-don't-lint, page counts, table/prose sync, traceability, declaring deviations |

Default is all three. Ask the user which layers apply if the project type is not
obvious; when in doubt keep `l1` only and add layers later — re-running the
script refreshes the block in place.

Rule numbers stay stable when a layer is dropped, so cross-references such as
"see L1 rule 5" keep pointing at the right rule.

## What lands in the project

```
CLAUDE.md            rules, wrapped in a managed block (re-run to refresh)
docs/RULES.md        project-specific incidents — you append to this as you go
docs/TODO.md         FIFO queue + blocked items + cancelled items
docs/PROVENANCE.md   number → weights + code + logs, plus the criteria
scripts/run_task.sh  task skeleton: resume, stale-marker guard, failure marks
.gitignore           run artifacts, stamps, LaTeX intermediates
```

The four files under `docs/` and `scripts/` are **never overwritten** once they
exist — they become the project's own record. Only the `CLAUDE.md` block is
managed.

## After deploying

Three things, in this order:

1. **Fill the criteria in `docs/PROVENANCE.md` before looking at any result.**
   Significance threshold, baseline fairness protocol, falsifiable prediction.
   Written afterwards, they are not criteria, they are rationalisation.
2. **Put the real work into `docs/TODO.md`.** New user instructions go on the
   queue; the thing in flight is not dropped unless the user says stop.
3. **Wire `scripts/run_task.sh`.** One `step` call per stage, so a failure in the
   last stage costs minutes instead of the whole chain.

## Keeping it alive

The rules are the artefact; the mechanism that produced them is the point.

- **Write the incident down when it happens**, into `docs/RULES.md`, with how it
  was hit. A rule with no instance is noise that buries the real ones.
- **Reversals are appended in place, not edited away.** Keeping a visible "this
  earlier conclusion was wrong" is more useful than looking consistent — the next
  reader, usually the same agent, will otherwise repeat the reasoning.
- **A number goes public only if it points at three things**: weights, code, log.
- **Do not invent work.** When the queue is empty and nothing can run, the correct
  action is to do nothing.
