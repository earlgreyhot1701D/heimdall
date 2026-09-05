# Structure steering: Heimdall

## File layout

```
heimdall/
├── README.md              # What this is, how to rerun it
├── PRD.md                 # The gated build document
├── FACILITATOR.md         # Shara's checklist during the run
├── KICKOFF_PROMPT.md      # The prompt that started this
├── RUN_REPORT.md          # Plain English, appended per block. THE deliverable.
├── NOTES.md               # Shara's reactions, written by hand during the run
├── raw_output.log         # Verbatim requests and responses. Never edited.
├── .env.example           # Placeholder names, no values
├── .gitignore             # .env, raw keys, anything sensitive
├── config/
│   └── config.json        # Bifrost config if the file method was used
├── scripts/
│   ├── 00-preflight.sh    # Direct calls to all 3 models, bypassing Bifrost
│   ├── 01-first-call.sh   # One unauthenticated call. Shara runs this by hand.
│   ├── 02-matrix.sh       # The nine calls
│   ├── 02b-provenance.sh  # Headers, env facts, negative control
│   └── 03-budget-trip.sh  # Loop until the clerk budget exhausts
└── screenshots/
    ├── rbac-roles.png
    ├── audit-log-success.png
    └── audit-log-denials.png
```

## Single responsibility

One file, one job. This is small enough that the rule is easy, so there is no excuse for breaking it.

- Each script does one block. It does not set up and test and report.
- Scripts write to `raw_output.log`. They do not write to `RUN_REPORT.md`.
- `RUN_REPORT.md` is written from what the scripts logged. That separation is what makes the report checkable.
- No script modifies config. Config changes are made deliberately and recorded.

## The two-file trust mechanism

This is the structural point of the whole repo.

| File | Written by | Read by | Rule |
|---|---|---|---|
| `raw_output.log` | scripts, append-only | nobody, until verification | never edited, never trimmed, never prettified |
| `RUN_REPORT.md` | the agent, per block | Shara, at every checkpoint | every claim cites a line in the log |

If those two ever disagree, the log wins and everything stops.

## Script conventions

- Every script echoes what it is about to do before doing it.
- Every script declares its expected outcome before running.
- Every response is appended to `raw_output.log` with a timestamp, the role name, the model, and the HTTP status.
- Virtual-key values come from `.env`. They never appear in a script, in the log, or in a screenshot. Log the role *name* (`clerk`), never the virtual-key *value* (`sk-bf-...`).
- Exit codes are not used for pass/fail. A denied call is an expected outcome, not a script failure.

## Commit discipline

- `.gitignore` before the first commit.
- Commit per block, message says what the block found, not what changed.
- Nothing gets committed until the block's checkpoint has a PASS.
- Final commit before push: scan the diff for `sk-`.

## What lives outside this repo

The article draft. It goes to the sponsor by email and to dev.to, not into this repo. The repo is evidence, the article is the interpretation, and they stay separate so a reader can check one against the other.
