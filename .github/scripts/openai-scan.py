#!/usr/bin/env python3
"""
openai-scan.py — OpenAI-backed CSI scanner (scan-only, no file editing).

Reads the same agent prompt used by the Copilot CLI backend and sends it to
the OpenAI API. Outputs a structured CSI report in the same format.

NOTE: This backend is scan-only. It cannot apply fixes because it lacks the
Copilot CLI's tool-use capability for file editing. Use the Copilot backend
for full scan-and-fix functionality.

Usage:
    python openai-scan.py --prompt-file <path> --output <path> [--model <model>] [--timeout <seconds>]
    python openai-scan.py --output <path> --fallback-report <error_message>

    When --fallback-report is given, --prompt-file is not required. The script
    writes a CSI-contract-compliant failure report and exits with code 1.

Requires:
    - OPENAI_API_KEY environment variable (not needed with --fallback-report)
    - openai>=1.0.0 pip package (not needed with --fallback-report)
"""

import argparse
import os
import subprocess
import sys
import textwrap
from datetime import datetime, timezone
from pathlib import Path


def get_repo_context(max_files: int = 100) -> str:
    """Gather repository context: file tree and key file contents."""
    lines = ["## Repository Structure\n"]

    # File tree (excluding common noise)
    try:
        result = subprocess.run(
            [
                "find", ".", "-maxdepth", "4", "-type", "f",
                "-not", "-path", "*/node_modules/*",
                "-not", "-path", "*/.git/*",
                "-not", "-path", "*/vendor/*",
                "-not", "-path", "*/__pycache__/*",
                "-not", "-path", "*/dist/*",
                "-not", "-path", "*/.venv/*",
            ],
            capture_output=True, text=True, timeout=30
        )
        files = sorted(result.stdout.strip().splitlines())[:max_files]
        lines.append("```")
        lines.extend(files)
        lines.append("```\n")
    except (subprocess.TimeoutExpired, FileNotFoundError):
        lines.append("(Could not list files)\n")

    # Read key files
    key_files = [
        "README.md", "CONTRIBUTING.md", ".gitignore", ".csi.yml",
        "package.json", "requirements.txt", "pyproject.toml",
        "Makefile", "Dockerfile", "docker-compose.yml",
    ]

    for fname in key_files:
        path = Path(fname)
        if path.is_file():
            try:
                content = path.read_text(encoding="utf-8", errors="replace")
                # Truncate large files
                if len(content) > 3000:
                    content = content[:3000] + "\n... (truncated)"
                lines.append(f"### {fname}\n```\n{content}\n```\n")
            except OSError:
                pass

    # Read workflow files
    wf_dir = Path(".github/workflows")
    if wf_dir.is_dir():
        for wf in sorted(wf_dir.glob("*.yml"))[:10]:
            try:
                content = wf.read_text(encoding="utf-8", errors="replace")
                if len(content) > 3000:
                    content = content[:3000] + "\n... (truncated)"
                lines.append(f"### {wf}\n```yaml\n{content}\n```\n")
            except OSError:
                pass

    return "\n".join(lines)


