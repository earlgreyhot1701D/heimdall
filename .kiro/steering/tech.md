# Tech steering: Heimdall

## Stack

Deliberately minimal. Occam's razor applies hard here because the harness is not the point.

| Layer | Choice | Why |
|---|---|---|
| Gateway | Bifrost, official Docker image `maximhq/bifrost`, port 8080 | The subject of the test. Docker so a reader can reproduce it in one command. |
| Provider | OpenAI, one throwaway key, hard spend cap set provider-side | One provider keeps the variable count at one. Multi-provider is STUB. |
| Test runner | Plain bash + curl | Nine HTTP calls. A framework would be more code than the thing it tests. |
| Config | `config.json` or the web UI, whichever we actually used | Record which one and why. That choice is itself an article detail. |
| Output | Two files: `RUN_REPORT.md` (English) and `raw_output.log` (verbatim) | Separation is the trust mechanism. |

No Python. No test framework. No build step. No cloud. If a dependency is proposed, the answer is no unless it solves a problem bash cannot.

## Bifrost mechanics (verified from docs, confirm during Block 1)

Start:
```bash
docker run -p 8080:8080 maximhq/bifrost
```

Web UI at `http://localhost:8080`. Provider keys added through the UI.

Request shape, OpenAI-compatible:
```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "x-bf-vk: sk-bf-XXXX" \
  -H "Content-Type: application/json" \
  -d '{"model":"openai/gpt-4o-mini","messages":[{"role":"user","content":"hello"}]}'
```

Virtual keys:
- Created via Web UI (Virtual Keys, Add Virtual Key), REST API `POST /api/governance/virtual-keys`, or static `config.json`
- Format `sk-bf-*`
- Model allowlist via `provider_configs` with `allowed_models`
- Budget via `max_limit` (dollars) and `reset_duration` (`1m`, `1h`, `1d`, `1w`, `1M`, `1Q`, `1Y`)
- Rate limits via `token_max_limit` and `request_max_limit`, virtual-key level only

Virtual key header, any of these accepted:
`x-bf-vk`, `Authorization: Bearer`, `x-api-key`, `x-goog-api-key`, `api-key`

Use `x-bf-vk` throughout for clarity in the article.

**Unverified, confirm in Block 2:** RBAC custom roles and audit log location were not covered in the docs pages read before the build. The sponsor states both are in the OSS build. Block 2 is a GO/NO-GO gate on exactly this.

## Security rules

Non-negotiable, from the standing build principles.

- API keys only in `.env`, never in code, never in a comment, never in a commit.
- `.env` in `.gitignore` before the first commit, not after.
- `.env.example` ships with placeholder names and no values.
- The OpenAI key used here is created for this test and revoked at the end. It is never a key that touches a live project.
- Hard spend cap set on the OpenAI side, not only in Bifrost. Two locks.
- Screenshots get checked for visible key material before they are committed.
- Before pushing: `git log -p | grep -i "sk-"` and confirm nothing.

## Proving the traffic went through the gateway

A reader is entitled to ask how they know these calls did not go straight to the provider. Every run records the answer.

Logging requirements, enforced in every script:

- Log the **full request URL** on every call, not a shortened form
- Capture **all response headers** (`curl -D -` or `-i`), not just the body
- Log the **role name** (`clerk`) and never the virtual-key value
- Confirm no provider credential appears in any outbound request the scripts make. The client holds `sk-bf-*` only.
- Record the **negative control**: container stopped, same call, connection refused, verbatim

Environment facts recorded once per run at the top of `raw_output.log`:

```bash
docker ps
docker images --digests maximhq/bifrost
date -u
```

The strongest single proof is the credential asymmetry. An `sk-bf-*` value cannot authenticate to OpenAI. If a request carrying only that value returns a completion, something upstream substituted a real key. Say that plainly in the report rather than gesturing at it.

## Model selection

The three models under test are set in `.env` and nowhere else. They are the models the roles reach for through the gateway. They are unrelated to whatever model the coding agent uses to write this harness.

To list what the provider key can reach:

```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | grep '"id"'
```

Pick three at distinct price tiers so that "expensive" carries meaning in the matrix. Prefix with the provider for Bifrost: `openai/gpt-4o-mini`.

Record the three chosen names in `RUN_REPORT.md` at Checkpoint 0. If a chosen model turns out to be unavailable to the key, that is a config fix, not a finding, and it gets noted with a line in the log.

**Model access is gated by OpenAI usage tier.** Tier depends on historical spend, and some reasoning models are restricted to higher tiers. The account's Limits page in the OpenAI dashboard shows tier and model access. Do not select a gated model. The "expensive" tier only needs to cost more than the other two.

**Key count: one.** Price tiers are model tiers, not key tiers. A single provider key reaches all three models. The three roles are virtual keys minted by Bifrost in Block 3 and are not provider credentials. If a plan ever calls for three provider keys, that plan is wrong.

**Pre-flight is mandatory.** Before Bifrost is introduced, each of the three models is called directly against `api.openai.com` and must return a completion. Log these under a `PREFLIGHT` heading in `raw_output.log`.

Without the pre-flight, a provider-side rejection during the matrix would be indistinguishable from a gateway denial, and the central result of the project would be unreadable. With it, every denial observed later can only have originated at the gateway. The pre-flight is therefore both a correctness control and a provenance artifact, and it is cited in Block 4b.

## Dry run mode

Every script honors `DRY_RUN=1`. In that mode it:

- prints the full request it would send, including URL, headers, and body
- masks any value beginning `sk-`, showing the role **name** instead
- executes no network call
- exits 0

This exists so the entire harness can be built and validated before a key exists. Building dry is Phase A and it costs nothing.

The dry run also asserts the eight self-checks in the PRD and prints a plain-English PASS or FAIL for each. Those assertions are the harness testing itself, and they catch the class of error that is cheap now and expensive during a live run: a matrix that generates eight calls instead of nine, an expected table that does not sum, a hardcoded model name, a virtual-key value printed into a log.

The URL assertion is a safety control as much as a correctness one. Any request targeting a provider domain rather than `localhost:8080` is a failed dry run, because that would mean the harness bypassed the thing it exists to test.

## Error handling

Every curl captures HTTP status and full response body. Nothing is swallowed. A failed call is data, so failures are recorded with the same care as successes.

No retries. A retry hides a transient failure, and a transient failure is a finding.

## Determinism

Same role, same model, same prompt, same expected outcome, every run. Prompts are fixed strings, not generated. No randomness anywhere in the harness.

The LLM responses will vary. That is fine and irrelevant. We measure whether the call was allowed or denied, never what the model said.

## Cost control

- Cheap model for all matrix calls except where the test requires reaching for an expensive one, and those are expected to be denied anyway.
- Prompt is `"hello"`. Minimum tokens.
- Total expected spend under $2.00.
- Provider-side cap is the backstop.
