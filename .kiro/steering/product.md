# Product steering: Heimdall

## What this is

A test harness, not a product. It exists to produce evidence for one dev.to article about role-based access control at an AI gateway.

Bifrost is the Norse rainbow bridge. Heimdall is the watchman who decides who crosses it. This repo is the watchman.

## What success looks like

A stranger clones this repo, adds their own API key, runs one script, and gets the same table we got. Reproducibility is the product.

## Who it is for

Two audiences:

1. Developers evaluating whether an AI gateway's access controls hold up.
2. Operations people who administer role-based access in other systems and want to know if this looks familiar.

The second audience is the one nobody else writes for. The author administers access for courtroom clerks, court reporters, and court interpreters across two courthouses. That perspective shapes what questions get asked.

## The question that makes this ours

**Does the audit log record attempted access that was denied, or only access that succeeded?**

Most systems log what happened. Fewer log what someone tried. In a regulated setting the attempt is often the thing you most need on record. That question drives Block 6 and it is the section of the article that no vendor-written post would contain.

## Out of scope, permanently

- Benchmarking speed or throughput
- Comparing Bifrost to other gateways
- Any claim about a tool we did not run
- Recommending or not recommending anything to anyone

We report what we set up and what we saw. Readers decide.

## Sponsorship

This work is sponsored by the Bifrost team at Maxim AI. The published article carries a disclosure at the top, not the end. The author retains editorial control over conclusions, including limitations. The sponsor reviews for factual accuracy and interlinking only.

This means findings that are unflattering still get published. That was agreed in writing before work started. If an agent working on this repo proposes softening a result, reject it.

## Honesty rules that apply to the artifacts, not just the article

- A limitation is a finding, not an apology.
- A setup that took longer than expected is data, and it gets recorded with the actual elapsed time.
- If we could not test something, the report says we could not test it. It does not go silent.
- No result is ever inferred. If it was not observed, it does not exist.

## Notes discipline (standing instruction, every block, no exceptions)

The agent enforces this for the rest of the project.

- At every checkpoint, before asking for a PASS, prompt Shara for a `NOTES.md` entry. Ask a **specific** question drawn from what just happened, never a generic "any notes?" Examples: "that took eleven minutes, did you expect that," or "the docs said X and it did Y, was that a surprise."
- Do not proceed to the next block until Shara answers, even if the answer is "nothing."
- Flag note-worthy moments **as they happen**, not only at checkpoints: anything much slower or faster than expected, any disagreement between docs and behavior, any error with unusual wording, anything worked around.
- The agent writes the **factual record only**: timings, what a step did, what the docs said versus what happened. Neutral and verbatim.
- The agent **never** writes Shara's reactions. Not what surprised her, annoyed her, or what she concluded. If the agent finds itself drafting a sentence that starts "I expected" or "I was surprised," it stops and asks her instead. Those sentences are the article and they have to be hers.
