# Notes

Yours. Written by hand, in the moment. Ugly is fine. Nobody reads this but you.

This file is the article. `RUN_REPORT.md` is the evidence, and this is the part only you can produce.

**Prompts, if you go blank:**
- What did I expect that did not happen
- What happened that I did not expect
- Where did the docs and the behavior disagree
- What exactly did the error say, and how did that land
- How long did that actually take
- What annoyed me
- What impressed me

Target five entries minimum. Timestamp each one.

---

**Start time:** 11:43 AM PST (Docker started, Block 1 begins)

---

[11:43 AM PST] Started Docker. Block 1 (the door opens) begins.

---

[Block 1, factual record]

Two setup blockers, both environmental, neither about Bifrost:

1. Docker Desktop was not running. Started it; the maximhq/bifrost image then pulled fine.
2. `docker run -p 8080:8080 maximhq/bifrost` failed: host port 8080 already in use. Verbatim error:
   "docker: Error response from daemon: ports are not available: exposing port TCP 0.0.0.0:8080 -> 127.0.0.1:0: listen tcp 0.0.0.0:8080: bind: Only one usage of each socket address (protocol/network address/port) is normally permitted."

Provenance artifact for Block 4b: image pulled with digest
sha256:cf71be9fad4e0749b6e26cbb774c687413dad9a0970b83f4e1dadb6f503ea208

45-minute gate: Block 1 started 11:43 AM PST. Gate is 12:28 PM PST.
[11:47 AM PST] 4 minutes elapsed. Both blockers diagnosed (Docker Desktop off, port 8080 held by a node server.js from yesterday 21:05). Awaiting Shara's A/B choice: free 8080 or remap. 41 minutes of headroom.

[11:49 AM PST] Decision: remap to 8090 (Option B). Reason recorded as a real constraint a reader might share: the process on 8080 was an unidentified `node server.js`, and Shara declined to stop a process mid-run that she could not identify. Updated BIFROST_URL in .env and .env.example to http://localhost:8090; updated the four gateway-script fallbacks from 8080 to 8090 so no literal disagrees with the configured address; rewrote dry-run Check 6 to derive the expected host:port from BIFROST_URL rather than asserting a hardcoded "localhost:8080". Reran the eight checks: 8 PASS, 0 FAIL. Check 6 now reports "route through BIFROST_URL (localhost:8090)".

Elapsed at 11:49 AM PST: 6 minutes into Block 1, 39 minutes of headroom against the 12:28 gate.

[11:52 AM PST] Ran `docker run -p 8090:8080 maximhq/bifrost` (host 8090 -> container 8080). 9 minutes into Block 1, 36 minutes of headroom against the 12:28 gate. Watching for the container to come up and the UI at http://localhost:8090.

[12:04 PM PST] First call succeeded. The door opened, inside the 45-minute gate (12:28).

Timing breakdown for Block 1 (factual):
- Block 1 started 11:43 AM PST. First successful call 12:04 PM PST. Total wall-clock: 21 minutes.
- The Bifrost container reported itself up at 11:52:34 local, per its own startup log.
- So of the 21 minutes, the stretch before 11:52 was environmental: Docker Desktop was not running, then host port 8080 was occupied (remap to 8090). That time is not attributable to Bifrost.
- From container-up (11:52:34) to first successful call (12:04): roughly 11-12 minutes, which covered opening the UI, adding the provider key, and running the first curl by hand.

[Shara, on the twelve minutes from container-up to first call] I think it's within expectable time for someone running this for the first time.

[Windows / PowerShell reproducibility note, 12:04 PM PST] The documented curl example does not work in PowerShell as written. Escaped double quotes failed, single quotes failed. Only feeding the body from a file with -d "@body.json" worked. This belongs in the README as a Windows note so a reader on PowerShell is not blocked at the first call.

[Shara, on what the dry run could and could not prove] The scripts ran in WSL all through Phase A and nobody asked whether WSL could reach the container, because nothing was reaching anything yet. The dry run proved the harness was correct and could not prove it was connected. That gap only appears at the moment you go live, and it is the honest limit of what a dry run buys you.

