# Heimdall: PRD

**One-line:** A reproducible test harness that hands out three scoped badges at a Bifrost AI gateway, tries every badge on every door, and reports in plain English what got through.

**Why the name:** Bifrost is the Norse rainbow bridge. Heimdall is the watchman who decides who crosses it. This repo is deliberately outside the Clew Suite and Lex naming families. It is a test harness for someone else's software, not a Clew Labs tool.

**Owner:** Earl Grey (dev.to/earlgreyhot1701d)
**Purpose:** Evidence for a sponsored dev.to article on RBAC and access scoping at an AI gateway. Sponsored by the Bifrost team at Maxim AI. Disclosure runs at the top of the published post.
**Total build budget:** 3 hours. Hard stop.
**Draft due:** Monday 9/7, 10pm PST.

---

## The one thing this proves

That a person who administers role-based access for a living can stand up an AI gateway, define three roles with different permissions and budgets, and find out what happens when someone reaches for something they were not given.

Not a benchmark. Not a comparison. One operator, one setup, one honest report.

---

## Model Authority Check

Run per this project's standing rule, on every place a model appears.

| Call | Role | Verified by | Notes |
|---|---|---|---|
| The LLM calls made during the matrix | **Subject** | N/A | The model is the traffic, not the decision maker. Prompts are trivial ("say hello"). No model output drives any conclusion in the article. |

No model is used as investigator, presenter, advisor, or creator anywhere in the harness. Every claim in the report traces to an HTTP status code and a response body in `raw_output.log`.

If an agent helping build this proposes adding a model call that interprets results, reject it. The comparison is deterministic: expected value versus observed value.

---

## Scope

### MUST (this build, non-negotiable)

1. Bifrost running locally in Docker, reachable at `localhost:8080`.
2. One provider configured: OpenAI, one throwaway API key with a hard spend cap set on the provider side.
3. Three virtual keys created, named for court roles:

   Access follows function, not seniority. Roles run narrowest to widest.

   | Badge | Allowed models | Budget | Reset |
   |---|---|---|---|
   | `interpreter` | routine tier only | $0.05 | 1d |
   | `reporter` | routine + standard | $1.00 | 1d |
   | `clerk` | all three | $5.00 | 1d |

   The interpreter budget is deliberately tiny so it can be exhausted on purpose in Block 5. The clerk holds the widest access because the clerk audits the case live; if the clerk cannot see something, court stops.
4. A 3x3 permission matrix. Every badge tries every model. Nine calls.
5. Expected results declared in the script **before** the run, compared to observed, mismatches flagged loudly.
6. A budget exhaustion test against the `interpreter` badge (the narrowest role, carrying the $0.05 budget).
7. Audit log inspection, answering one specific question: **are denied attempts recorded, or only successful ones?**
8. `RUN_REPORT.md` written in plain English, appended after every block, readable by someone who does not read code.
9. `raw_output.log` preserving every raw request and response, untouched.
10. Public GitHub repo that a stranger can clone and rerun with their own key.

### STUB (comment the hook, do not build)

- Key revocation mid-run. Do it only if Block 5 finishes early.
- Teams and customers layer (department-level budgets above individual badges).
- SSO / OIDC identity provider integration.
- Rate limit testing (`token_max_limit`, `request_max_limit`).
- Multi-provider failover.
- Any second provider.

Each of these gets a one-line stub comment in the config or script naming what it would do and why it is out of scope for this pass.

### NEVER

- Never use an API key that belongs to a live project. Fresh key, capped, revoked at the end.
- Never commit a key, a `.env`, or a `sk-bf-*` value. `.env.example` only.
- Never deploy this to AWS or any cloud. Local Docker is the environment. The article's value depends on a reader being able to rerun it in ten minutes.
- Never write a result into `RUN_REPORT.md` that is not backed by a line in `raw_output.log`.
- Never let an agent "fix" a mismatch quietly. A mismatch is a finding and gets written down before anyone touches the config.
- Never paraphrase an error message. Verbatim or not at all.

