# Local refinement comparison, first implementation

Twelve synthetic Japanese cleanup samples were evaluated on the available Apple FoundationModels engine. The original seven revealed problems and informed the replacement prompt, so they are development examples rather than independent quality evidence. Five additional cases were authored independently before reading the replacement prompt and were not supplied verbatim to its implementation agent. All outputs are single samples from a probabilistic model; this is a small behavior check, not a Typeless comparison or general quality score.

Both service snapshots were compiled independently from the app. Original sources are preserved under `tmp/refinement-baseline/`; first-improvement sources under `tmp/refinement-improved-v1/`. File hashes are recorded in `source-snapshots.sha256`.

## Original seven: fidelity improved, some cleanup remains absent

| Case | Baseline problem | Improved v1 result |
| --- | --- | --- |
| Short filler | Short input skipped unchanged | `了解`; filler removed. |
| Corrected time | Request changed into a promise | Corrected time and request both preserved. |
| Negation | Active denial changed into passive status | Original statement and prohibition preserved unchanged. |
| Uncertainty | Estimate remained uncertain | Original estimate preserved unchanged. |
| Names/numbers | Important facts preserved | Filler removed; important facts preserved. |
| Mixed English | Sharing request disappeared | Sharing request now preserved. |
| Disordered clauses | Unsupported sending promise added | Original text returned unchanged; promise is no longer invented, but clause order and filler are not improved. |

The new API reported four `refined` and three `unchanged` results. Every result contained text; no fallback occurred. Calls took 0.511–0.912 seconds in this run.

## Held-out five: safer preservation, little actual cleanup

All five returned the complete input unchanged (`unchanged` status), with no fallback, in 0.595–1.056 seconds. Inspection of the saved service confirms these are direct model outputs, not a validation layer substituting original input.

| Case | Baseline | Improved v1 |
| --- | --- | --- |
| Request and commitment | Removed filler while preserving request and speaker commitment | Preserves meaning, but opening filler is now left intact. |
| Actor negation | Dropped the speaker's explicit denial | Preserves both denial and uncertainty about the other person. |
| Date/time correction | Kept original and corrected booking date/time | Also keeps both date/times, including correction words; the desired cleanup remains unresolved. |
| Uncertain decision | Returned fallback after 31.893 seconds | Returns unchanged text normally in 0.647 seconds. A single run does not prove the previous fallback cause or timing is consistently fixed. |
| Casual Messages tone | Forced polite wording and omitted “earlier” | Preserves casual voice and all details, but leaves the opening hesitation. |

These held-out results demonstrate better retention of information and tone, but do not establish strong general cleanup ability. The first implementation is more conservative and can leave removable fillers or clear self-corrections untouched.

The Messages fixture supplied app context only to the new service, because the original service has no app-context parameter. This is a comparison of whole implementations, including the new context feature, rather than isolated prompt wording.

## Scope and reproducibility

- These standalone harness runs measure model capability independently of app preferences; no settings were changed.
- The harness sends no external requests and uses only synthetic text. It does not record audio, use user transcripts, or measure recognition, insertion, network, or end-to-end dictation latency.
- Input expectations are qualitative meaning-preservation criteria, not exact target strings or automatic correctness scores.
- Results and individual timings: `baseline.json`, `baseline-heldout.json`, `improved-v1.json`, and `improved-heldout-v1.json`.

```sh
scripts/refinement-evaluation.sh improved-v1 tmp/refinement-improved-v1/RefinementService.swift tmp/refinement-improved-v1/RefinementPrompt.swift tmp/refinement-improved-v1/RefinementDeadline.swift --application-context --detailed-result
HSVOICE_REFINEMENT_EVALUATION_SUITE=heldout scripts/refinement-evaluation.sh improved-heldout-v1 tmp/refinement-improved-v1/RefinementService.swift tmp/refinement-improved-v1/RefinementPrompt.swift tmp/refinement-improved-v1/RefinementDeadline.swift --application-context --detailed-result
```

Use a new output label for another run to preserve the existing reports.