[12:08 PM PST, factual] WSL probe: ran 01-first-call.sh from WSL against http://localhost:8090. Returned HTTP 200 with a real completion. WSL's localhost reached the container; Git Bash fallback not needed. The matrix will run in WSL. The probe also closed an evidence gap: the first successful call is now in raw_output.log (lines 203-204, role=none(unauth), http=200), where before it existed only as a by-hand PowerShell call Shara had witnessed. The logged response carries Server: fasthttp and a family of X-Bifrost-* headers (Trace-Id, Provider, Original/Resolved-Model, Routing-Info-Key: Heimdall, Upstream-Latency), which a provider would never stamp. That is the address-and-headers half of the Block 4b provenance proof, banked early.

[Block 2, factual] GO with a scope change. In the OSS build: "Roles & Permissions" (RBAC) is present. Audit Logs is enterprise-gated, not available in OSS; screenshot captured. The sponsor had stated both were in the OSS build; roles are, the audit log is not. This is a partial mismatch against the sponsor's statement, recorded as a finding.

Block 6 redirected as a result: instead of the (paywalled) Audit Logs, we test whether Observability > LLM Logs records a denied request and what fields it captures. The LLM Logs status filters include "Error", so there is somewhere for a denial to land. That is the record an OSS user actually has.

[Shara, on the LLM Logs cost display] Two calls already in LLM Logs, both mine, total cost showing $0.

[Block 3, finding, the two-controls trap] In the Bifrost UI, "Model budgets" and "Access & rate limits" are two separate controls, and the one that looks like scoping is not the one that scopes access. A per-model budget (e.g. $0.05 on luna) caps what that model may SPEND. It does not restrict which models the key can REACH. The access scope is a different control: the bottom row read "Access & rate limits - All keys - All models - No rate limits", meaning that at that moment the interpreter key could reach all three models. The $0.05 only capped luna's cost; if interpreter had called astra, it would have gone straight through.

Why this matters: configure only the budget and you have a key you BELIEVE is restricted but is not. That would have quietly broken the entire matrix. Every one of the nine calls would have come back ALLOWED, the expected-vs-observed table would have shown six mismatches, and the natural next move would have been to go hunting for a bug in the harness, when the harness was correct and the gateway config was the problem. The pre-flight guarantees provider reachability, so a false ALLOW here could only have come from an unset access scope, but you would not know that without knowing these are two controls.

The fix: for each role, set the ACCESS scope (allowed models) in "Access & rate limits", not just the per-model budget. interpreter -> routine only; reporter -> routine + standard; clerk -> all three. The budgets stay as the spend cap on top.

This is the first finding that is about Bifrost's own design rather than the harness or the Windows environment: a naming/placement choice in the UI where the control that reads like access scoping is the budget, and the real access scope lives elsewhere and defaults to "all models" open.

[Block 3, factual] The UI exposes a budget level the docs do not document. There are five separate places on one form to set a spending limit.