---

## Three phases

The blocks below run inside phases. The phases exist so that nothing that can be built without a key is built with one, and nothing live starts until the harness is proven.

| Phase | Keys | Docker | Cost | Who watches |
|---|---|---|---|---|
| **A. Build dry** | none | no | $0 | Nobody needs to. Safe to run ahead. |
| **B. Smoke** | provider key | no | cents | Shara, 5 min |
| **C. Live run** | provider key + badges | yes | under $2 | Shara, the full 3 hours |

### Phase A: build dry

Kiro builds every script, the config, the report scaffolding, and `.gitignore`. No keys exist. Docker is not started. Nothing reaches the network.

Every script supports `DRY_RUN=1`, which prints the exact request it would send, masks any badge value, and executes nothing.

**Dry-run self-checks.** The dry run asserts all of the following and prints a plain-English PASS or FAIL for each:

| Check | Passes when |
|---|---|
| Matrix count | Exactly 9 badge-model combinations are generated |
| Expected table | Sums to 6 ALLOW and 3 DENY |
| Env coverage | Every variable the scripts reference exists in `.env.example` |
| No hardcoded models | No model name appears outside `.env` |
| No badge leakage | No `sk-` value appears in any printed output |
| Target URL | Every request targets `localhost:8080`, never a provider domain |
| Gitignore | `.gitignore` contains `.env` |
| Log writable | `raw_output.log` can be appended to |

**Phase A gate:** all eight checks PASS. Nothing proceeds until they do. This phase can run unattended and costs nothing, so it should be finished before the live session starts.

### Phase B: smoke

Provider key added to `.env`. Bifrost still not running.

Run Block 0's pre-flight only: three direct calls to the provider, one per model.

**Phase B gate:** three completions returned. The key works and all three models are reachable.

This is the last thing that can go wrong before Docker is involved, and it costs a few cents to find out.

### Phase C: live run

Blocks 1 through 7. Shara present throughout. This is the phase the 3 hour budget applies to.

---

## Build blocks

Each block ends with a QA checkpoint. Shara reads the plain-English report and says PASS or FAIL out loud before the next block starts.

### Block 0. Prep and pre-flight (not counted against the 3 hours)

**Keys.** One provider key, not three. The price tiers are model tiers, not key tiers. One OpenAI key reaches all three models. The three badges are virtual keys created inside Bifrost in Block 3, and they are not OpenAI credentials.

- Create a fresh OpenAI API key. Set a hard spend cap on the OpenAI side, $5 or lower.
- Confirm Docker is running.
- Create `NOTES.md` and open it. It stays open the whole time.
- Run `git init` now, before the key exists. Confirm `.env` is ignored with `git check-ignore .env` (it must print `.env`) before pasting any key. The ordering is the point: initialize the repo around an empty folder and prove the ignore *before* a live key is on disk, rather than initializing around a folder that already holds one. Block 7 keeps the push, the secret scan, and the packaging.

**Choosing the three models.** Some models are gated by OpenAI usage tier, which depends on historical spend. Reasoning models in particular sit at higher tiers and are not available to every account.

Check both:

1. The Limits page in the OpenAI dashboard, which shows the account's tier and model access.
2. The models endpoint, which shows what this key can actually reach:

```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | grep '"id"'
```

Pick three from that list at distinct price points. Tier labels name the access level, not the cost: routine, standard, restricted. The "restricted" tier only needs to cost more than the other two. It does not need to be the most capable model available. Do not chase a gated model.

**Pre-flight: prove all three models work before Bifrost enters the picture.**

Call each of the three models directly against `api.openai.com`, bypassing Bifrost entirely. All three must return a completion.

This matters for two reasons:

1. If a model is unreachable for the key, a later failure through the gateway would be an OpenAI rejection wearing the costume of an access denial. The matrix would be unreadable.
2. Three models proven reachable directly, then denied through the gateway, is the cleanest possible proof that the gateway did the denying. This feeds Block 4b.

