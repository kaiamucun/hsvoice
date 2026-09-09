# Local refinement baseline

Run: 2026-09-09, macOS 26.5, Apple FoundationModels available. The harness compiled the original `RefinementService.swift` snapshot separately from the app. Seven synthetic Japanese cleanup samples were run once, with no external AI and no user transcripts. No application context or custom instructions were supplied.

The six model calls took 0.411–0.959 seconds. The first, five-character input returned immediately without model processing because the original service skips inputs shorter than eight characters. These timings are one local run, with no warm/cold state control, and do not establish end-to-end dictation latency or a comparison against Typeless.

| Case | Observed result | Assessment |
| --- | --- | --- |
| Short filler | `えっと了解` inserted unchanged | Filler not removed because of short-input bypass. |
| Corrected time | `明日の会議は4時に変更します。` | Corrected time preserved, but the user's request became a promise. |
| Negation | `契約はまだ承認されていませんので、送付しないでください。` | Negation and prohibition preserved. Active “I have not approved” became passive “has not been approved,” and a causal link was added. |
| Uncertainty | `金曜までに終わる見込みですが、確定はまだできません。` | Friday estimate remains uncertain. |
| Names and numbers | `佐藤さんにHS Voiceの見積もり12万5000円を、9月18日までに送ってください。` | Names, amount, deadline, and send request preserved. |
| Mixed English | `Slackのreleaseチャンネルに、APIのtimeoutを30秒に変更しました。` | Technical terms and number retained, but the request to share the update was dropped. |
| Disordered clauses | `資料を田中さんに送ってください。今日中に送りますので、送る前に数字だけ確認してください。` | Recipient and action order retained, but an unsupported promise to send today was added. |

The sample intentionally checks preservation of requests, negation, uncertainty, names, and numbers. These are manual observations, not a broad quality score. See `baseline.json` for inputs, outputs, fallback flags, expected qualities, and precise per-case timings.

Re-run the preserved implementation:

```sh
scripts/refinement-evaluation.sh baseline tmp/refinement-baseline/RefinementService.swift
```

Run a changed implementation, appending any standalone helper sources it imports:

```sh
scripts/refinement-evaluation.sh improved Sources/HSVoice/RefinementService.swift path/to/helper.swift
```

Append `--availability-only` to check the local model without generating results. The harness stops at availability reporting when the model is unavailable and never changes system settings.
