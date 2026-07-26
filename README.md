# agent-workflow

A Claude Code skill that installs working discipline for **long-horizon tasks** —
runs measured in hours or days, GPU batch jobs, background pipelines, a paper
revised against a shared remote repo. The kind of work where the expensive
failures are not bad code but bad bookkeeping: a stale completion marker, two
chains writing the same directory, a table updated without the prose that
discusses it.

Distilled from one real project: dozens of hours of experiments, a journal paper
revised in place, continuous pushes to a shared remote. About 800 lines of rules
accumulated there. **26 survive a change of project** — those are what this ships.

## Install

```bash
git clone https://github.com/hashiruu/agent-workflow-template.git
cd agent-workflow-template
./install.sh                    # -> ~/.claude/skills/agent-workflow
```

Or without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/hashiruu/agent-workflow-template/main/install.sh | bash
```

Then restart Claude Code — skills are discovered at session start.

Options: `./install.sh --project` installs into `./.claude/skills/` (this repo
only, committable for a team); `./install.sh --dir PATH` installs anywhere else.

## Use

In the project you want to set up:

```
/agent-workflow
```

or just tell the agent *"set up the long-task workflow in this project"*. The
skill decides which layers apply and runs the deploy script. To drive it by hand:

```bash
bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run          # preview
bash ~/.claude/skills/agent-workflow/deploy.sh                    # all layers
bash ~/.claude/skills/agent-workflow/deploy.sh --layers l1,l2     # subset
bash ~/.claude/skills/agent-workflow/deploy.sh --target ../other  # elsewhere
```

Not a Claude Code user? `skills/agent-workflow/assets/` is plain Markdown and
Bash. `deploy.sh` works standalone; point any agent at the deployed `CLAUDE.md`.

## What gets deployed

```
CLAUDE.md            the rules, inside a managed block — re-run to refresh
docs/RULES.md        project-specific incidents; you append as you go
docs/TODO.md         FIFO queue + blocked items + cancelled items
docs/PROVENANCE.md   number -> weights + code + logs, plus the criteria
scripts/run_task.sh  task skeleton: resume, stale-marker guard, failure marks
.gitignore           run artifacts, stamps, LaTeX intermediates
```

Re-running is safe. Only the `CLAUDE.md` block is managed; once the four ledger
files exist they are never overwritten (`--force` if you really mean it).

`run_task.sh` treats **its own directory** as the run root and writes only
relative paths — logs, results and checkpoint stamps land next to it, under
`scripts/`. That is deliberate (never write a global path; see L2 rule 14). Move
the script if you want the artifacts elsewhere.

An existing `CLAUDE.md` is preserved — the block is appended below your content,
and replaced in place on later runs.

## The three layers

Rules are tagged by scope, so a web project does not inherit GPU advice. Rule
numbers stay stable when a layer is dropped, so cross-references keep working.

| Layer | Rules | Keep it when | Sample |
|---|---|---|---|
| **L1** general | 11 | always | Never edit a script that is currently executing — bash reads it incrementally by byte offset, so an edit mid-run shifts the bytes under the interpreter and it resumes inside a token |
| **L2** compute | 8 | GPU / long batch jobs | `CUDA_VISIBLE_DEVICES` values and OOM messages are visible indices, not physical cards; `ls -l /proc/<pid>/fd \| grep nvidia` is the only reliable mapping |
| **L3** writing | 7 | LaTeX + shared remote | Trust only `Output written ... (N pages)` — the largest page number in `.aux` is where the last float landed, not the document length |

## What it is actually for

The rules will age. The mechanism that produced them is the transferable part:

1. **Write the incident down when it happens**, with how it was hit. A rule with
   no instance is noise that buries the real ones.
2. **Allow self-reversal.** When a rule turns out to be wrong, append the
   correction in place and keep the original. Visible "I was wrong here" beats
   apparent consistency — the next reader, usually the same agent, will otherwise
   reproduce the reasoning that failed.
3. **Criteria before data.** Significance thresholds and fairness protocols get
   written down *before* results are seen, or they are not criteria, they are
   picking the ruler to fit the answer.
4. **Every published number traces to a file** — weights, code, log. Three things.

Point 2 is the counterintuitive one. The source project's rule file contains a
whole retracted conclusion: a judgement made on 6 samples killed a run that was
configured correctly. Keeping that retraction is worth more than a clean rewrite.

## Honest notes

- The rules are in **Chinese**. They were recorded in the language the incidents
  happened in, and translating them loses the precision that makes them usable.
  Everything else — skill, scripts, this README — is English.
- Dataset names and metric values inside the examples are **illustrative
  placeholders**. The shape and magnitude of each incident is real; the specific
  numbers are not the source project's results.
- **What was deliberately left out**: dataset names, path conventions, thresholds,
  hyperparameters, GPU topology, quirks of one upstream repo. Those belong in a
  project's own `docs/RULES.md`. Mixing them into `CLAUDE.md` drowns the general
  rules, and the next agent stops reading.

The test for whether a rule belongs here: **change the dataset, change the paper —
does it still hold?** If not, it stays where it was learned.

## Layout

```
install.sh                       installs the skill
skills/agent-workflow/
  SKILL.md                       entry point — when to deploy, which layers
  deploy.sh                      idempotent deployment, layer filtering
  assets/
    CLAUDE.md                    the 26 rules, L1 / L2 / L3
    gitignore.snippet
    scaffold/{RULES,TODO,PROVENANCE}.md
    scaffold/run_task.sh
```

## License

MIT — see [LICENSE](LICENSE).