[Shara's reaction] Said "lord" out loud at the five spending-limit controls on one form.

[Block 4, the falsification test]

The working framing (relayed from a conversation with Claude): don't verify trust; make specific claims falsifiable and then try to falsify them. Four things already protected the clean 6/3 result, but none of them could tell apart a harness reporting OBSERVATIONS from one reporting EXPECTATIONS: (1) expectations were declared before the run and came from the Block 3 decisions, so the script could not retrofit them; (2) the denial text says "not allowed for this virtual key" with type model_blocked, and OpenAI has no concept of a virtual key, so that string could not have come from the provider; (3) every claim cites a log line she can open herself; (4) the Block 4b negative control is the one test whose answer is known in advance. Only a deliberate divergence test distinguishes observation from expectation.

The test: Shara hand-added gpt-5.6-terra to the interpreter role in the Bifrost UI. The agent changed no config and did not alter the expected table. Then reran 02-matrix.sh. Prediction: interpreter/terra should flip from DENY to a reported MISMATCH, because the script still predicts DENY while the live config now permits it. That mismatch was the desired result, not a failure to fix.

Result: MISMATCH on interpreter/terra exactly as predicted. First run returned 403 (raw_output.log line 294, 19:47:25); after the hand-edit the same call returned 200 with a real completion (line 649, 19:53:41). Both entries carry EXPECTED=DENY. The append-only log holds both states side by side. The other eight calls were unchanged.

What it proves: the harness reports what happened, not what it hoped to see. A harness echoing its own expected table would have reported MATCH here, and that silence would have been the real failure. The expected table was left reading DENY for that cell throughout; the divergence surfaced on its own.

Planned third run: Shara removes terra from the interpreter role, then the agent reruns. Expected to return to a clean MATCH (six allowed, three denied). If that flip-back does not happen, stop, because a scope that will not un-set is a bigger problem than any single matrix result.

Third run result: MATCH restored. interpreter/terra flipped back to 403 (raw_output.log line 1021, 19:56:17). Full three-state sequence now in the append-only log: 403 (line 294) -> 200 (line 649) -> 403 (line 1021). Recorded as its own numbered checkpoint, 4a, in RUN_REPORT.

[Shara, Q1 - why the falsification test was worth more than the clean 6/3, verbatim] Because I have learned the hard way that sometimes I assume what I'm building is green and it is green, but it's not the behavior I expected. Adding the mismatch verifies the first behavior I built was not only expected but correct for the build.

[Shara, Q2 - watching it report against its own incentive, verbatim] I was apprehensive, because if it didn't test as expected then it would have been me back to the drawing board. Like, really back to the drawing board.

[On why the agent runs 4b and not Shara, Shara's words] I ran the falsification test first, and that's what earned this. Before 4a I had no independent reason to trust a report from the harness. After it, I do.

[Shara, after 4b, verbatim] I don't exactly understand what I'm being asked, but 4a gave me the confidence, with the additional unplanned but necessary testing. My insight here now is how valuable gating access is for users of an application, not just the one at the courts. Least access is a must and just good hygiene. That's my opinion anyway.

[Process note, Shara's feedback on the notes prompts] The 4b question was too abstract to answer directly. Keep the prompts concrete and simple for the rest of the run. Example she gave: "What convinced you, 4a or 4b?" would have gotten a cleaner answer than asking her to rank which was decisive.

[Block 5, factual] Budget exhaustion test attempted, then cut from scope. 200 calls on the interpreter role (luna) all returned 200; the $0.05 cap never engaged. Cause: 200 one-word "hello" calls cost about $0.0016 total, nowhere near $0.05. Not a test of enforcement. The cause was the test design, not Bifrost. Moved budget enforcement to the "did not test" list. No config changed, no rerun.

[Observation kept for the article, Shara's point] A spend cap is meaningless unless you already know your per-call cost, and the place you set the cap does not tell you what a call costs.

[Block 6, factual] The article's central question, answered. In Observability > LLM Logs, filtering Status = Error returned exactly 8 entries, matching the 8 denials across the three matrix passes. Denied access IS recorded in the OSS view; nothing was silently dropped. The entry carries the reason verbatim ("Model 'gpt-6-astra' is not allowed for this virtual key"), plus status ERROR, HTTP 403, a request ID, timestamp to the second, and the model requested. A denied call shows latency 0ms and blank tokens/cost: the refusal happens at the gateway before reaching OpenAI, so a denial is free. Open item, not concluded: the entry does not name the virtual key or role in the main view; three UI places (More details, Routing tab, Raw JSON) still to be checked before deciding whether the finding is "captured but not surfaced" or "who was refused is not recorded at all".

[Shara, on the dashboard, verbatim] This error log and dashboard has been easier for me to use than Vercel and the AWS console. I use both.

[Block 6 resolved, factual] Checked all three UI places. The virtual key IS captured: More details > Request Details > VIRTUAL KEY: reporter, a link to that key's config page with its UUID. True finding is "captured but not surfaced in the main view." The other candidate ("who was refused is not recorded") is false and was not recorded. Two more findings from that view: (a) the timing breakdown itemizes gateway overhead with the governance check on its own line, 497 us total / 142 us Governance plugin / 0.00 ms upstream, so the permission check is visible and timed; (b) on a denied entry the Raw JSON tab says "No raw JSON available", fine for reading on screen, a limit for exporting.

[Shara's observation for the report, verbatim] The record is complete and producible. My only criticism is placement. "Who" is the first question I ask about a refusal, not the fourth.

[Block 6 correction, factual] Downloaded the JSON export of a denied request (evidence/denial-export-0c0c4444.json). "No raw JSON available" refers only to raw_request/raw_response, which are empty because the call never went upstream. The record itself exports in one click and carries more than the screen: virtual_key_name "reporter", virtual_key_id, error_details.type "model_blocked", and the full overhead_breakdown with plugin.governance at 141.562 us. So the earlier "not exportable" reading was wrong and has been corrected in the report. The export also has user_id, team_id, customer_id, business_unit_id, all null in this run (only virtual keys were set up, nothing above them); recorded under "what I did not test." Confirmed clean before citing: virtual_key.value is an empty string, no API keys in the file.

[Secret-scan limitation, factual] git log -p | grep -i "sk-" reads text only, not inside PNGs. Both screenshots checked by eye: they show a virtual key name and request IDs, no sk- values. Recorded in the report so a reader knows text files were machine-scanned and image files were eyeballed.

[Shara, on Block 5 and Block 6, verbatim] This is the first time I've used Bifrost, so I had no expectation about refusals to be surprised against.

DRIFT-CATCH TALLY: this is the THIRD time in this build a check keyed to a literal would have drifted out from under us. First "badge=" (the matrix rename), then the tier rename (cheap/mid/expensive -> routine/standard/restricted), now the port (8080 -> 8090). Each time the fix was the same shape: key the check to the config/source of truth, not to a copy of the value written into the check itself.

---

[Phase A]

The dry-run self-check caught the harness writing six lines into raw_output.log during a dry run. The logging helpers were writing unconditionally, so a self-check that is supposed to touch nothing was quietly appending to the one file that is the evidence for every claim in the article. If that had slipped through, the file that proves the results would itself have been written to by something other than a real call. Caught for free, before a key existed, before a dollar was spent. This is the concrete example for the build-process section: the check that protects the evidence nearly corrupted the evidence, and the harness testing itself is what surfaced it.

---

[Phase A, during the role reorder]

Second version of the same failure mode. Check 1 counts the nine matrix calls by matching the printed line, and that line said "badge=". When the reorder renamed badge to role, the line became "role=" and the matcher would have counted zero. A check that reads zero calls and then reports PASS is worse than having no check at all, because it looks like coverage while providing none. The lesson: never key a check to a human-readable string a rename can silently break. Fixed the matcher this time; the deeper fix is to key checks to something structural that does not drift.

---

[Phase B, before pasting the key]

git check-ignore .env came back "fatal: not a git repository" and my first instinct read it as alarm: my key file might not be protected. It wasn't that at all. There was simply no git repo yet, so nothing could commit anything, so the key could not leak. The report explained the difference instead of just stamping FAIL and moving on, and that distinction is the whole reason the plain-English reporting rule exists: a raw FAIL would have sent me looking for a problem that wasn't there, or worse, waved me past a real one some other day. Two things worth holding onto. First, "the guard fired" and "there is a problem" are not the same event, and only the explanation tells them apart. Second, this is now the third time a guard has surfaced something about the harness itself (dry-run writing to the log, the badge= matcher, now the ignore check) rather than anything about Bifrost. We have not tested the actual subject yet and the harness has already caught itself three times. That is either the harness earning its keep or a sign the subject is going to be the easy part. Fixed by running git init early and proving the ignore before the key exists, which also improved the plan: initialize around an empty folder, not around one already holding a secret.

---

[HH:MM]


---

[HH:MM]


---

[HH:MM]


---

[HH:MM]


---

[HH:MM]


---

**Spot-check 1 done at:**

**Spot-check 2 done at:**

**Stop time:**

**Total elapsed:**

---

## After, before writing

Three questions to answer from the notes above, in your own words, before you open the article draft.

**1. What is the one thing I know now that I did not know Saturday morning?**


**2. What would I tell someone who was about to do this themselves?**


**3. What is the honest headline? Not the flattering one, not the harsh one. The accurate one.**


---

Do not write the title until question 3 has an answer. The title needs a turn in it, and the turn is whatever happened, not whatever you hoped would happen.
