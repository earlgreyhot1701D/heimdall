# Run report

Plain-English record of what happened, appended after every block.

Every claim in this file traces to a line in `raw_output.log`. If it does not, it does not belong here.

**Run started:** [fill in]
**Run finished:** [fill in]
**Total elapsed:** [fill in]

---

## PHASE A: Build dry (no keys, no Docker, $0)
Time: 2026-09-05 (UTC)

WHAT I DID

I built the whole harness with no keys and Docker never started: a shared helper library, the Bifrost config skeleton with the three roles, five block scripts (pre-flight, first call, matrix, provenance, budget trip), and a self-check script. Then I ran the self-check, which exercises every script in dry-run mode (each prints the exact request it would send and makes no network call) and reports PASS or FAIL for eight things. Nothing reached the network and no money was spent.

| # | Check | Result |
|---|---|---|
| 1 | Exactly 9 role-model combinations generated | PASS |
| 2 | Expected table sums to 6 ALLOW, 3 DENY | PASS |
| 3 | Every referenced variable exists in `.env.example` | PASS |
| 4 | No model name hardcoded outside `.env` | PASS |
| 5 | No `sk-` value in any printed output | PASS |
| 6 | Every request targets `localhost:8080` | PASS |
| 7 | `.gitignore` contains `.env` | PASS |
| 8 | `raw_output.log` writable | PASS |

EXPECTED:
All eight checks PASS with no network call and no writes to `raw_output.log`.

OBSERVED:
All eight PASS. After a full dry run `raw_output.log` is 0 bytes, confirming dry mode writes no evidence.

Two failures surfaced during the build and were fixed before this PASS. Both are recorded here rather than smoothed over, because catching them is what Phase A is for:

1. The self-check flagged two `sk-bf-` strings printed by the provenance script. They were description text, not real keys, but a check that bans `sk-` in output should not have to tell the difference. I reworded the two lines to say "virtual-key credential" instead of printing the literal token.
2. The first run left six header lines in `raw_output.log` during a dry run. Cause: the logging helpers wrote unconditionally, and the matrix, pre-flight, and budget scripts announce their log section before checking dry mode. Fix: the logging helpers now do nothing at all under dry run, so no script can write to the evidence file during a self-check regardless of ordering. The six junk lines (created only by that bug, before any real run, containing no evidence) were cleared and the log confirmed empty after the fix.

Two intentional exceptions are shown in the check output rather than hidden, as agreed:
- Check 4: model names live only in `.env`; `config.json` also names models because it is Bifrost's allowlist config, which the check exempts and states.
- Check 6: `00-preflight.sh` is the one script that targets `api.openai.com` by design (the pre-flight must bypass Bifrost). The check names it as the explicit exception; the four gateway scripts target `localhost:8080` only.

Notes on the five constraints Shara added before the build:
- `raw_output.log` is append-only. Every write uses `>>`. No script truncates or rotates it.
- Allow/deny never sets an exit code. Scripts exit non-zero only if the harness itself breaks (missing variable, unwritable log).
- The negative control in `02b` is not run by the script. It prints the stop/start commands and prompts Shara to run them by hand.
- `.gitignore` is never created or edited. Check 7 reads it and reports PASS/FAIL.
- The self-check runs with no `.env` present, validating against `.env.example` only.

EVIDENCE: `scripts/99-dryrun-checks.sh` output (8 PASS, 0 FAIL, gate PASS). No `raw_output.log` entries by design; the log is 0 bytes after the dry run.

GATE: all 8 PASS before Phase B. SHARA: PASS / FAIL

---

## PHASE B: Smoke (key added, Bifrost not yet running)
Time:

Three direct calls to the provider, one per model. Bifrost is not in the picture.

GATE: three completions returned. All three passed. Recorded at Checkpoint 0 below. SHARA: PASS / FAIL

---

## CHECKPOINT 0: Prep and pre-flight
Time: 2026-09-05 18:30-18:31 UTC

WHAT I DID

