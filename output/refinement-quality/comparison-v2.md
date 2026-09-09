# Final local refinement evaluation

The final implementation improved preservation of requests, the speaker's role, negation, and casual tone in the tested examples. It also handles short inputs that the original service skipped and removes some fillers. It still sometimes leaves clear self-corrections or fragmented clauses untouched. This evidence supports a useful local improvement, not a claim of Typeless-level completion quality.

All runs used the available Apple FoundationModels engine on macOS 26.5, with synthetic Japanese text and no external AI. These standalone service calls measure model capability independently of app preferences. This evaluation changed no app or system settings.

## Evaluation design

| Suite | Size | Relationship to prompt development |
| --- | --- | --- |
| Original cases | 7 | Baseline failures informed the first prompt, including some literal examples. Development evidence only. |
| Held-out cases | 5 | Authored independently without reading the first replacement prompt or sharing their text with its author. High-level v1 echo/cleanup findings informed one generic prompt iteration, so the v2 run is regression evidence. |
| Final cases | 3 | Authored independently before inspecting v2. Texts were not shared with the tuning agent; no further prompt tuning followed this run. |

Each input was run once per tested implementation. Quality was assessed against meaning, request/commitment, actor, number, and editing criteria rather than exact target strings. These small samples and uncontrolled warm/cold model state do not establish a general accuracy score or an end-to-end speed benchmark. No Typeless execution was performed.

## Observed behavior

| Behavior | Original service | Final implementation |
| --- | --- | --- |
| Short `えっと了解` | Skipped unchanged | `了解` |
| Request to change meeting time | Changed request into a promise | Corrected time and request preserved |
| Request to share a technical update | Dropped sharing request | Preserved request, though colloquial wording remained |
| Speaker's denial of deleting | Dropped denial | Preserved denial and uncertainty about another person's action |
| Casual message | Forced formal wording and omitted a time reference | Preserved casual voice and details, but retained opening hesitation |
| Distinct request and speaker commitment | Cleaned filler while preserving both | Also cleaned filler while preserving both |
| Reservation date/time correction | Kept both superseded and corrected date/time | Returned original unchanged; correction remains unresolved |
| Disordered clauses | Sometimes invented a promise or produced awkward phrasing | Avoided added promises, but often retained fragmented wording |

The final unseen set provides a more limited check of actual cleanup:

| Final input type | Original output | Final implementation output |
| --- | --- | --- |
| Quantity self-correction | `納品数は28個をお願いします。` | `納品数は28個でお願いします。` |
| Fillers around a polite request | `昨日のデモのリンクをもう一度送っていただけますか。` | Same natural request; both fillers removed |
| Inventory check before ordering, in fragments | `在庫を確認してください。発注前に、対象は青いケーブルです。` | Original fragmented text unchanged |

Both implementations resolved the unseen quantity correction and polite request. The final implementation's quantity wording was more natural, but it did not assemble the fragmented inventory request into a single natural sentence. No actor, factual, or request-to-promise regression was observed in the three final cases. A three-case sample cannot establish absence of such regressions generally.

## Latency and outcomes

All 15 final calls completed with text and no fallback, taking 0.427–0.896 seconds, median 0.514 seconds. Seven outputs were marked `refined` and eight `unchanged`; those statuses report whether the model altered the string, not whether it edited correctly. In particular, unchanged date/time correction and fragmented-clause cases still need improvement.

The baseline had one immediate short-input bypass and one nil result after 31.893 seconds. The original nullable API does not expose the reason for that nil result. Its replacement completed that same synthetic input normally during these runs, but one timing observation does not prove the original failure cause or that slow cases are eliminated.

The Messages fixture supplied app context only to the new service, because the original API has no such parameter. This compares whole implementations, including optional context, rather than isolated prompt text. No surrounding app content was read.

## Artifacts and reproduction

- Original baseline: `baseline.json`, `baseline-heldout.json`, `baseline-final.json`.
- First implementation: `improved-v1.json`, `improved-heldout-v1.json`, and `comparison-v1.md`; all preserved unchanged.
- Final implementation: `improved-v2.json`, `improved-heldout-v2.json`, `improved-final-v2.json`.
- Source snapshots: `tmp/refinement-baseline/`, `tmp/refinement-improved-v1/`, `tmp/refinement-improved-v2/`; hashes in `source-snapshots.sha256`.
- Reusable runner and fixtures: `scripts/refinement-evaluation.sh`, `scripts/refinement-evaluation.swift`.

```sh
# Original seven; select a NEW label to avoid replacing the preserved output.
scripts/refinement-evaluation.sh rerun-v2 tmp/refinement-improved-v2/RefinementService.swift tmp/refinement-improved-v2/RefinementPrompt.swift tmp/refinement-improved-v2/RefinementDeadline.swift --application-context --detailed-result

# Five held-out cases, or use suite=final for the three final cases.
HSVOICE_REFINEMENT_EVALUATION_SUITE=heldout scripts/refinement-evaluation.sh rerun-heldout-v2 tmp/refinement-improved-v2/RefinementService.swift tmp/refinement-improved-v2/RefinementPrompt.swift tmp/refinement-improved-v2/RefinementDeadline.swift --application-context --detailed-result
```

The runner checks availability before generating and does not change settings if the model is unavailable. `--availability-only` records availability without generating any text.