Record each pre-flight response status in `raw_output.log` under a `PREFLIGHT` heading.

**Checkpoint 0:**
- Key exists, provider-side cap set
- Docker up
- Three model names chosen and written into `.env`
- All three return a successful completion on a direct call
- The three names recorded in `RUN_REPORT.md`

If a chosen model fails the pre-flight, swap it for another from the models list. That is a config fix, not a finding, but note the swap in the log.

---

### Block 1. The door opens (30 min)

- `docker run -p 8080:8080 maximhq/bifrost`
- Open `http://localhost:8080`. Confirm the web UI loads.
- Add the OpenAI key through the UI.
- Shara personally runs one curl, no badge:

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"openai/gpt-4o-mini","messages":[{"role":"user","content":"hello"}]}'
```

**Checkpoint 1:** A response came back.

**HARD GATE:** If there is no successful response at 45 minutes, stop. Write down exactly where it stuck. That becomes the opening of the article and the scope changes to a setup-friction piece. Do not push through silently.

---

### Block 2. Find the two things the article depends on (20 min)

The published docs cover virtual keys, budgets, and rate limits clearly. They did not cover RBAC roles or audit log location. The sponsor confirmed both are in the OSS build. Verify that before building anything on top of it.

- Locate RBAC / custom roles in the UI or API. Screenshot it.
- Locate the audit log. Screenshot it.

**Checkpoint 2 (GO / NO-GO):**

- Both present: continue as planned.
- Either missing or enterprise-gated: **stop and message Swapnoneel before continuing.** Record exactly what is and is not available. Do not spend Sunday building around a gap. This gate exists so a blocker surfaces Saturday, not Sunday night.

---

### Block 3. Three badges (30 min)

- Create `interpreter`, `reporter`, `clerk` as virtual keys, via UI or `config.json` (record which method was used and why).
- Attach `allowed_models` per the table above.
- Attach budgets per the table above.
- Save the three `sk-bf-*` values into `.env` (never committed).

**Checkpoint 3:** Three badges exist. `RUN_REPORT.md` lists them with their configured limits, in plain English.

---

### Block 4. The matrix (30 min)

Nine calls. Each badge against each model.

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "x-bf-vk: $BADGE" \
  -H "Content-Type: application/json" \
  -d '{"model":"'"$MODEL"'","messages":[{"role":"user","content":"hello"}]}'
```

The script declares expected results first:

| Badge | routine | standard | restricted |
|---|---|---|---|
| interpreter | ALLOW | DENY | DENY |
| reporter | ALLOW | ALLOW | DENY |
| clerk | ALLOW | ALLOW | ALLOW |

Expected total: 6 allowed, 3 denied.

Report format per call: badge, model, expected, observed, HTTP status, verbatim error text if denied.

**Checkpoint 4:** Report shows expected vs actual with any mismatch flagged. Shara reads it and records her reaction in `NOTES.md` before anything is changed.

---

### Block 4b. Provenance: prove the traffic went through Bifrost (15 min)

Without this, every result in the article rests on the reader taking our word that these calls did not go straight to OpenAI. Record the proof rather than assuming it.

Five pieces of evidence, cheapest first.

1. **The address.** Every entry in `raw_output.log` records the full request URL. `http://localhost:8080/v1/chat/completions`, never a provider domain.
2. **The credential.** The client only ever holds an `sk-bf-*` value. That is not a valid OpenAI credential. If a call succeeds carrying only that, something upstream substituted the real key. Confirm no `OPENAI_API_KEY` is present in any outbound request from the scripts.
3. **Response headers.** Capture all of them with `curl -D -` or `-i`. Record any gateway-stamped headers verbatim, including request IDs, provider attribution, and latency headers.
4. **The denial vocabulary.** A provider never says "virtual key." Denial text that references virtual keys or budgets could only have come from the gateway. Quote it.
5. **The negative control.** Stop the container. Run the exact same successful call from Block 4 again. It must fail with connection refused. Restart the container and confirm the call succeeds again.