I called each of the three models directly against api.openai.com, one call each, with Bifrost not involved at all. The point was to prove the key can reach all three before the gateway enters the picture, so that any denial we see later can only have come from the gateway. Each call sent the single word "hello" and each came back with a real reply.

**The three models under test** (set in `.env`, one provider key reaches all three):

Tier labels name the access level, not the cost: routine (anyone doing the work), standard (middle), restricted (needs a reason).

| Tier | Model name | Pre-flight direct call | HTTP status |
|---|---|---|---|
| routine | openai/gpt-5.6-luna | PASS | 200 |
| standard | openai/gpt-5.6-terra | PASS | 200 |
| restricted | openai/gpt-6-astra | PASS | 200 |

OpenAI usage tier of this account: not separately recorded; all three models were reachable with this key, which is what the pre-flight needed to establish.
Any model swapped out because it was gated or unreachable: none. All three worked on the first try.

All three must PASS before Block 1. Without that, a later provider-side rejection would be indistinguishable from a gateway denial.

EXPECTED:
Each of the three models returns a completion (HTTP 200) on a direct call.

OBSERVED:
All three returned HTTP 200 with a genuine completion (each response carried a chatcmpl id, an assistant reply, and token usage). routine and standard replied "Hello! How can I help you today?"; restricted replied "Hello! How can I help?". The exact text does not matter; the 200 and the completion do.

MATCH / MISMATCH: MATCH. Three for three.

Note: the key did not appear anywhere in the log. The long `__cf_bm` strings in the `set-cookie` headers are Cloudflare bot-management cookies from OpenAI's edge, not credentials, and they expire within 30 minutes.

EVIDENCE: `raw_output.log`, PREFLIGHT section. The three log header lines read `role=n/a(direct) | model=gpt-5.6-luna | http=200`, `... gpt-5.6-terra | http=200`, and `... gpt-6-astra | http=200`, each followed by the verbatim response including the completion body.

SHARA: PASS / FAIL

---

## CHECKPOINT 1: The door opens
Time: 2026-09-05, started 11:43 AM PST

WHAT I DID
Attempted to start Bifrost in Docker on Windows. Two environment blockers hit before the gateway came up, neither related to Bifrost:
1. Docker Desktop was not running. Started it; the image then pulled fine.
2. `docker run -p 8080:8080 maximhq/bifrost` failed because host port 8080 was already occupied by another process (see below).

**Provenance artifact (belongs to Block 4b, recorded here so it is not lost):**
The `maximhq/bifrost` image pulled with digest `sha256:cf71be9fad4e0749b6e26cbb774c687413dad9a0970b83f4e1dadb6f503ea208`.

**Verbatim error from the failed `docker run`:**
```
docker: Error response from daemon: ports are not available: exposing port TCP 0.0.0.0:8080 -> 127.0.0.1:0: listen tcp 0.0.0.0:8080: bind: Only one usage of each socket address (protocol/network address/port) is normally permitted.
```

After remapping the host port to 8090 (8080 was occupied), the container started, the UI loaded, the provider key was added through it, and the first unauthenticated call was run by hand against `http://localhost:8090/v1/chat/completions`.

EXPECTED:
A single unauthenticated call to the gateway (`$BIFROST_URL`, now `http://localhost:8090`) returns a response from the model.

OBSERVED:
The first call succeeded. The gateway answered.

Timing:
- Block 1 started 11:43 AM PST; first successful call 12:04 PM PST. Total wall-clock: 21 minutes, inside the 45-minute hard gate (12:28 PM PST).
- The Bifrost container reported itself up at 11:52:34 local, per its own startup log.
- The gap before 11:52 was environmental, not Bifrost: Docker Desktop was not running, then host port 8080 was occupied (leading to the 8090 remap). From container-up to first successful call was roughly 11-12 minutes, covering UI open, key entry, and the hand-run curl.

Elapsed from `docker run` to first successful response: container started 11:52 AM PST, first success 12:04 PM PST, ~12 minutes.

MATCH / MISMATCH: MATCH. The door opened. Two setup blockers were recorded along the way (Docker Desktop off, port 8080 occupied); both were environmental and neither was about Bifrost.

