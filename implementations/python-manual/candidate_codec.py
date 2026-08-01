#!/usr/bin/env python3
"""Positive-only manual producer for PT2-CBOR-AUTH-RECORD-CANDIDATE-v1.

Every byte sequence produced here is CANDIDATO NO NORMATIVO.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ARTIFACT_STATUS = "CANDIDATO NO NORMATIVO"
PROFILE_ID = "PT2-CBOR-AUTH-RECORD-CANDIDATE-v1"
DOMAIN = "PT2:MEC-A1:HMAC-SHA-256:RECORD:v1"

INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1
MAX_OCCURRED_AT = 253_402_300_799_999
MAX_RECORD_BYTES = 65_536
MAX_CONTAINER_ITEMS = 256
MAX_TEXT_BYTES = 16_384
MAX_DEPTH = 9
_LEDGER_HEX = re.compile(r"[0-9a-f]{32}\Z")


class CandidateCodecError(ValueError):
    """Raised when a logical input is outside the candidate profile."""


@dataclass(frozen=True)
class Record:
    schema_version: int
    mechanism_version: int
    ledger_id: bytes
    sequence: int
    event_type: str
    occurred_at: int
    operator_id: str
    amount_cents: int
    payload: dict[str, Any]


@dataclass(frozen=True)
class Fixture:
    case_id: str
    record: Record


def _utf8(value: str, name: str) -> bytes:
    try:
        return value.encode("utf-8", errors="strict")
    except UnicodeEncodeError as error:
        raise CandidateCodecError(
            f"{name} must contain valid Unicode scalar values"
        ) from error


def _validate_bounded_text(
    name: str, value: Any, minimum: int, maximum: int
) -> None:
    if type(value) is not str:
        raise CandidateCodecError(f"{name} must be text")
    size = len(_utf8(value, name))
    if size < minimum or size > maximum:
        raise CandidateCodecError(
            f"{name} UTF-8 length must be in {minimum}..{maximum} bytes"
        )


def _validate_int64(name: str, value: Any) -> None:
    if type(value) is not int or value < INT64_MIN or value > INT64_MAX:
        raise CandidateCodecError(f"{name} must be an int64")


def _validate_payload(value: Any, depth: int) -> None:
    if type(value) is str:
        if len(_utf8(value, "payload text")) > MAX_TEXT_BYTES:
            raise CandidateCodecError(
                f"payload text exceeds {MAX_TEXT_BYTES} UTF-8 bytes"
            )
        return
    if type(value) is int:
        _validate_int64("payload integer", value)
        return
    if type(value) is bool:
        return
    if type(value) is list:
        if depth > MAX_DEPTH:
            raise CandidateCodecError(
                f"payload exceeds structural depth {MAX_DEPTH}"
            )
        if len(value) > MAX_CONTAINER_ITEMS:
            raise CandidateCodecError(
                f"payload array exceeds {MAX_CONTAINER_ITEMS} elements"
            )
        for item in value:
            _validate_payload(item, depth + 1)
        return
    if type(value) is dict:
        if depth > MAX_DEPTH:
            raise CandidateCodecError(
                f"payload exceeds structural depth {MAX_DEPTH}"
            )
        if len(value) > MAX_CONTAINER_ITEMS:
            raise CandidateCodecError(
                f"payload map exceeds {MAX_CONTAINER_ITEMS} pairs"
            )
        for key, item in value.items():
            _validate_bounded_text("payload map key", key, 1, 128)
            _validate_payload(item, depth + 1)
        return
    raise CandidateCodecError(
        f"payload contains prohibited Python type {type(value).__name__}"
    )


def validate_record(record: Record) -> None:
    if type(record.schema_version) is not int or record.schema_version != 1:
        raise CandidateCodecError(
            f"schema_version must be 1 for {PROFILE_ID}"
        )
    if (
        type(record.mechanism_version) is not int
        or record.mechanism_version != 1
    ):
        raise CandidateCodecError(
            f"mechanism_version must be 1 for {PROFILE_ID}"
        )
    if type(record.ledger_id) is not bytes or len(record.ledger_id) != 16:
        raise CandidateCodecError("ledger_id must contain exactly 16 bytes")
    if (
        type(record.sequence) is not int
        or record.sequence < 1
        or record.sequence > INT64_MAX
    ):
        raise CandidateCodecError("sequence must be in 1..2^63-1")
    _validate_bounded_text("event_type", record.event_type, 1, 64)
    if (
        type(record.occurred_at) is not int
        or record.occurred_at < 0
        or record.occurred_at > MAX_OCCURRED_AT
    ):
        raise CandidateCodecError(
            f"occurred_at must be in 0..{MAX_OCCURRED_AT}"
        )
    _validate_bounded_text("operator_id", record.operator_id, 1, 128)
    _validate_int64("amount_cents", record.amount_cents)
    if type(record.payload) is not dict:
        raise CandidateCodecError("payload must be a map")
    _validate_payload(record.payload, 2)


def _encode_head(major_type: int, argument: int) -> bytes:
    if argument < 0:
        raise CandidateCodecError("CBOR head argument must be nonnegative")
    prefix = major_type << 5
    if argument < 24:
        return bytes((prefix | argument,))
    if argument <= 0xFF:
        return bytes((prefix | 24, argument))
    if argument <= 0xFFFF:
        return bytes((prefix | 25,)) + argument.to_bytes(2, "big")
    if argument <= 0xFFFF_FFFF:
        return bytes((prefix | 26,)) + argument.to_bytes(4, "big")
    if argument <= 0xFFFF_FFFF_FFFF_FFFF:
        return bytes((prefix | 27,)) + argument.to_bytes(8, "big")
    raise CandidateCodecError("CBOR head argument exceeds uint64")


def _head_size(argument: int) -> int:
    if argument < 0:
        raise CandidateCodecError(
            "CBOR head argument must be nonnegative"
        )
    if argument < 24:
        return 1
    if argument <= 0xFF:
        return 2
    if argument <= 0xFFFF:
        return 3
    if argument <= 0xFFFF_FFFF:
        return 5
    if argument <= 0xFFFF_FFFF_FFFF_FFFF:
        return 9
    raise CandidateCodecError("CBOR head argument exceeds uint64")


def _encoded_size(value: Any) -> int:
    if type(value) is bool:
        return 1

    if type(value) is int:
        _validate_int64("integer", value)
        argument = value if value >= 0 else -1 - value
        return _head_size(argument)

    if type(value) is bytes:
        return _head_size(len(value)) + len(value)

    if type(value) is str:
        encoded = _utf8(value, "text")
        return _head_size(len(encoded)) + len(encoded)

    if type(value) is list:
        total = _head_size(len(value))

        for item in value:
            total += _encoded_size(item)

            if total > MAX_RECORD_BYTES:
                return total

        return total

    if type(value) is dict:
        total = _head_size(len(value))

        for key, item in value.items():
            if type(key) is not str:
                raise CandidateCodecError(
                    "CBOR map keys must be text"
                )

            total += _encoded_size(key)
            total += _encoded_size(item)

            if total > MAX_RECORD_BYTES:
                return total

        return total

    raise CandidateCodecError(
        "cannot size prohibited Python type "
        f"{type(value).__name__}"
    )

def _encode_value(value: Any) -> bytes:
    if type(value) is bool:
        return b"\xf5" if value else b"\xf4"
    if type(value) is int:
        _validate_int64("integer", value)
        if value >= 0:
            return _encode_head(0, value)
        return _encode_head(1, -1 - value)
    if type(value) is bytes:
        return _encode_head(2, len(value)) + value
    if type(value) is str:
        encoded = _utf8(value, "text")
        return _encode_head(3, len(encoded)) + encoded
    if type(value) is list:
        return _encode_head(4, len(value)) + b"".join(
            _encode_value(item) for item in value
        )
    if type(value) is dict:
        pairs: list[tuple[bytes, bytes]] = []
        for key, item in value.items():
            if type(key) is not str:
                raise CandidateCodecError("CBOR map keys must be text")
            encoded_key = _encode_value(key)
            pairs.append((encoded_key, _encode_value(item)))
        pairs.sort(key=lambda pair: pair[0])
        return _encode_head(5, len(pairs)) + b"".join(
            key + item for key, item in pairs
        )
    raise CandidateCodecError(
        f"cannot encode prohibited Python type {type(value).__name__}"
    )


def encode(record: Record) -> bytes:
    """Validate and encode the candidate ten-element outer array."""

    validate_record(record)
    outer = [
        DOMAIN,
        record.schema_version,
        record.mechanism_version,
        record.ledger_id,
        record.sequence,
        record.event_type,
        record.occurred_at,
        record.operator_id,
        record.amount_cents,
        record.payload,
    ]
    candidate_size = _encoded_size(outer)

    if candidate_size > MAX_RECORD_BYTES:
        raise CandidateCodecError(
            f"candidate record is {candidate_size} bytes; "
            f"maximum is {MAX_RECORD_BYTES}"
        )

    encoded = _encode_value(outer)

    if len(encoded) > MAX_RECORD_BYTES:
        raise CandidateCodecError(
            f"candidate record is {len(encoded)} bytes; "
            f"maximum is {MAX_RECORD_BYTES}"
        )

    if len(encoded) != candidate_size:
        raise CandidateCodecError(
            f"manual encoder produced {len(encoded)} bytes; "
            f"validated size was {candidate_size}"
        )

    return encoded


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise CandidateCodecError(f"duplicate JSON object key {key!r}")
        result[key] = value
    return result


def _reject_noninteger(token: str) -> None:
    raise CandidateCodecError(f"JSON number {token!r} is not an integer")


def _decode_json(data: str) -> Any:
    try:
        return json.loads(
            data,
            object_pairs_hook=_unique_object,
            parse_float=_reject_noninteger,
            parse_constant=_reject_noninteger,
        )
    except json.JSONDecodeError as error:
        raise CandidateCodecError(f"decode fixture JSON: {error}") from error


def _require_exact_keys(
    value: Any, name: str, expected: set[str]
) -> dict[str, Any]:
    if type(value) is not dict:
        raise CandidateCodecError(f"{name} must be a JSON object")
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise CandidateCodecError(
            f"{name} fields differ; missing={missing}, extra={extra}"
        )
    return value


def _require_string(value: Any, name: str) -> str:
    if type(value) is not str:
        raise CandidateCodecError(f"{name} must be a JSON string")
    return value


def _require_integer(value: Any, name: str) -> int:
    if type(value) is not int:
        raise CandidateCodecError(f"{name} must be a JSON integer")
    return value


def decode_fixture(data: str) -> Fixture:
    root = _require_exact_keys(
        _decode_json(data),
        "fixture",
        {"artifact_status", "profile", "case_id", "record"},
    )
    if _require_string(root["artifact_status"], "artifact_status") != ARTIFACT_STATUS:
        raise CandidateCodecError(
            f"artifact_status must be {ARTIFACT_STATUS!r}"
        )
    if _require_string(root["profile"], "profile") != PROFILE_ID:
        raise CandidateCodecError(f"profile must be {PROFILE_ID!r}")
    case_id = _require_string(root["case_id"], "case_id")
    if not case_id:
        raise CandidateCodecError("case_id must not be empty")

    record_data = _require_exact_keys(
        root["record"],
        "record",
        {
            "domain",
            "schema_version",
            "mechanism_version",
            "ledger_id_hex",
            "sequence",
            "event_type",
            "occurred_at",
            "operator_id",
            "amount_cents",
            "payload",
        },
    )
    if _require_string(record_data["domain"], "domain") != DOMAIN:
        raise CandidateCodecError(f"domain must be {DOMAIN!r}")
    ledger_hex = _require_string(
        record_data["ledger_id_hex"], "ledger_id_hex"
    )
    if _LEDGER_HEX.fullmatch(ledger_hex) is None:
        raise CandidateCodecError(
            "ledger_id_hex must contain exactly 32 lowercase "
            "hexadecimal characters"
        )

    record = Record(
        schema_version=_require_integer(
            record_data["schema_version"], "schema_version"
        ),
        mechanism_version=_require_integer(
            record_data["mechanism_version"], "mechanism_version"
        ),
        ledger_id=bytes.fromhex(ledger_hex),
        sequence=_require_integer(record_data["sequence"], "sequence"),
        event_type=_require_string(record_data["event_type"], "event_type"),
        occurred_at=_require_integer(
            record_data["occurred_at"], "occurred_at"
        ),
        operator_id=_require_string(
            record_data["operator_id"], "operator_id"
        ),
        amount_cents=_require_integer(
            record_data["amount_cents"], "amount_cents"
        ),
        payload=record_data["payload"],
    )
    validate_record(record)
    return Fixture(case_id=case_id, record=record)


def load_fixture(path: str | Path) -> Fixture:
    try:
        data = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise CandidateCodecError(f"read fixture: {error}") from error
    return decode_fixture(data)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} FIXTURE.json", file=sys.stderr)
        return 2
    try:
        fixture = load_fixture(argv[1])
        print(encode(fixture.record).hex())
    except CandidateCodecError as error:
        print(f"candidate codec error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
