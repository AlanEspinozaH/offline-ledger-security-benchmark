#!/usr/bin/env python3
"""Validate the repository's normative document and traceability contracts."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterable, Sequence


EXPECTED_FILES = (
    "docs/00-research-charter.md",
    "docs/01-change-control.md",
    "docs/02-research-questions.md",
    "docs/04-threat-model.md",
    "docs/05-record-format.md",
    "docs/06-mechanism-specifications.md",
    "docs/11-measurement-contract.md",
    "docs/16-traceability-matrix.csv",
    "docs/17-agent-workflow.md",
    "docs/decisions/README.md",
    "docs/decisions/ADR-000-template.md",
    "docs/decisions/ADR-001-authenticated-encoding-v1.md",
    "docs/decisions/ADR-002-key-scope-and-provisioning.md",
    "docs/decisions/ADR-003-append-measurement-boundary.md",
)

GOVERNED_GENERAL_DOCUMENTS = frozenset(
    path
    for path in EXPECTED_FILES
    if path.endswith(".md")
    and "/ADR-" not in path
    and path != "docs/decisions/README.md"
)

DECISIONS_README = "docs/decisions/README.md"
GENERAL_KEYS = ("document_id", "title", "version", "status")
ADR_KEYS = ("decision_id", "title", "version", "status", "date", "decided_by")
ALLOWED_STATUSES = frozenset(
    {"DRAFT", "PROVISIONAL", "APPROVED", "SUPERSEDED", "REJECTED"}
)
TEXT_EXTENSIONS = frozenset({".md", ".csv", ".json", ".yml", ".yaml"})
SEMVER_RE = re.compile(
    r"^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$"
)
ADR_REFERENCE_RE = re.compile(r"\bADR-[0-9]+\b")
DOCUMENT_PATH_RE = re.compile(
    r"`(?P<path>docs/(?:[A-Za-z0-9_.-]+/)*"
    r"[A-Za-z0-9_.-]+\.(?:md|csv|json|yml|yaml))`"
)

TRACEABILITY_HEADER = (
    "trace_id",
    "rq_id",
    "hypothesis_id",
    "requirement_id",
    "mechanism_id",
    "threat_id",
    "attack_id",
    "metric_id",
    "data_field_id",
    "test_id",
    "decision_id",
    "status",
    "notes",
)


def repository_path(path: Path, root: Path) -> str:
    """Return a deterministic POSIX path relative to the repository root."""
    return path.relative_to(root).as_posix()


def iter_repository_files(root: Path) -> Iterable[Path]:
    """Yield repository files in deterministic order, excluding Git internals."""
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        relative_parts = path.relative_to(root).parts
        if ".git" not in relative_parts:
            yield path


def read_text(path: Path, root: Path, errors: list[str]) -> str | None:
    """Read UTF-8 text and report decoding failures without raising."""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"{repository_path(path, root)}: cannot read UTF-8 text: {exc}")
        return None


def validate_file_basics(root: Path, errors: list[str]) -> None:
    """Validate expected files, zero-byte docs files, and carriage returns."""
    for relative in EXPECTED_FILES:
        if not (root / relative).is_file():
            errors.append(f"{relative}: expected file does not exist")

    docs = root / "docs"
    if docs.is_dir():
        for path in sorted(docs.rglob("*")):
            if path.is_file() and path.stat().st_size == 0:
                errors.append(f"{repository_path(path, root)}: file is empty")

    for path in iter_repository_files(root):
        if path.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        try:
            content = path.read_bytes()
        except OSError as exc:
            errors.append(f"{repository_path(path, root)}: cannot read bytes: {exc}")
            continue
        if b"\r" in content:
            errors.append(f"{repository_path(path, root)}: contains CR bytes")


def looks_like_displaced_front_matter(lines: Sequence[str]) -> bool:
    """Identify a metadata block whose opening delimiter is not line one."""
    try:
        opening = lines.index("---")
        closing = lines.index("---", opening + 1)
    except ValueError:
        return False
    if opening == 0:
        return False
    known_keys = set(GENERAL_KEYS) | set(ADR_KEYS)
    block_keys = {
        line.split(":", 1)[0].strip()
        for line in lines[opening + 1 : closing]
        if ":" in line
    }
    return bool(known_keys & block_keys)


def parse_front_matter(
    path: Path,
    root: Path,
    required: bool,
    errors: list[str],
) -> dict[str, str] | None:
    """Parse the simple YAML mapping used by governed Markdown documents."""
    text = read_text(path, root, errors)
    if text is None:
        return None

    relative = repository_path(path, root)
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        if required or looks_like_displaced_front_matter(lines):
            errors.append(
                f"{relative}: front matter opening delimiter must be first line"
            )
        return None

    try:
        closing = lines.index("---", 1)
    except ValueError:
        errors.append(f"{relative}: front matter has no closing delimiter")
        return None

    metadata: dict[str, str] = {}
    for line_number, line in enumerate(lines[1:closing], start=2):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in line:
            errors.append(
                f"{relative}:{line_number}: malformed front matter entry"
            )
            continue
        key, value = (part.strip() for part in line.split(":", 1))
        if not key:
            errors.append(f"{relative}:{line_number}: empty front matter key")
            continue
        if key in metadata:
            errors.append(
                f"{relative}:{line_number}: duplicate front matter key '{key}'"
            )
            continue
        metadata[key] = value
    return metadata


def is_adr(path: Path) -> bool:
    return path.parent.name == "decisions" and path.match("ADR-*.md")


def required_keys_for(path: Path, root: Path) -> tuple[str, ...]:
    relative = repository_path(path, root)
    return ADR_KEYS if is_adr(path) else GENERAL_KEYS


def validate_required_metadata(
    path: Path,
    root: Path,
    metadata: dict[str, str],
    errors: list[str],
) -> None:
    relative = repository_path(path, root)
    for key in required_keys_for(path, root):
        if not metadata.get(key):
            errors.append(
                f"{relative}: required front matter key '{key}' is missing or empty"
            )

    version = metadata.get("version")
    if version and not SEMVER_RE.fullmatch(version):
        errors.append(f"{relative}: invalid semantic version '{version}'")

    status = metadata.get("status")
    if status and status not in ALLOWED_STATUSES:
        errors.append(f"{relative}: invalid status '{status}'")


def report_duplicate_identifiers(
    identifier_name: str,
    locations: dict[str, list[str]],
    errors: list[str],
) -> None:
    for identifier in sorted(locations):
        paths = locations[identifier]
        if len(paths) > 1:
            errors.append(
                f"duplicate {identifier_name} '{identifier}': {', '.join(paths)}"
            )


def validate_front_matter(root: Path, errors: list[str]) -> set[str]:
    """Validate governed metadata and return all declared ADR identifiers."""
    docs = root / "docs"
    if not docs.is_dir():
        return set()

    document_locations: dict[str, list[str]] = defaultdict(list)
    decision_locations: dict[str, list[str]] = defaultdict(list)

    for path in sorted(docs.rglob("*.md")):
        relative = repository_path(path, root)
        required = (
            relative in GOVERNED_GENERAL_DOCUMENTS
            or relative == DECISIONS_README
            or is_adr(path)
        )
        metadata = parse_front_matter(path, root, required, errors)
        if metadata is None:
            continue
        validate_required_metadata(path, root, metadata, errors)

        document_id = metadata.get("document_id")
        if document_id:
            document_locations[document_id].append(relative)
        decision_id = metadata.get("decision_id")
        if decision_id:
            decision_locations[decision_id].append(relative)

    report_duplicate_identifiers("document_id", document_locations, errors)
    report_duplicate_identifiers("decision_id", decision_locations, errors)
    return set(decision_locations)


def read_traceability_rows(
    root: Path,
    decision_ids: set[str],
    errors: list[str],
) -> list[dict[str, str]]:
    """Validate and return structurally usable traceability rows."""
    path = root / "docs/16-traceability-matrix.csv"
    if not path.is_file():
        return []

    try:
        with path.open(encoding="utf-8", newline="") as handle:
            reader = csv.reader(handle)
            header = next(reader, None)
            raw_rows = list(reader)
    except (OSError, UnicodeError, csv.Error) as exc:
        errors.append(f"docs/16-traceability-matrix.csv: cannot parse CSV: {exc}")
        return []

    if header != list(TRACEABILITY_HEADER):
        errors.append(
            "docs/16-traceability-matrix.csv: header must exactly equal "
            + ",".join(TRACEABILITY_HEADER)
        )

    if not any(row for row in raw_rows):
        errors.append("docs/16-traceability-matrix.csv: requires at least one data row")

    seen_trace_ids: dict[str, int] = {}
    valid_rows: list[dict[str, str]] = []
    for line_number, row in enumerate(raw_rows, start=2):
        if len(row) != len(TRACEABILITY_HEADER):
            errors.append(
                "docs/16-traceability-matrix.csv:"
                f"{line_number}: expected 13 columns, found {len(row)}"
            )
            continue

        record = dict(zip(TRACEABILITY_HEADER, row))
        valid_rows.append(record)
        trace_id = record["trace_id"].strip()
        if not trace_id:
            errors.append(
                f"docs/16-traceability-matrix.csv:{line_number}: trace_id is empty"
            )
        elif trace_id in seen_trace_ids:
            errors.append(
                "docs/16-traceability-matrix.csv:"
                f"{line_number}: duplicate trace_id '{trace_id}' "
                f"(first declared on line {seen_trace_ids[trace_id]})"
            )
        else:
            seen_trace_ids[trace_id] = line_number

        status = record["status"].strip()
        if not status:
            errors.append(
                f"docs/16-traceability-matrix.csv:{line_number}: status is empty"
            )
        elif status not in ALLOWED_STATUSES:
            errors.append(
                "docs/16-traceability-matrix.csv:"
                f"{line_number}: invalid status '{status}'"
            )

        decision_cell = record["decision_id"].strip()
        references = ADR_REFERENCE_RE.findall(decision_cell)
        if len(references) > 1:
            errors.append(
                "docs/16-traceability-matrix.csv:"
                f"{line_number}: decision_id combines multiple ADR references "
                f"ambiguously: '{decision_cell}'"
            )
        for reference in references:
            if reference not in decision_ids:
                errors.append(
                    "docs/16-traceability-matrix.csv:"
                    f"{line_number}: decision_id references missing '{reference}'"
                )

    return valid_rows


def validate_document_references(root: Path, errors: list[str]) -> None:
    """Validate explicit repository paths written as Markdown inline code."""
    docs = root / "docs"
    if not docs.is_dir():
        return
    for path in sorted(docs.rglob("*.md")):
        text = read_text(path, root, errors)
        if text is None:
            continue
        relative = repository_path(path, root)
        for match in DOCUMENT_PATH_RE.finditer(text):
            reference = match.group("path")
            if not (root / reference).is_file():
                errors.append(
                    f"{relative}: referenced repository path does not exist: "
                    f"{reference}"
                )


def markdown_section(text: str, identifier: str) -> str | None:
    """Return the level-two Markdown section whose heading starts with an ID."""
    lines = text.splitlines()
    heading = re.compile(rf"^##\s+{re.escape(identifier)}(?:\s|$)")
    start: int | None = None
    for index, line in enumerate(lines):
        if start is None and heading.match(line):
            start = index
            continue
        if start is not None and line.startswith("## "):
            return "\n".join(lines[start:index])
    return "\n".join(lines[start:]) if start is not None else None


def require_section_invariants(
    root: Path,
    relative: str,
    identifier: str,
    required_tokens: Sequence[str],
    errors: list[str],
) -> None:
    path = root / relative
    if not path.is_file():
        return
    text = read_text(path, root, errors)
    if text is None:
        return
    section = markdown_section(text, identifier)
    if section is None:
        errors.append(f"{relative}: missing section for {identifier}")
        return
    for token in required_tokens:
        if token not in section:
            errors.append(f"{relative}: {identifier} section must reference {token}")


def validate_baseline_invariants(
    root: Path,
    rows: Sequence[dict[str, str]],
    errors: list[str],
) -> None:
    """Validate current blockers without interpreting or changing their meaning."""
    # These invariants encode the current normative baseline. They must be
    # updated only through an approved normative change when a contract is
    # approved or a mechanism/metric is unblocked.
    require_section_invariants(
        root,
        "docs/06-mechanism-specifications.md",
        "MEC-A1",
        ("BLOCKED", "ADR-001", "ADR-002"),
        errors,
    )
    require_section_invariants(
        root,
        "docs/11-measurement-contract.md",
        "MET-APPEND-READY-E2E",
        ("BLOCKED", "ADR-003"),
        errors,
    )

    required_relations = (
        ("mechanism_id", "MEC-A1", "ADR-001"),
        ("mechanism_id", "MEC-A1", "ADR-002"),
        ("metric_id", "MET-APPEND-READY-E2E", "ADR-003"),
    )
    for column, subject, decision_id in required_relations:
        if not any(
            row[column].strip() == subject
            and row["decision_id"].strip() == decision_id
            for row in rows
        ):
            errors.append(
                "docs/16-traceability-matrix.csv: missing independent relation "
                f"{subject} -> {decision_id}"
            )


def validate_repository(root: Path) -> list[str]:
    """Run all validations and return deterministic error messages."""
    root = root.resolve()
    errors: list[str] = []
    validate_file_basics(root, errors)
    decision_ids = validate_front_matter(root, errors)
    rows = read_traceability_rows(root, decision_ids, errors)
    validate_document_references(root, errors)
    validate_baseline_invariants(root, rows, errors)
    return errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate normative document and traceability contracts."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to the parent of scripts/)",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    errors = validate_repository(args.root)
    if errors:
        print(f"Normative contract validation failed with {len(errors)} error(s):")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Normative contract validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