EVIDENCE: verbatim `docker run` port-collision error above; image digest `sha256:cf71be9...ea208` above; container self-reported up at 11:52:34 local. First-call response body captured to `raw_output.log` via the WSL probe run of `01-first-call.sh` (see BLOCK 1 section of the log).

SHARA: PASS. First call succeeded through the gateway at 12:04 PM PST.

---

## CHECKPOINT 2: RBAC roles and audit log located (GO / NO-GO)
Time: 2026-09-05, Block 2

WHAT I DID
Looked in the running OSS build's web UI for the two things the sponsor said would be there: custom roles (RBAC) and an audit log. Found one, not the other.

EXPECTED:
Custom roles and an audit log are both present in the OSS build, as the sponsor stated (the sponsor stated both were in the OSS build).

OBSERVED:
- RBAC / custom roles present: YES. "Roles & Permissions" is present in the OSS build.
- Audit log present: NO in OSS. The Audit Logs feature is enterprise-gated, not available in the OSS build. Screenshot captured.
- Anything gated behind enterprise: the Audit Logs feature specifically.

MATCH / MISMATCH: PARTIAL MISMATCH against the sponsor's statement. Roles are in OSS as stated; the audit log is not, it is enterprise-gated. This is a finding, recorded plainly rather than smoothed over.

DECISION: GO, with a scope change to Block 6. Roles being present is enough to build the virtual keys and run the matrix. The audit-log question (Block 6) is redirected to the record an OSS user actually has: Observability > LLM Logs. See the revised Block 6 below.

EVIDENCE: screenshot of the enterprise-gated Audit Logs (in `/screenshots`). RBAC located in the UI as "Roles & Permissions".

SHARA: PASS (GO with scope change)

---

## CHECKPOINT 3: Three roles created
Time: 2026-09-05, Block 3

WHAT I DID
Created the three roles as virtual keys in the Bifrost web UI. For each, set the ACCESS scope (allowed models) under "Access & rate limits" so the key can only reach its permitted models, and set the spending cap at the virtual-key level. Pasted the three `sk-bf-*` values into `.env` (never committed).

Method used (web UI / REST API / config.json), and why:
Web UI. Two deliberate choices recorded:
1. **Access scope set under "Access & rate limits", not via a per-model budget.** During setup we found that "Model budgets" caps what a model may spend but does NOT restrict which models a key can reach; the real access control is the allowed-models scope, which defaulted to "All models" open. Setting only the budget would have left a key that looks restricted but is not, and every matrix call would have come back ALLOWED. So the allowed-models access scope is the control that enforces the matrix. (See NOTES.md, Block 3 finding.)
2. **Budgets set at the virtual-key level, not the model level.** Per-model budgets are not documented, so we did not rely on them. The virtual-key-level spending cap is the documented control, so each role's budget lives there.

| Role | Allowed models (access scope) | Budget (VK-level) | Reset |
|---|---|---|---|
| interpreter | routine only (luna) | $0.05 | 1d |
| reporter | routine + standard (luna, terra) | $1.00 | 1d |
| clerk | all three (luna, terra, astra) | $5.00 | 1d |

EXPECTED:
Three virtual keys exist with the access scopes and budgets above. The access scope, not the budget, is what will make the matrix deny.

OBSERVED:
Three roles created in the UI; access scope and budget set per the table; the three `sk-bf-*` values are in `.env`. The matrix in Block 4 is the live proof that the access scopes actually hold.

MATCH / MISMATCH: MATCH at configuration time. Behavioural confirmation comes from the Block 4 matrix.

EVIDENCE: three `VK_*` values present in `.env` (values not recorded here or in the log). Access scopes and budgets as configured in the UI. The nine matrix results (Checkpoint 4) will confirm the scopes deny as expected.

SHARA: PASS / FAIL

---

## CHECKPOINT 4: The permission matrix
Time:

WHAT I DID
Ran nine calls. Each role against each model.

EXPECTED:

Roles ordered narrowest to widest by function, not seniority.

| Role | routine | standard | restricted |
|---|---|---|---|
| interpreter | ALLOW | DENY | DENY |
| reporter | ALLOW | ALLOW | DENY |
| clerk | ALLOW | ALLOW | ALLOW |

6 allowed, 3 denied.

OBSERVED (one sentence per call, in order):

- interpreter tried luna: allowed (HTTP 200), as expected
- interpreter tried terra: denied (HTTP 403), as expected
- interpreter tried astra: denied (HTTP 403), as expected
- reporter tried luna: allowed (HTTP 200), as expected
- reporter tried terra: allowed (HTTP 200), as expected
- reporter tried astra: denied (HTTP 403), as expected
- clerk tried luna: allowed (HTTP 200), as expected
- clerk tried terra: allowed (HTTP 200), as expected
- clerk tried astra: allowed (HTTP 200), as expected

| Role | routine (luna) | standard (terra) | restricted (astra) |
|---|---|---|---|
| interpreter | ALLOW (200) | DENY (403) | DENY (403) |
| reporter | ALLOW (200) | ALLOW (200) | DENY (403) |
| clerk | ALLOW (200) | ALLOW (200) | ALLOW (200) |

Verbatim text of each denial:

All three denials are the same shape, differing only in the model named. The body, verbatim:

```
{"type":"model_blocked","is_bifrost_error":false,"status_code":403,"error":{"message":"Model 'gpt-5.6-terra' is not allowed for this virtual key"},"extra_fields":{"routing_info":{},"provider":"openai","original_model_requested":"gpt-5.6-terra","resolved_model_used":"gpt-5.6-terra","request_type":"chat_completion"}}
```

The other two are identical except the model name: interpreter/astra and reporter/astra both read `"Model 'gpt-6-astra' is not allowed for this virtual key"`. Each 403 also carried gateway-stamped headers (`Server: fasthttp`, `X-Bifrost-Trace-Id`, `X-Bifrost-Provider`, etc.). The phrase "not allowed for this virtual key" is gateway vocabulary; a provider never speaks of virtual keys.

MATCH / MISMATCH
>>> MATCH. All nine calls matched their predicted outcome. Six allowed, three denied, which is what we expected.

EVIDENCE: `raw_output.log`, BLOCK 4 section beginning line 248. The three 403 header lines are at lines 294 (interpreter/terra), 322 (interpreter/astra), and 440 (reporter/astra); their verbatim JSON bodies at lines 318, 346, and 464.

SHARA: PASS / FAIL

---

## CHECKPOINT 4a: Falsification test, does the harness report observations or expectations?
Time: 2026-09-05, Block 4 (three matrix runs, 19:47 / 19:53 / 19:56 UTC)

WHAT I DID
A clean 6-allowed / 3-denied result on the first run is consistent with two very different harnesses: one that reports what actually happened, and one that just echoes the expected table it was given. Those two are indistinguishable on a passing run. The only way to tell them apart is to make reality diverge from the prediction and see whether the report notices.

So we ran the same nine-call matrix three times, changing one live config setting by hand between runs and never touching the script's expected table (which reads interpreter/terra = DENY throughout):

1. **Run 1 (baseline).** interpreter role scoped to routine only. interpreter/terra returned 403 (denied), matching the DENY prediction.
2. **Run 2 (config changed).** Shara hand-added gpt-5.6-terra to the interpreter role in the Bifrost UI. The agent changed no config and did not alter the expected table. interpreter/terra now returned 200 with a real completion. The script still predicted DENY, so it reported this as a MISMATCH on exactly that one call, naming it and stating the direction. The other eight calls were unchanged.
3. **Run 3 (config reverted).** Shara removed terra from the interpreter role. interpreter/terra returned 403 again, back to a clean MATCH, six allowed and three denied.

EXPECTED:
Run 1 all MATCH; Run 2 a MISMATCH isolated to interpreter/terra (ALLOW observed vs DENY predicted); Run 3 back to all MATCH. If Run 2 had reported MATCH, the harness would be echoing expectations, not observing. If Run 3 had not flipped back, the access scope would not un-set, a bigger problem than any single result.

