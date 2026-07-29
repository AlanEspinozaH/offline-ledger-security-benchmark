from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPOSITORY_ROOT / "scripts/validate_contracts.py"
sys.path.insert(0, str(SCRIPT_PATH.parent))

import validate_contracts  # noqa: E402


GENERAL_DOCUMENTS = {
    "docs/00-research-charter.md": ("PT2-DOC-00", "Research Charter"),
    "docs/01-change-control.md": ("PT2-DOC-01", "Change Control"),
    "docs/02-research-questions.md": ("PT2-DOC-02", "Research Questions"),
    "docs/04-threat-model.md": ("PT2-DOC-04", "Threat Model"),
    "docs/05-record-format.md": ("PT2-DOC-05", "Record Format"),
    "docs/06-mechanism-specifications.md": (
        "PT2-DOC-06",
        "Mechanism Specifications",
    ),
    "docs/11-measurement-contract.md": ("PT2-DOC-11", "Measurement Contract"),
    "docs/decisions/README.md": (
        "PT2-DOC-DECISIONS",
        "Decision Record Governance",
    ),
}

ADR_DOCUMENTS = {
    "docs/decisions/ADR-000-template.md": ("ADR-000", "Decision Template"),
    "docs/decisions/ADR-001-authenticated-encoding-v1.md": (
        "ADR-001",
        "Authenticated Encoding",
    ),
    "docs/decisions/ADR-002-key-scope-and-provisioning.md": (
        "ADR-002",
        "Key Provisioning",
    ),
    "docs/decisions/ADR-003-append-measurement-boundary.md": (
        "ADR-003",
        "Append Boundary",
    ),
}


def general_document(document_id: str, title: str, body: str = "") -> str:
    return (
        "---\n"
        f"document_id: {document_id}\n"
        f"title: {title}\n"
        "version: 1.0.0\n"
        "status: DRAFT\n"
        "---\n\n"
        f"# {title}\n\n"
        f"{body}"
    )


def adr_document(decision_id: str, title: str) -> str:
    return (
        "---\n"
        f"decision_id: {decision_id}\n"
        f"title: {title}\n"
        "version: 1.0.0\n"
        "status: DRAFT\n"
        "date: PENDING\n"
        "decided_by: PENDING\n"
        "---\n\n"
        f"# {decision_id} — {title}\n"
    )


class ValidateContractsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.matrix_rows = [
            [
                "TRC-001",
                "RQ-01",
                "",
                "",
                "MEC-A1",
                "",
                "",
                "",
                "",
                "",
                "ADR-001",
                "DRAFT",
                "encoding",
            ],
            [
                "TRC-002",
                "RQ-01",
                "",
                "",
                "MEC-A1",
                "",
                "",
                "",
                "",
                "",
                "ADR-002",
                "DRAFT",
                "keys",
            ],
            [
                "TRC-003",
                "RQ-04",
                "",
                "",
                "",
                "",
                "",
                "MET-APPEND-READY-E2E",
                "",
                "",
                "ADR-003",
                "DRAFT",
                "measurement",
            ],
        ]
        self.create_valid_repository()

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write(self, relative: str, content: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8", newline="\n")
        return path

    def replace(self, relative: str, old: str, new: str) -> None:
        path = self.root / relative
        content = path.read_text(encoding="utf-8")
        self.assertIn(old, content)
        path.write_text(content.replace(old, new, 1), encoding="utf-8", newline="\n")

    def write_matrix(
        self,
        rows: list[list[str]] | None = None,
        header: tuple[str, ...] = validate_contracts.TRACEABILITY_HEADER,
    ) -> None:
        path = self.root / "docs/16-traceability-matrix.csv"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle, lineterminator="\n")
            writer.writerow(header)
            writer.writerows(self.matrix_rows if rows is None else rows)

    def create_valid_repository(self) -> None:
        mechanism_body = (
            "## MEC-A1 — Test mechanism\n\n"
            "### Estado de implementación\n\n"
            "`BLOCKED`\n\n"
            "- `ADR-001`\n"
            "- `ADR-002`\n"
        )
        metric_body = (
            "## MET-APPEND-READY-E2E\n\n"
            "### Estado de implementación\n\n"
            "`BLOCKED`\n\n"
            "- `ADR-003`\n"
        )
        for relative, (document_id, title) in GENERAL_DOCUMENTS.items():
            body = ""
            if relative == "docs/06-mechanism-specifications.md":
                body = mechanism_body
            elif relative == "docs/11-measurement-contract.md":
                body = metric_body
            self.write(relative, general_document(document_id, title, body))

        for relative, (decision_id, title) in ADR_DOCUMENTS.items():
            self.write(relative, adr_document(decision_id, title))
        self.write_matrix()

    def errors(self) -> list[str]:
        return validate_contracts.validate_repository(self.root)

    def assert_error(self, fragment: str) -> None:
        errors = self.errors()
        self.assertTrue(
            any(fragment in error for error in errors),
            msg=f"Expected error containing {fragment!r}; got {errors!r}",
        )

    def test_valid_repository(self) -> None:
        self.assertEqual([], self.errors())

    def test_empty_file(self) -> None:
        self.write("docs/04-threat-model.md", "")
        self.assert_error("docs/04-threat-model.md: file is empty")

    def test_crlf(self) -> None:
        path = self.root / "docs/04-threat-model.md"
        path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        self.assert_error("docs/04-threat-model.md: contains CR bytes")

    def test_front_matter_must_start_on_first_line(self) -> None:
        path = self.root / "docs/04-threat-model.md"
        path.write_text(
            "\n" + path.read_text(encoding="utf-8"),
            encoding="utf-8",
            newline="\n",
        )
        self.assert_error("front matter opening delimiter must be first line")

    def test_front_matter_requires_closing_delimiter(self) -> None:
        self.replace(
            "docs/04-threat-model.md",
            "status: DRAFT\n---\n",
            "status: DRAFT\n",
        )
        self.assert_error("front matter has no closing delimiter")

    def test_duplicate_front_matter_key(self) -> None:
        self.replace(
            "docs/04-threat-model.md",
            "title: Threat Model\n",
            "title: Threat Model\ntitle: Duplicate\n",
        )
        self.assert_error("duplicate front matter key 'title'")

    def test_missing_required_metadata(self) -> None:
        self.replace("docs/04-threat-model.md", "title: Threat Model\n", "")
        self.assert_error("required front matter key 'title' is missing or empty")

    def test_duplicate_document_id(self) -> None:
        self.replace(
            "docs/05-record-format.md",
            "document_id: PT2-DOC-05",
            "document_id: PT2-DOC-04",
        )
        self.assert_error("duplicate document_id 'PT2-DOC-04'")

    def test_duplicate_decision_id(self) -> None:
        self.replace(
            "docs/decisions/ADR-002-key-scope-and-provisioning.md",
            "decision_id: ADR-002",
            "decision_id: ADR-001",
        )
        self.assert_error("duplicate decision_id 'ADR-001'")

    def test_invalid_version(self) -> None:
        self.replace("docs/04-threat-model.md", "version: 1.0.0", "version: 1.0")
        self.assert_error("invalid semantic version '1.0'")

    def test_invalid_status(self) -> None:
        self.replace("docs/04-threat-model.md", "status: DRAFT", "status: PENDING")
        self.assert_error("invalid status 'PENDING'")

    def test_approved_adr_status_is_allowed(self) -> None:
        self.replace(
            "docs/decisions/ADR-000-template.md",
            "status: DRAFT",
            "status: APPROVED",
        )
        self.assertEqual([], self.errors())

    def test_incorrect_csv_header(self) -> None:
        header = ("wrong_trace_id",) + validate_contracts.TRACEABILITY_HEADER[1:]
        self.write_matrix(header=header)
        self.assert_error("header must exactly equal")

    def test_csv_row_with_incorrect_column_count(self) -> None:
        rows = [*self.matrix_rows, ["TRC-004", "RQ-01"]]
        self.write_matrix(rows)
        self.assert_error("expected 13 columns, found 2")

    def test_csv_requires_data_row(self) -> None:
        self.write_matrix([])
        self.assert_error("requires at least one data row")

    def test_duplicate_trace_id(self) -> None:
        duplicate = self.matrix_rows[0].copy()
        duplicate[10] = ""
        rows = [*self.matrix_rows, duplicate]
        self.write_matrix(rows)
        self.assert_error("duplicate trace_id 'TRC-001'")

    def test_empty_matrix_status(self) -> None:
        rows = [row.copy() for row in self.matrix_rows]
        rows[0][11] = ""
        self.write_matrix(rows)
        self.assert_error("status is empty")

    def test_missing_adr_in_matrix(self) -> None:
        rows = [row.copy() for row in self.matrix_rows]
        rows[0][10] = "ADR-999"
        self.write_matrix(rows)
        self.assert_error("decision_id references missing 'ADR-999'")

    def test_ambiguous_multiple_adrs_in_matrix(self) -> None:
        rows = [row.copy() for row in self.matrix_rows]
        rows[0][10] = "ADR-001 / ADR-002"
        self.write_matrix(rows)
        self.assert_error("decision_id combines multiple ADR references ambiguously")

    def test_missing_document_reference(self) -> None:
        path = self.root / "docs/04-threat-model.md"
        with path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write("\n`docs/missing-contract.md`\n")
        self.assert_error(
            "referenced repository path does not exist: docs/missing-contract.md"
        )

    def test_mec_a1_requires_blocked(self) -> None:
        self.replace("docs/06-mechanism-specifications.md", "`BLOCKED`", "`READY`")
        self.assert_error("MEC-A1 section must reference BLOCKED")

    def test_mec_a1_requires_adr_001(self) -> None:
        self.replace("docs/06-mechanism-specifications.md", "- `ADR-001`\n", "")
        self.assert_error("MEC-A1 section must reference ADR-001")

    def test_mec_a1_requires_adr_002(self) -> None:
        self.replace("docs/06-mechanism-specifications.md", "- `ADR-002`\n", "")
        self.assert_error("MEC-A1 section must reference ADR-002")

    def test_metric_requires_blocked(self) -> None:
        self.replace("docs/11-measurement-contract.md", "`BLOCKED`", "`READY`")
        self.assert_error("MET-APPEND-READY-E2E section must reference BLOCKED")

    def test_metric_requires_adr_003(self) -> None:
        self.replace("docs/11-measurement-contract.md", "- `ADR-003`\n", "")
        self.assert_error("MET-APPEND-READY-E2E section must reference ADR-003")

    def test_cli_exit_codes(self) -> None:
        valid = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--root", str(self.root)],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, valid.returncode, valid.stdout + valid.stderr)
        self.assertEqual("Normative contract validation passed.\n", valid.stdout)

        self.write("docs/04-threat-model.md", "")
        invalid = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--root", str(self.root)],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(0, invalid.returncode)
        self.assertIn("Normative contract validation failed", invalid.stdout)


if __name__ == "__main__":
    unittest.main()
