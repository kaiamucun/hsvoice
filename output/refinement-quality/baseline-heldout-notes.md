# Held-out local refinement baseline

Five additional synthetic cases were independently authored without reading the replacement prompt and were not supplied verbatim to its implementation agent. They were evaluated once on the preserved original service with Apple FoundationModels available. The original seven-case baseline files were preserved.

| Held-out case | Observed result | Assessment |
| --- | --- | --- |
| Request and commitment | Request to change the invoice addressee and the speaker's payment commitment both survived. | Preserved distinct actors and speech acts. |
| Actor negation | Output retained uncertainty about Mori's action but removed the speaker's explicit statement that they had not deleted anything. | Important information lost. |
| Date and time correction | Output included both October 6 at 10 AM and October 8 at 2 PM. | Superseded reservation date/time incorrectly retained. |
| Uncertain decision | Service returned nil after 31.893 seconds, so the original text would be inserted. | Fallback preserved information; refinement did not complete. The old API does not expose a failure reason. |
| Casual Messages tone | Casual thanks and invitation became `写真ありがとうございます。とても良かったです。また週末に遊びましょう。` | Meaning broadly preserved; casual voice was made formal and the reference to the earlier photo was dropped. |

The four completed generations took 0.405–1.024 seconds. These are single-run observations, and model/session state was not controlled. The uncertain-decision fallback's timing is consistent with the old service's deadline path, but the nullable API does not identify its actual failure reason.

The casual-tone fixture records `Messages` as its intended app context. The original service has no application-context parameter, so the baseline did not consume that hint (`applicationContextEnabled: false`). A later comparison with context enabled therefore evaluates the whole feature change, including adding the app hint, rather than prompt wording alone.

```sh
HSVOICE_REFINEMENT_EVALUATION_SUITE=heldout scripts/refinement-evaluation.sh baseline-heldout tmp/refinement-baseline/RefinementService.swift
```

Full raw inputs, outputs, expectations, and timings are in `baseline-heldout.json`. The case definitions are in `scripts/refinement-evaluation.swift`.