OBSERVED:
Exactly that. interpreter/terra: 403 -> 200 -> 403, tracking the live config each time while the predicted value stayed DENY. Run 2's report flagged the single mismatch and did not smooth it over. Run 3 returned to 6 ALLOW / 3 DENY.

The three states, in the append-only log, spot-checkable by hand:
- 403 (denied): `raw_output.log` line 294, timestamp 19:47:25Z, Content-Length 317, type model_blocked
- 200 (allowed, after adding terra to interpreter): line 649, timestamp 19:53:41Z, real completion, Content-Length 1334
- 403 (denied, after removing terra): line 1021, timestamp 19:56:17Z, Content-Length 317, type model_blocked
All three carry EXPECTED=DENY, because the script's prediction never changed. Only the live gateway behaviour changed, and only run 2 reported a mismatch.

MATCH / MISMATCH: this checkpoint is itself a MATCH against its design. The harness reported observations, not expectations. A table-echoing harness would have reported MATCH on run 2; it reported MISMATCH. The access scope both engaged and disengaged on demand.

Why this is the strongest evidence in the run: every other control (pre-declared expectations, gateway-only denial vocabulary, per-claim log citations, the negative control) is necessary but none of them, alone, proves the report is not simply repeating its own expected table. This does. It is findable here as its own checkpoint rather than buried in Checkpoint 4.

EVIDENCE: `raw_output.log` lines 294, 649, 1021 (the three interpreter/terra states with timestamps and Content-Lengths above).

SHARA: PASS / FAIL

---

## CHECKPOINT 4b: Provenance, how we know it went through Bifrost
Time: 2026-09-05, negative control run 20:03 UTC

WHAT I DID
Recorded the evidence that these calls passed through the gateway rather than going straight to the provider, and ran the negative control: picked a call that succeeds, stopped the container, confirmed the same call then fails, restarted, confirmed it succeeds again.

**Environment**
- `docker ps` output: `5d1ed97dd0a6  maximhq/bifrost  "/app/docker-entrypo…"  Up ~1 hour (healthy)  0.0.0.0:8090->8080/tcp, [::]:8090->8080/tcp  fervent_galileo`
- Image digest: `sha256:cf71be9fad4e0749b6e26cbb774c687413dad9a0970b83f4e1dadb6f503ea208` (matches the digest captured at Block 1)
- Bifrost version: not separately queried; identified by image digest above and `Server: fasthttp` on every gateway response
- Run date/time (UTC): `Sat Sep 5 20:02:45 UTC 2026` (from `date -u`)

**1. The address**
Full request URL used on every call: `http://localhost:8090/v1/chat/completions` (BIFROST_URL, the gateway). No call in the matrix or negative control targeted a provider domain.

**2. The credential**
Did any outbound request from the scripts carry a provider key? NO.
The client held only: `sk-bf-*` virtual-key values from `.env`. Those cannot authenticate to OpenAI, yet the allowed calls returned real completions, so something upstream (Bifrost) substituted the real provider key. That credential asymmetry is the strongest single proof.

**3. Response headers**
Verbatim gateway-stamped headers present on every response (from the first-call log entry and every matrix/negative-control response):

```
Server: fasthttp
X-Bifrost-Trace-Id: <per-request>
X-Bifrost-Provider: openai
X-Bifrost-Original-Model: <requested model>
X-Bifrost-Resolved-Model: <resolved model>
X-Bifrost-Request-Type: chat_completion
X-Bifrost-Routing-Info-Key: Heimdall   (on allowed calls)
X-Bifrost-Upstream-Latency-Ms: <ms>    (on allowed calls)
```

Gateway-stamped headers present: YES. `Server: fasthttp` (not Cloudflare) and the `X-Bifrost-*` family. A provider never stamps these; they can only originate at the gateway.

**4. Denial vocabulary**

