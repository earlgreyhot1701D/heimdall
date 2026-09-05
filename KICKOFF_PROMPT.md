# Kickoff prompt

Paste this into Kiro or Codex to start. It assumes `PRD.md` and `.kiro/steering/` are in the repo.

---

You are helping me build a small test harness called **Heimdall**. Read `PRD.md` in full before you write anything. Read `.kiro/steering/product.md`, `.kiro/steering/tech.md`, and `.kiro/steering/structure.md` too.

**Context you need up front:**

I am a court manager, not a traditional engineer. I direct, you generate, I validate and decide. I will not be reading your code line by line. You must report to me in plain English at every checkpoint, and your report must state what you expected to happen before it states what happened.

This is a three hour job with a hard stop. It is not a product. It is evidence for an article. The value is in what we observe, not in what we build.

**How we work:**

1. **Propose before you implement.** For each block in the PRD, tell me what you plan to do and what files you will touch. Wait for my approval. Then implement.
2. **One block at a time.** Do not run ahead. Block 4 does not start until I say PASS on Block 3.
3. **DO NOT refactor anything outside the block we are on.**
4. After each block, append to `RUN_REPORT.md` in plain English. Format below. I read that, not your code.
5. If something mismatches what we expected, **stop and tell me. Do not fix it quietly.** A mismatch is the most valuable thing that can happen in this project. It is a finding, not a bug to be smoothed over.

**RUN_REPORT.md entry format, every block:**

```
## CHECKPOINT [n]: [what this block did]
Time: [timestamp]

WHAT I DID (plain English, 2-4 sentences, no jargon)

EXPECTED:
[what should happen, stated as a specific observable outcome]

OBSERVED:
[what actually happened]

MATCH / MISMATCH
>>> If MISMATCH, explain in one sentence what differs and stop here.

EVIDENCE: [line numbers in raw_output.log, screenshot filenames]

WAITING ON SHARA: PASS or FAIL?
```

**Hard rules from the PRD, repeated because they matter:**

- Never commit a key, a `.env`, or any `sk-bf-*` value.
- Never paraphrase an error message. Verbatim, in full, into `raw_output.log`.
- Never write a claim into `RUN_REPORT.md` that is not traceable to a line in `raw_output.log`.
- Never add an LLM call that interprets results. Comparison is deterministic: expected value versus observed value.
- Every call logs its **full request URL** and **all response headers**. Provenance is recorded, never assumed. Block 4b exists to prove the traffic went through Bifrost, and it is not optional.
- Log the badge **name** (`clerk`), never the badge **value** (`sk-bf-...`).
- The three model names come from `.env` and nowhere else. Do not hardcode a model name in a script.
- Local Docker only. Do not deploy anything anywhere.
- Everything in the STUB list gets a one-line comment naming what it would do. Nothing in the STUB list gets built.

**On keys and models, so you do not propose the wrong thing:**

There is ONE provider key. The price tiers are model tiers, not key tiers. One OpenAI key reaches all three models. The three badges are virtual keys minted by Bifrost in Block 3 and are not provider credentials. If you find yourself planning for three OpenAI keys, re-read Block 0.

Block 0 includes a mandatory pre-flight: each of the three models is called directly against `api.openai.com`, bypassing Bifrost, and must return a completion. Log these under a `PREFLIGHT` heading. Do not skip this. Without it, a provider-side rejection during the matrix is indistinguishable from a gateway denial and the central result of the project becomes unreadable.

**We work in three phases. Start with Phase A.**

| Phase | Keys | Docker | You can work | 
|---|---|---|---|
| A. Build dry | none exist | not running | ahead, unattended, nothing to observe yet |
| B. Smoke | provider key added | not running | 3 direct calls, I watch |
| C. Live run | key + badges | running | one block at a time, I watch everything |

**Phase A is your task right now.** Build the whole harness with no keys and no Docker. Every script must support `DRY_RUN=1`: print the exact request it would send, mask any `sk-` value and show the badge name instead, execute nothing, exit 0.

The dry run must assert these eight checks and print a plain-English PASS or FAIL for each:

1. Exactly 9 badge-model combinations are generated
2. The expected table sums to 6 ALLOW and 3 DENY
3. Every variable the scripts reference exists in `.env.example`
4. No model name appears anywhere outside `.env`
5. No `sk-` value appears in any printed output
6. Every request targets `localhost:8080`, never a provider domain
7. `.gitignore` contains `.env`
8. `raw_output.log` is writable

Phase A is done when all eight PASS. Show me that output in plain English. Do not ask me for a key, and do not start Docker.

**Then stop.** Phase B and C need me at the keyboard, and Phase C runs one block at a time with a PASS from me between each.
