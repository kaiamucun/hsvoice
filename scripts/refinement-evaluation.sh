#!/bin/bash
set -euo pipefail

# Usage: scripts/refinement-evaluation.sh LABEL [SERVICE.swift] [HELPER.swift ...]
# Append --availability-only to compile and inspect availability without prompts.
# Set HSVOICE_REFINEMENT_EVALUATION_SUITE=heldout to run the five held-out samples
# separately, =final for three final validation cases, or =all for all fifteen.
# The default remains the original seven.
# Append --application-context for a service with an applicationName argument.
# Append --detailed-result for a service with refineWithResult to record its status.
# Example baseline:
#   scripts/refinement-evaluation.sh baseline tmp/refinement-baseline/RefinementService.swift
# Example current app (automatically includes helpers and detailed status):
#   scripts/refinement-evaluation.sh improved
# Example explicit new-service snapshot:
#   scripts/refinement-evaluation.sh improved-snapshot tmp/refinement-improved-v2/RefinementService.swift tmp/refinement-improved-v2/RefinementPrompt.swift tmp/refinement-improved-v2/RefinementDeadline.swift --application-context --detailed-result
# This runs seven synthetic cleanup samples once. Results and timings are not a
# comprehensive quality or speed benchmark, and nil preserves raw dictation.

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root_dir"
label="${1:-current}"
if [[ $# -gt 0 ]]; then shift; fi
case "$label" in
  *[!a-zA-Z0-9_-]*|'') printf '%s\n' 'LABEL may contain only letters, digits, underscores, and hyphens.' >&2; exit 2 ;;
esac

availability_args=()
compiler_args=(-parse-as-library -swift-version 5 -O)
source_files=()
for argument in "$@"; do
  if [[ "$argument" == '--availability-only' ]]; then
    availability_args+=("$argument")
  elif [[ "$argument" == '--application-context' ]]; then
    compiler_args+=(-D REFINEMENT_APPLICATION_CONTEXT)
  elif [[ "$argument" == '--detailed-result' ]]; then
    compiler_args+=(-D REFINEMENT_DETAILED_RESULT)
  else
    source_files+=("$argument")
  fi
done
if [[ ${#source_files[@]} -eq 0 ]]; then
  source_files+=("Sources/HSVoice/RefinementService.swift" "Sources/HSVoice/RefinementPrompt.swift" "Sources/HSVoice/RefinementDeadline.swift")
  compiler_args+=(-D REFINEMENT_APPLICATION_CONTEXT -D REFINEMENT_DETAILED_RESULT)
fi

build_dir="$root_dir/tmp/refinement-evaluation/$label"
mkdir -p "$build_dir" "$root_dir/output/refinement-quality"
xcrun swiftc "${compiler_args[@]}" \
  "${source_files[@]}" scripts/refinement-evaluation.swift \
  -o "$build_dir/evaluate"
if [[ ${#availability_args[@]} -gt 0 ]]; then
  "$build_dir/evaluate" "$label" "$root_dir/output/refinement-quality/$label.json" "${availability_args[@]}"
else
  "$build_dir/evaluate" "$label" "$root_dir/output/refinement-quality/$label.json"
fi