Cross-reference the pre-flight: all three models returned completions on direct calls at Checkpoint 0. Any denial observed in Checkpoint 4 therefore originated at the gateway, not the provider.

Denial text that could only have come from the gateway (verbatim, raw_output.log line 318):

```
{"type":"model_blocked","is_bifrost_error":false,"status_code":403,"error":{"message":"Model 'gpt-5.6-terra' is not allowed for this virtual key"},"extra_fields":{"routing_info":{},"provider":"openai","original_model_requested":"gpt-5.6-terra","resolved_model_used":"gpt-5.6-terra","request_type":"chat_completion"}}
```

The phrase "not allowed for this virtual key" and the type `model_blocked` are gateway concepts. OpenAI has no notion of a virtual key, so this could not have come from the provider.

**5. Negative control**
Chosen call: clerk -> luna (routine), which returned 200 in the third matrix pass. Stopped the container (`docker stop fervent_galileo`), reran the exact same call, then restarted (`docker start fervent_galileo`) and reran once more.

EXPECTED: connection refused while the container is down; success again after restart.

OBSERVED (all three states in the append-only log):
- Baseline, container up: HTTP 200, real completion. `raw_output.log` line 1332, 20:03:11Z.
- Container stopped, same call: FAILED. Verbatim (line 1380):

```
curl: (7) Failed to connect to localhost port 8090 after 0 ms: Could not connect to server
```

- Container restarted, same call: HTTP 200 again. `raw_output.log` line 1385, 20:03:19Z.

Restarted the container, reran the same call. Succeeded again: YES.

MATCH / MISMATCH: MATCH. The call succeeded only while Bifrost was running and failed with connection refused the moment it was stopped. Nothing else was answering on 8090.
>>> The negative control DID fail as required. No stop-everything condition.

**The one-sentence version a skeptical reader would accept:**
Every call went to localhost:8090 carrying only a Bifrost virtual key (which cannot reach OpenAI on its own), the responses were stamped with `X-Bifrost-*` headers and `Server: fasthttp`, denials used gateway-only language about virtual keys, and the exact same successful call failed with connection refused the instant the Bifrost container was stopped and worked again once it restarted, so the traffic could only have passed through Bifrost.

EVIDENCE: `raw_output.log` lines 1332 (200 up), 1380 (`curl: (7)` connection refused, stopped), 1385 (200 restarted); denial body line 318; first-call gateway headers line ~204. Environment facts (docker ps, digest, date -u) above.

SHARA: PASS / FAIL

---

## CHECKPOINT 5: Running out of money — ATTEMPTED, NOT COMPLETED (cut from scope)
Time: 2026-09-05, Block 5 attempt 20:07 UTC

STATUS: Attempted, not completed. Cut from scope. This is not a test of budget enforcement, because the budget was never approached.

WHAT I DID
Looped calls on the interpreter role against its allowed model (luna) intending to exhaust the $0.05 daily budget. Ran 200 calls; all 200 returned HTTP 200. The cap never engaged.

WHY IT WAS NOT A REAL TEST
The prompt is a single word ("hello"), roughly 19 tokens per call. 200 calls generated on the order of $0.0016 in spend, so the $0.05 cap was never anywhere near being reached. The test design (tiny prompt, 200-call cap) could not generate enough spend to trip the budget in a reasonable number of calls. The cause is the test design, not Bifrost. Nothing here is a finding about the product's enforcement, because enforcement was never exercised.

DECISION: Budget enforcement is moved to the "What I did not test (STUB)" list. The article's argument is about permissions and evidence — the matrix, the falsification test (4a), and the negative control (4b) — and does not depend on the budget thread. No config was changed and the loop was not rerun.

OBSERVATION KEPT FOR THE ARTICLE (an operator point, not a product test result):
A spend cap is meaningless unless you already know your per-call cost, and the place you set the cap does not tell you what a call costs. An operator who sets "$0.05/day" without knowing per-call spend has set a control they cannot reason about.

EVIDENCE: `raw_output.log`, BLOCK 5 section beginning line 1429; 200 consecutive http=200 entries, no budget-exceeded response present.

