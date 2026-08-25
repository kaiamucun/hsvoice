#!/usr/bin/env python3
"""Generate an HS Voice PPPC profile from the final signed application."""

from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys
import uuid
from pathlib import Path


SERVICES = ("Accessibility", "PostEvent", "SpeechRecognition")


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_bundle_identifier(app_path: Path) -> str:
    info_path = app_path / "Contents" / "Info.plist"
    if not info_path.is_file():
        fail(f"Info.plist not found: {info_path}")
    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    identifier = info.get("CFBundleIdentifier")
    if not isinstance(identifier, str) or not identifier:
        fail("CFBundleIdentifier is missing from the application")
    return identifier


def read_code_requirement(app_path: Path) -> str:
    result = subprocess.run(
        ["codesign", "-dr", "-", str(app_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        fail(f"codesign could not read the application requirement:\n{result.stdout.strip()}")
    for line in result.stdout.splitlines():
        marker = "designated =>"
        if marker in line:
            requirement = line.split(marker, 1)[1].strip()
            if requirement:
                return requirement
    fail("codesign did not return a designated requirement")


def is_stable_developer_id_requirement(requirement: str) -> bool:
    lowered = requirement.lower()
    return "cdhash" not in lowered and "anchor apple generic" in lowered


def payload_base(identifier: str, display_name: str) -> dict[str, object]:
    return {
        "PayloadDisplayName": display_name,
        "PayloadIdentifier": identifier,
        "PayloadType": "Configuration",
        "PayloadUUID": str(uuid.uuid4()).upper(),
        "PayloadVersion": 1,
    }


def make_profile(
    bundle_identifier: str,
    code_requirement: str,
    organization: str,
    payload_identifier: str,
) -> dict[str, object]:
    privacy_payload_id = f"{payload_identifier}.privacy"
    privacy_payload = payload_base(privacy_payload_id, "HS Voice Privacy Permissions")
    privacy_payload.update(
        {
            "PayloadType": "com.apple.TCC.configuration-profile-policy",
            "Services": {
                service: [
                    {
                        "Allowed": True,
                        "CodeRequirement": code_requirement,
                        "Identifier": bundle_identifier,
                        "IdentifierType": "bundleID",
                        "StaticCode": False,
                    }
                ]
                for service in SERVICES
            },
        }
    )

    profile = payload_base(payload_identifier, "HS Voice Managed Permissions")
    profile.update(
        {
            "ConsentText": {
                "default": (
                    "HS Voiceが音声認識結果を業務アプリへ入力できるよう、"
                    "会社が必要なプライバシー権限を管理します。"
                )
            },
            "Organization": organization,
            "PayloadContent": [privacy_payload],
            "PayloadDescription": (
                "HS Voiceの音声認識と自動入力に必要な権限を構成します。"
                "マイク権限はmacOS上で利用者本人が許可します。"
            ),
            "PayloadRemovalDisallowed": False,
            "PayloadScope": "System",
        }
    )
    return profile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a legacy PPPC mobileconfig for managed macOS 14–26 devices."
    )
    parser.add_argument("--app", required=True, type=Path, help="Final signed HS Voice.app")
    parser.add_argument("--output", required=True, type=Path, help="Output .mobileconfig path")
    parser.add_argument("--organization", required=True, help="Company display name")
    parser.add_argument(
        "--payload-identifier",
        help="Stable profile identifier (default: <bundle-id>.deployment.pppc)",
    )
    parser.add_argument(
        "--allow-adhoc",
        action="store_true",
        help="Allow a CDHash/ad-hoc requirement for local structural testing only",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    app_path = args.app.resolve()
    if not app_path.is_dir():
        fail(f"application not found: {app_path}")

    bundle_identifier = read_bundle_identifier(app_path)
    code_requirement = read_code_requirement(app_path)
    if not is_stable_developer_id_requirement(code_requirement) and not args.allow_adhoc:
        fail(
            "the application has an ad-hoc or unstable code requirement; build it with a "
            "Developer ID Application identity before generating a production PPPC profile"
        )
    if not is_stable_developer_id_requirement(code_requirement):
        print("warning: generated profile is for local structure testing only", file=sys.stderr)

    payload_identifier = args.payload_identifier or f"{bundle_identifier}.deployment.pppc"
    profile = make_profile(
        bundle_identifier=bundle_identifier,
        code_requirement=code_requirement,
        organization=args.organization,
        payload_identifier=payload_identifier,
    )

    output_path = args.output.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as handle:
        plistlib.dump(profile, handle, fmt=plistlib.FMT_XML, sort_keys=False)
    print(f"PPPC profile written: {output_path}")
    print("Microphone is intentionally omitted because legacy PPPC cannot grant it.")


if __name__ == "__main__":
    main()
