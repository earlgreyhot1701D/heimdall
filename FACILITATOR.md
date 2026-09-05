# Facilitator checklist

Your job during the build. Print it, or keep it open in a second window.

You are not reading code. You are reading English, making judgment calls, and writing down surprises.

---

## Three phases

Only the third one needs you sitting there.

| Phase | What happens | You |
|---|---|---|
| **A. Build dry** | Kiro builds everything. No keys, no Docker, no network. Dry run asserts 8 self-checks. | Read the 8 PASS/FAIL lines. That is all. |
| **B. Smoke** | Add the provider key. Three direct calls, one per model. | 5 minutes, watch them return |
| **C. Live run** | Docker up, Blocks 1 through 7 | Present for all of it |

Phase A costs nothing and can run the night before. If it is finished before your live session, Saturday is not a build day at all. It is three hours of watching, which is what you are actually paying yourself to do.

**Phase A gate:** all 8 checks PASS.
**Phase B gate:** three completions returned.
Do not start Phase C until both.

---

## Before you start

**One OpenAI key, not three.** The price tiers are model tiers. One key reaches all three models. The three badges get created inside Bifrost later, and they are not OpenAI keys.

- [ ] Fresh OpenAI API key created
- [ ] Hard spend cap set on the OpenAI side, $5 or lower
- [ ] Docker running
- [ ] Three model names chosen and in `.env`
- [ ] Pre-flight passed: all three models returned a completion on a direct call, before Bifrost is involved
- [ ] `NOTES.md` open in a window that stays open
- [ ] Timer started, or at least a clock you glance at
- [ ] Phone face down

Write the start time in `NOTES.md` right now.

---

## Decisions that are yours, not the agent's

Make these before Block 3 so nobody has to guess.

**The three roles.** interpreter, reporter, clerk, ordered narrowest to widest by function, not seniority. Change the names if different ones read better in the article. These names show up in the piece, so pick ones that carry the idea.

**The limits.** Draft is in the PRD. The only one that matters technically is the interpreter budget at $0.05, because it has to be small enough to exhaust in a few calls.

**The three model names.** Pick them before you start so the matrix has something concrete to point at.

To see what your key can actually reach:

```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | grep '"id"'
```

Pick three at different price tiers, prefix each with `openai/`, and put them in `.env`. That is the only place they live. These are the models the badges reach for, not the model Kiro uses to write code.

**Some models are gated.** OpenAI restricts certain models by usage tier, which depends on how much the account has spent historically. Check the Limits page in the OpenAI dashboard to see your tier and what you have access to. Do not chase a gated model. Your "restricted" tier only needs to cost more than the other two.

**Then run the pre-flight.** Call all three models directly, bypassing Bifrost. All three must come back with a completion.

This is the step that makes the whole matrix readable. If a model is unreachable for your key, a failure later would be OpenAI rejecting you, not Bifrost denying you, and from the outside those look the same. Once all three are proven reachable directly, every denial you see afterward can only have come from the gateway.

If one fails, swap it for another from the models list and note the swap. That is housekeeping, not a finding.

---

## At every checkpoint

The agent stops and shows you a report block. You do four things.

1. Read the WHAT I DID section. Does it describe something you understand?
2. Read EXPECTED, then OBSERVED. Do they match?
3. If MISMATCH, **write it in `NOTES.md` before anyone changes anything.** What did you expect, what happened, how did you feel about it. That paragraph is worth more than the fix.
4. Say PASS or FAIL. Out loud is better than in your head.

If a report is written in language you cannot follow, that is a FAIL. Send it back and ask for it in plain English. You are the reader standing in for every reader of the article.

---

## Notes discipline (the agent enforces this every block)

A standing instruction for the rest of the project. The agent runs it; you answer.

- **Before** the agent asks for your PASS, it prompts you for a `NOTES.md` entry with a **specific** question about what just happened, not "any notes?" Something like "that took eleven minutes, did you expect that," or "the docs said X and it did Y, was that a surprise."
- The agent does **not** move to the next block until you answer, even if your answer is "nothing."
- The agent flags note-worthy moments **as they happen**, not only at checkpoints: anything much slower or faster than expected, docs disagreeing with behavior, an error with odd wording, anything it worked around.
- The agent writes the **factual record** into `NOTES.md`: timings, what a step did, docs versus behavior. Neutral and verbatim.
- The agent **never** writes your reactions. What surprised you, annoyed you, or what you concluded stays yours. Those sentences are the article. If the agent starts one with "I expected" or "I was surprised," it stops and asks you instead.

---

## The negative control (Block 4b, do not skip)

The one moment in the run where you prove the whole thing is real.

1. Note a call from Block 4 that succeeded.
2. Stop the Bifrost container.
3. Run that exact same call again.
4. It should fail with connection refused.
5. Restart the container. Run it once more. It should succeed.

Takes thirty seconds. Without it, a reader has only your word that these calls went through the gateway instead of straight to OpenAI. With it, the claim is checkable.

If step 4 does **not** fail, stop everything. Something else answered, and every result before this point needs explaining before anything gets published.

---

## The two spot-checks

Twice during the run, do this by hand:

1. Pick any line from `RUN_REPORT.md` that states a result.
2. Open `raw_output.log`.
3. Find the entry it refers to.
4. Confirm the report is telling the truth about what came back.

You are not reading code. You are checking that a summary matches its source, the same way you would check a report against a docket.

If it does not match, stop everything. Nothing publishes from a report you cannot trace.

Mark both spot-checks in `NOTES.md` with the time.

---

## The hard gates

**45 minutes, Block 1.** If no successful call has come back, stop. Write down where it stuck. The article becomes a setup-friction piece and that is a legitimate article. Do not push through in silence.

**Block 2, GO/NO-GO.** If RBAC roles or the audit log are missing or enterprise-gated, stop and message Swapnoneel before building further. Better to surface it Saturday than Sunday night.

**3 hours.** When you hit three hours, stop building. Whatever you have is the article. An unfinished test honestly reported is worth more than a finished one written at midnight.

---

## What goes in NOTES.md

Write in the moment, not after. Short is fine. Ugly is fine. Nobody reads this but you.

Capture:

- Anything you expected that did not happen
- Anything that happened that you did not expect
- Every place the docs and the behavior disagreed
- The exact wording of any error that surprised you
- How long a step actually took versus what you thought
- Anything that annoyed you. Annoyance is a reader's experience too.
- Anything that impressed you

Target at least five entries. If you get to the end with fewer than five, you were not watching closely enough, and you will feel that when you sit down to write.

---

## When you finish

- [ ] Revoke the OpenAI key
- [ ] `git log -p | grep -i "sk-"` returns nothing
- [ ] Screenshots checked for visible key material
- [ ] Repo pushed public
- [ ] Total elapsed time written in `NOTES.md`

Then close the laptop. The article gets written after, from `NOTES.md` and `RUN_REPORT.md`, not from the docs and not from memory.

---

## Before you publish

- [ ] Disclosure at the top of the post, not the end
- [ ] Byline is Earl Grey, and Swapnoneel knows to look for that handle
- [ ] Bifrost site and GitHub linked in the intro
- [ ] Docs linked in the body
- [ ] Repo linked so readers can check your work
- [ ] Every claim traces to `RUN_REPORT.md`
- [ ] Anything that broke is in there
- [ ] Run the dev.to pre-publish checklist