SHARA: cut from scope (attempted, not completed)

---

## CHECKPOINT 6: The logbook question
Time:

SCOPE CHANGE (from Checkpoint 2): the Audit Logs feature is enterprise-gated and not in the OSS build. The dedicated audit log we planned to inspect does not exist for an OSS user. So this block is redirected to the record an OSS user actually has: **Observability > LLM Logs**. Its status filters include "Error", so a denied request has somewhere to land. The question is unchanged in spirit: does the record show attempted-and-denied access, or only what succeeded?

WHAT I DID
Opened Observability > LLM Logs (not the enterprise Audit Logs, which OSS does not have) and checked whether the denied matrix calls appear and what fields are captured.

EXPECTED:
Unknown. This is the open question of the project. The "Error" status filter existing suggests denials may be recordable, but whether they actually land there and with what detail is what we are testing.

OBSERVED (in Observability > LLM Logs):

**1. Do denials appear?** YES. Filtering Status = Error returned exactly 8 entries, matching the 8 denials generated across the three matrix passes (three in run 1, two in run 2, three in run 3). Nothing was silently dropped. This is the central question of the project, and the answer is that denied access IS recorded in the OSS observability view.

**2. Does the entry carry the reason, or just the failure?** The reason. Verbatim from the request detail view:

```
Model 'gpt-6-astra' is not allowed for this virtual key
```

Alongside: Status ERROR, HTTP 403, a request ID, timestamp to the second, and the model requested. So the log says a refusal happened AND why.

**3. Cost of a denial.** The refused call never reached OpenAI: latency 0ms, tokens blank, cost blank. Bifrost turned it back at the gateway. A denial costs nothing and produces no tokens. FINDING (a real strength, and the flip side of the Block 5 cost observation): access is enforced before any spend is incurred, so a blocked request is free.

**4. Who was refused? — RESOLVED: captured, but not surfaced in the main view.** The virtual key IS recorded. It is under More details > Request Details > VIRTUAL KEY: reporter, shown as a link to that key's configuration page with its UUID. So the record is complete and producible. The main entry view shows model, status, reason, timestamp, and request ID, but NOT who was refused; you have to expand More details to get it.
   - The finding is "captured but not surfaced in the main view", a placement criticism, NOT "who was refused is not recorded" (that alternative is false and is not recorded as a finding). Operator observation (Shara): the record is complete and producible; the only criticism is placement. "Who" is the first question you ask about a refusal, not the fourth.
   - This resolves the earlier open item. The `routing_info:{}` seen in the API denial body was the response omitting it, not the stored log omitting it; the UI stores the key under More details.

**5. The permission check is visible and timed (FINDING).** On a denied entry, the timing breakdown itemizes the gateway's own overhead and lists the governance check as a separate line: 497 microseconds total overhead, of which 142 microseconds is the Governance plugin, and 0.00 ms upstream. The access decision is observable and measured, not a black box.

**6. The denied record IS exportable, and the export carries more than the screen (CORRECTED FINDING).** Earlier reading: the Raw JSON tab shows "No raw JSON available", which looked like the record could not be exported. Corrected: that message refers specifically to `raw_request` and `raw_response`, which are empty because the call never went upstream. The record itself exports in one click. The downloaded JSON (`evidence/denial-export-0c0c4444.json`) carries more than the screen shows, including:
   - `virtual_key_name: "reporter"` and `virtual_key_id: d7afb265-...` (the refused identity, machine-readable)
   - `error_details.type: "model_blocked"` with the block message
   - a full `overhead_breakdown` array, with `plugin.governance` at 141.562 microseconds
   So the record is complete, producible, AND exportable. No language should imply otherwise. The only screen-level rough edge remains placement: "who" is under More details, not in the main row.

**7. The identity model is wider than what this run exercised (recorded under "did not test").** The export carries `user_id`, `team_id`, `customer_id`, and `business_unit_id` fields, all null in this run because only three roles were set up with nothing above them. Bifrost's identity model extends to users, teams, customers, and business units; this test exercised virtual keys only.