def build_scan_failure_report(error_message: str) -> str:
    """Return a CSI-formatted fallback report for backend failures."""
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    # Sanitize error: escape backticks and truncate to prevent markdown breakage
    sanitized = error_message.replace("`", "'")
    normalized_error = (" ".join(sanitized.split()) or "Unknown error")[:200]

    return textwrap.dedent(
        f"""\
        ## Applied Fix

        **Issue ID**: CSI-CONFIG-001
        **Category**: CONFIG
        **Severity**: 🔴 HIGH
        **Description**: OpenAI scan backend could not complete.

        ### What Changed
        No files were modified. OpenAI runs in scan-only mode, and this invocation failed before it could produce findings.

        ### Evidence
        `.github/scripts/openai-scan.py` fallback report: `{normalized_error}`

        ### Verification
        Re-run the scan after resolving the backend error shown above.

        ---

        ## Remaining Issues

        1. **[CONFIG] 🔴 HIGH**: OpenAI scan backend could not complete — `.github/scripts/openai-scan.py:92-135`

        ---

        ## Scan Summary

        | Category | Issues Found |
        |----------|-------------|
        | DRY Violations | 0 |
        | Documentation Drift | 0 |
        | Tooling Currency | 0 |
        | Dead Code | 0 |
        | Code Quality | 0 |
        | Security Hygiene | 0 |
        | Dependency Health | 0 |
        | Config Consistency | 1 |
        | **Total** | **1** |

        *Scan completed: {timestamp}*
        """
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenAI-backed CSI scanner")
    parser.add_argument("--prompt-file", required=False, help="Path to the agent prompt file")
    parser.add_argument("--output", required=True, help="Path to write the report")
    parser.add_argument("--model", default="gpt-4o", help="OpenAI model to use")
    parser.add_argument("--timeout", type=int, default=900, help="Timeout in seconds")
    parser.add_argument("--fallback-report", metavar="MSG", help="Write a CSI-formatted failure report with the given error message and exit")
    args = parser.parse_args()
    output_path = Path(args.output)

    def write_report_and_exit(report: str, exit_code: int = 0) -> None:
        """Write report to output path (creating parent dirs) and exit."""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(report, encoding="utf-8")
        line_count = len(report.splitlines())
        print(f"CSI report written: {output_path} ({line_count} lines)")
        sys.exit(exit_code)

    # Fallback report mode: write a CSI-formatted failure report and exit
    if args.fallback_report:
        write_report_and_exit(build_scan_failure_report(args.fallback_report), exit_code=1)

    if not args.prompt_file:
        print("::error::--prompt-file is required when not using --fallback-report", file=sys.stderr)
        write_report_and_exit(build_scan_failure_report("--prompt-file is required"), exit_code=1)

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        print("::error::OPENAI_API_KEY environment variable is not set", file=sys.stderr)
        write_report_and_exit(build_scan_failure_report("OPENAI_API_KEY environment variable is not set"), exit_code=1)

    try:
        from openai import OpenAI
    except ImportError:
        print("::error::openai package not installed. Run: pip install openai>=1.0.0", file=sys.stderr)
        write_report_and_exit(build_scan_failure_report("openai package not installed. Run: pip install openai>=1.0.0"), exit_code=1)

    # Read the prompt
    prompt_path = Path(args.prompt_file)
    if not prompt_path.is_file():
        print(f"::error::Prompt file not found: {args.prompt_file}", file=sys.stderr)
        write_report_and_exit(build_scan_failure_report(f"Prompt file not found: {args.prompt_file}"), exit_code=1)

    agent_prompt = prompt_path.read_text(encoding="utf-8")

    # Gather repo context (since OpenAI can't browse files)
    repo_context = get_repo_context()

    system_message = textwrap.dedent("""\
        You are a repository maintenance scanner. You analyze codebases for
        maintenance issues across these categories: DRY violations, documentation
        drift, tooling currency, dead code, code quality, security hygiene,
        dependency health, and config consistency.

        You are running in SCAN-ONLY mode. You cannot edit files. Your job is to
        produce a structured CSI report that still uses the standard section
        headings expected by the workflow.

        IMPORTANT RULES:
        - Always include ALL three sections (Applied Fix, Remaining Issues, Scan Summary) even if no issues are found.
        - If no issues are found, set all counts to 0 and write "✅ No maintenance issues detected. Repository is in good health." under Remaining Issues.
        - The *Scan completed:* line must always be the very last line of your output.

        Output your response in this exact format:

        ## Applied Fix

        **Issue ID**: None
        **Category**: None
        **Severity**: None
        **Description**: No issues found requiring a fix.

        ### What Changed
        No files were modified. This is a scan-only report from the OpenAI backend.

        ### Evidence
        Summarize the evidence for the highest-priority finding, or state that no issues were found.

        ### Verification
        Briefly explain how the finding can be verified, or state that no changes were required.

        ---

        ## Remaining Issues

        <numbered list of all findings, ordered by severity HIGH → MEDIUM → LOW, each in this exact format:>
        1. **[CATEGORY] 🔴 HIGH**: Description — `file:line` evidence
        2. **[CATEGORY] 🟡 MEDIUM**: Description — `file:line` evidence
        3. **[CATEGORY] 🟢 LOW**: Description — `file:line` evidence

        ---

        ## Scan Summary

        | Category | Issues Found |
        |----------|-------------|
        | DRY Violations | X |
        | Documentation Drift | X |
        | Tooling Currency | X |
        | Dead Code | X |
        | Code Quality | X |
        | Security Hygiene | X |
        | Dependency Health | X |
        | Config Consistency | X |
        | **Total** | **X** |

        *Scan completed: <ISO 8601 timestamp>*
    """)

    user_message = f"{agent_prompt}\n\n---\n\n{repo_context}"

    client = OpenAI(api_key=api_key)

    try:
        response = client.chat.completions.create(
            model=args.model,
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": user_message},
            ],
            temperature=0.2,
            max_tokens=4096,
            timeout=args.timeout,
        )

        report = response.choices[0].message.content or ""
        if not report.strip():
            raise ValueError("OpenAI API returned an empty report")

    except Exception as exc:
        report = build_scan_failure_report(str(exc))
        print(f"::error::OpenAI API error: {exc}", file=sys.stderr)
        write_report_and_exit(report, exit_code=1)

    # Write report
    write_report_and_exit(report)


if __name__ == "__main__":
    main()
