# agent-workflow

[简体中文](README.md) · English

> A research automation workflow that runs 24/7: it runs your experiments,
> maintains your public repos through Git, and keeps your LaTeX (Overleaf) paper
> up to date.

Three things turning at once. Experiments running, repos being pushed, the paper
being revised. A human shows up only at decision points.

In that setting the expensive failures are never bad code. They are bookkeeping
failures. Last round's completion marker read as this round's. Two chains writing
into the same directory. A table updated while the prose discussing it is not. A
`git push` that failed quietly with nobody watching. What they have in common:
nobody is there when it happens, it surfaces much later, and the tens of hours in
between are gone.

This repo is a Claude Code skill that installs that discipline into any project
with one command.

## In practice

Work that used to take months fits into a week. Queue never idle, resume from
checkpoint, land every result the moment it exists. Seven days covered close to
what half a year used to.

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

The material comes from one real project that ran unattended over a long stretch.
About 800 lines of rules accumulated there; 26 survive a change of project. Those
26 are what this ships, plus the scaffolding that keeps them enforced.

## Install

```bash
git clone https://github.com/hashiruu/agent-workflow-template.git
cd agent-workflow-template
./install.sh                    # -> ~/.claude/skills/agent-workflow
```

Without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/hashiruu/agent-workflow-template/main/install.sh | bash
```

Restart Claude Code afterwards. Skills are discovered at session start, so you
will not see it until you do.

Two other options: `./install.sh --project` installs into `./.claude/skills/`,
which is scoped to that repo and committable for a team; `./install.sh --dir PATH`
installs anywhere else.

## Use

In the project you want to set up:

```
/agent-workflow
```

or just say "set up the long-task workflow in this project". The skill works out
which layers apply and calls the deploy script. To drive it by hand:

```bash
bash ~/.claude/skills/agent-workflow/deploy.sh --dry-run          # preview
bash ~/.claude/skills/agent-workflow/deploy.sh                    # all layers
bash ~/.claude/skills/agent-workflow/deploy.sh --layers l1,l2     # subset
bash ~/.claude/skills/agent-workflow/deploy.sh --target ../other  # elsewhere
```

You do not need Claude Code. Everything under `skills/agent-workflow/assets/` is
plain Markdown and Bash, `deploy.sh` runs standalone, and the `CLAUDE.md` it
produces can be handed to any agent.

## What gets deployed

```
CLAUDE.md            the rules, in a managed block, refreshed on re-run
docs/RULES.md        project-specific incidents, appended as you go
docs/TODO.md         FIFO queue + blocked items + cancelled items
docs/PROVENANCE.md   number -> weights + code + logs, plus the criteria
scripts/run_task.sh  task skeleton: resume, stale-marker guard, failure marks
.gitignore           run artifacts, stamps, LaTeX intermediates
```

Re-running is safe. The only thing the script owns is the block inside
`CLAUDE.md`; once the four ledger files exist they are never overwritten, and you
need `--force` to change that. An existing `CLAUDE.md` is left alone. The block
goes below your content and gets replaced in place on later runs.

`run_task.sh` treats its own directory as the run root and writes only relative
paths, so logs, results and checkpoint stamps land next to it under `scripts/`.
That is deliberate: never write a global path (see L2 rule 14). Move the script
if you want the artifacts elsewhere.

## The three layers

Rules are tagged by scope, so a frontend project does not inherit GPU advice.
Rule numbers stay stable when a layer is dropped, so cross-references like "see L1
rule 5" keep pointing at the right rule.

| Layer | Rules | Keep it when | One example |
|---|---|---|---|
| L1 general | 11 | always | Never edit a script that is currently executing. bash reads it incrementally by byte offset, so an edit mid-run shifts the bytes under the interpreter and it resumes inside a token |
| L2 compute | 8 | GPU / long batch jobs | `CUDA_VISIBLE_DEVICES` values and the card numbers in OOM messages are visible indices, not physical cards; the only reliable mapping is `ls -l /proc/<pid>/fd \| grep nvidia` |
| L3 writing | 7 | LaTeX + shared remote | Trust only `Output written ... (N pages)`. The largest page number in `.aux` is where the last float landed, not the length of the document |

## What it is actually for

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