Note on what this can and cannot claim: this is the OSS observability record, not the enterprise Audit Logs. Denials show here with their reason and the refused identity (under More details, and in full in the export), so that is what an OSS operator gets. The one screen-level rough edge is the placement of "who".

**Secret-scan limitation for image evidence:** `git log -p | grep -i "sk-"` only reads text, so it cannot see inside PNG screenshots. Both screenshots (`llm-logs-denials.png`, `llm-logs-denial-detail.png`, `audit-log-enterprise-gated.png`) were checked BY EYE and show a virtual key name and request IDs, not `sk-` values. The JSON export was both grep-scannable and read in full: `virtual_key.value` is an empty string and no API key appears. A reader should know: text files were machine-scanned, image files were checked by eye.

EVIDENCE: LLM Logs filtered Status=Error showing 8 entries (`screenshots/llm-logs-denials.png`); request detail with VIRTUAL KEY: reporter (`screenshots/llm-logs-denial-detail.png`); full machine-readable export (`evidence/denial-export-0c0c4444.json`); `raw_output.log` denial bodies (lines 318, 346, 464) and allowed-call `"key":"Heimdall"` (lines 244, 290).

SHARA: PASS

---

## CHECKPOINT 7: Packaged
Time: 2026-09-05, Block 7

WHAT I DID
Committed the repo (files added by name, `.env` excluded and confirmed gitignored), scanned for secrets, and pushed to the public GitHub repo. `body.json` was committed deliberately (the Windows curl workaround the README references). The JSON export and three screenshots are included as evidence.

Scan coverage, stated so a reader knows which check covered what:
- **Text files: machine-scanned.** `git log -p | grep -i "sk-"` over the committed content. Every `sk-` hit was a placeholder (`sk-your-throwaway-key-here`, `sk-bf-XXXX`), a doc reference to the pattern (`sk-bf-*`), or prose about masking. No real key.
- **The JSON export: machine-scanned and read in full.** `virtual_key.value` is an empty string; no API key present. It does contain a `virtual_key_id` UUID, an identifier (not a credential) for a virtual key inside a local container being destroyed at the end; committed as-is by decision.
- **The three PNG screenshots: checked BY EYE, not by grep.** grep cannot read inside image files. The images show a virtual key name and request IDs, not `sk-` values. This is a real limit of the text scan and is recorded so a reader knows images were verified visually, not mechanically.

CHECKS:
- [x] `.env` gitignored, never committed (`git check-ignore .env` returns `.env`; not in `git status`)
- [x] `git log -p | grep -i "sk-"` returns nothing (text scan; only placeholders/pattern refs, no real key)
- [x] Screenshots checked for visible key material (by eye; grep cannot read PNGs)
- [ ] Repo pushed public
- [ ] Provider key revoked (Shara, after push)

SHARA: PASS / FAIL

---

## Verification spot-checks

Two by hand, per the PRD.

**Spot-check 1**
Time:
Line checked from this report:
Matching entry found in `raw_output.log`: YES / NO
Notes:

**Spot-check 2**
Time:
Line checked from this report:
Matching entry found in `raw_output.log`: YES / NO
Notes:

---

## Not tested (STUB)

Recorded so the article can say plainly what this run did not cover.

- **Budget / spend-cap enforcement** — attempted in Block 5 but not completed. A $0.05 cap was never approached because 200 one-word calls cost ~$0.0016. Cut from scope; the cause was test design, not the product. Would need a test that generates real spend (larger prompts or a much higher call count) to actually exercise enforcement.
- **The wider identity model.** The denial export carries `user_id`, `team_id`, `customer_id`, and `business_unit_id`, all null here because only three virtual keys were set up with nothing above them. Bifrost's identity model extends to users, teams, customers, and business units; this run exercised virtual keys only.
- Key revocation mid-run
- Teams and customers layer
- SSO / OIDC identity providers
- Rate limits (`token_max_limit`, `request_max_limit`)
- Multi-provider failover
- Any second provider