Also record for the article's reproducibility:

- `docker ps` output showing the running container
- The image digest (`docker images --digests maximhq/bifrost`)
- Bifrost version, from the UI or `/health` if one is exposed
- Wall-clock date and time of the run

**Checkpoint 4b:** `RUN_REPORT.md` states, in one plain sentence a skeptical reader would accept, how we know these calls passed through Bifrost. The negative control result is recorded with its verbatim error.

If the negative control does **not** fail, stop. That means something else answered, and every prior result is suspect until it is explained.

---

### Block 5. Running out of money (30 min)

- Loop calls on the `interpreter` badge against its allowed model until the $0.05 budget is exhausted.
- Capture: how many calls it took, the exact response at the moment it trips, the HTTP status, and whether the failure is clean or ambiguous.

**Checkpoint 5:** Report states in plain English what happens when a badge runs out of money.

**If time remains:** revoke the `reporter` badge and confirm calls stop. Note how quickly.

---

### Block 6. The logbook question (20 min)

The article's distinctive question. Answer it precisely.

- Open the audit log.
- Confirm the six successful calls appear.
- **Check whether the three denied calls appear.**
- Check whether the budget-exhausted calls appear.
- Note what fields are recorded: who, what, when, cost, outcome.

**Checkpoint 6:** `RUN_REPORT.md` states plainly whether attempted-and-denied access is recorded, with a screenshot.

Either answer is publishable. If denials are logged, that is a genuine strength worth naming. If they are not, that is a limitation an operator in a regulated setting would need to know about.

---

### Block 7. Package (40 min)

The repo was already initialized in Block 0, with `.env` proven ignored before the key existed. Block 7 is push, secret scan, and packaging only.

- `README.md` explaining what this is and how to rerun it.
- `.env.example` with placeholder names, no values.
- Config and script committed.
- `RUN_REPORT.md` and `raw_output.log` committed.
- Screenshots in `/screenshots`.
- Push to a public repo named `heimdall`.
- Revoke the OpenAI key.

**Checkpoint 7:** A stranger could clone this and rerun it.

---

## Time budget

| Block | Budget | Cut first if behind |
|---|---:|---|
| 1. Door opens | 30 min | |
| 2. Find RBAC + audit log | 20 min | |
| 3. Three badges | 30 min | |
| 4. Matrix | 30 min | |
| 4b. Provenance | 15 min | Never cut. Without it nothing else is checkable. |
| 5. Budget exhaustion | 30 min | Revocation test |
| 6. Logbook | 20 min | |
| 7. Package | 40 min | Screenshots trimmed to 3 |
| **Total** | **3h 35m** | Target 3h |

Expected spend: under $2.00 across all calls.

---

## Verification rule

Twice during the run, Shara picks a line from `RUN_REPORT.md` and finds the matching entry in `raw_output.log` herself. Not to read code, only to confirm the summary matches what came back.

If a summary claims something the raw log does not show, that is a stop-everything moment. Nothing gets published from a report that cannot be traced to source.

---

## Definition of done

- [ ] Nine matrix results recorded, expected vs observed
- [ ] Provenance recorded: URL, headers, negative control, image digest
- [ ] Budget exhaustion behavior recorded verbatim
- [ ] Audit log denial question answered yes or no, with evidence
- [ ] `RUN_REPORT.md` readable by a non-coder end to end
- [ ] `raw_output.log` complete, two entries spot-checked by hand
- [ ] `NOTES.md` has at least five entries written during the run
- [ ] Public repo pushed, no secrets
- [ ] OpenAI key revoked
- [ ] Under 3 hours of build time

The article is written after all of the above, from `NOTES.md` and `RUN_REPORT.md`. Not before, and not from the docs.
