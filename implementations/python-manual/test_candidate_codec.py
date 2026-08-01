import unittest

import candidate_codec as codec


def valid_record() -> codec.Record:
    return codec.Record(
        schema_version=1,
        mechanism_version=1,
        ledger_id=bytes(16),
        sequence=1,
        event_type="x",
        occurred_at=0,
        operator_id="x",
        amount_cents=0,
        payload={},
    )


def nested_arrays(count: int) -> object:
    value: object = 0
    for _ in range(count):
        value = [value]
    return value


def logical_outer_for_test(record: codec.Record) -> list[object]:
    return [
        codec.DOMAIN,
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


def record_with_encoded_size(
    test_case: unittest.TestCase, target: int
) -> codec.Record:
    full_text = "x" * codec.MAX_TEXT_BYTES
    payload = {
        "a": full_text,
        "b": full_text,
        "c": full_text,
        "d": "",
    }
    record = codec.Record(
        **{
            **valid_record().__dict__,
            "payload": payload,
        }
    )
    base_size = codec._encoded_size(logical_outer_for_test(record))
    required_delta = target - base_size

    for text_length in range(codec.MAX_TEXT_BYTES + 1):
        encoded_text_delta = (
            codec._head_size(text_length)
            + text_length
            - codec._head_size(0)
        )
        if encoded_text_delta != required_delta:
            continue

        payload["d"] = "x" * text_length
        record = codec.Record(
            **{
                **valid_record().__dict__,
                "payload": dict(payload),
            }
        )
        test_case.assertEqual(
            codec._encoded_size(logical_outer_for_test(record)),
            target,
        )
        return record

    test_case.fail(f"unable to construct candidate record of {target} bytes")
    raise AssertionError("unreachable")


class ManualEncodingTests(unittest.TestCase):
    def test_integer_boundaries_use_minimal_representations(self) -> None:
        cases = {
            0: "00",
            23: "17",
            24: "1818",
            255: "18ff",
            256: "190100",
            -1: "20",
            -24: "37",
            -25: "3818",
            codec.INT64_MIN: "3b7fffffffffffffff",
            codec.INT64_MAX: "1b7fffffffffffffff",
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                self.assertEqual(codec._encode_value(value).hex(), expected)

    def test_map_keys_use_encoded_bytewise_order(self) -> None:
        encoded = codec._encode_value({"aa": 1, "b": 2, "a": 3})
        self.assertEqual(encoded.hex(), "a361610361620262616101")

    def test_record_is_repeatable_and_has_ten_element_array(self) -> None:
        record = valid_record()
        record.payload.update({"aa": 1, "b": 2, "a": 3})
        first = codec.encode(record)
        second = codec.encode(record)
        self.assertEqual(first, second)
        self.assertEqual(first[0], 0x8A)
        self.assertTrue(first.endswith(bytes.fromhex("a361610361620262616101")))

    def test_out_of_profile_values_are_rejected(self) -> None:
        invalid_records = [
            codec.Record(**{**valid_record().__dict__, "schema_version": 2}),
            codec.Record(**{**valid_record().__dict__, "ledger_id": bytes(15)}),
            codec.Record(**{**valid_record().__dict__, "sequence": 0}),
            codec.Record(**{**valid_record().__dict__, "event_type": ""}),
            codec.Record(
                **{
                    **valid_record().__dict__,
                    "occurred_at": codec.MAX_OCCURRED_AT + 1,
                }
            ),
            codec.Record(**{**valid_record().__dict__, "operator_id": ""}),
            codec.Record(**{**valid_record().__dict__, "payload": {"x": 1.5}}),
            codec.Record(**{**valid_record().__dict__, "payload": {"x": None}}),
            codec.Record(
                **{**valid_record().__dict__, "payload": {"x": b"bytes"}}
            ),
        ]
        for record in invalid_records:
            with self.subTest(record=record):
                with self.assertRaises(codec.CandidateCodecError):
                    codec.encode(record)

    def test_isolated_surrogate_is_rejected(self) -> None:
        record = codec.Record(
            **{**valid_record().__dict__, "payload": {"x": "\ud800"}}
        )
        with self.assertRaises(codec.CandidateCodecError):
            codec.encode(record)

    def test_record_above_raw_byte_limit_is_rejected(self) -> None:
        payload = {
            "a": "x" * codec.MAX_TEXT_BYTES,
            "b": "x" * codec.MAX_TEXT_BYTES,
            "c": "x" * codec.MAX_TEXT_BYTES,
            "d": "x" * codec.MAX_TEXT_BYTES,
        }
        record = codec.Record(
            **{
                **valid_record().__dict__,
                "payload": payload,
            }
        )

        with self.assertRaisesRegex(
            codec.CandidateCodecError,
            "maximum",
        ):
            codec.encode(record)

    def assert_encoding_outcome(
        self,
        record: codec.Record,
        want_error: bool,
    ) -> None:
        if want_error:
            with self.assertRaises(codec.CandidateCodecError):
                codec.encode(record)
        else:
            self.assertTrue(codec.encode(record))

    def test_payload_boundary_pairs(self) -> None:
        cases = [
            (
                "structural depth 9",
                {"value": nested_arrays(7)},
                False,
            ),
            (
                "structural depth 10",
                {"value": nested_arrays(8)},
                True,
            ),
            (
                "array 256 elements",
                {"value": [0] * 256},
                False,
            ),
            (
                "array 257 elements",
                {"value": [0] * 257},
                True,
            ),
            (
                "map 256 pairs",
                {f"k{index}": 0 for index in range(256)},
                False,
            ),
            (
                "map 257 pairs",
                {f"k{index}": 0 for index in range(257)},
                True,
            ),
            (
                "text 16384 UTF-8 bytes",
                {"value": "x" * codec.MAX_TEXT_BYTES},
                False,
            ),
            (
                "text 16385 UTF-8 bytes",
                {"value": "x" * (codec.MAX_TEXT_BYTES + 1)},
                True,
            ),
            (
                "key 128 UTF-8 bytes",
                {"k" * 128: 0},
                False,
            ),
            (
                "key 129 UTF-8 bytes",
                {"k" * 129: 0},
                True,
            ),
        ]

        for name, payload, want_error in cases:
            with self.subTest(name=name):
                record = codec.Record(
                    **{
                        **valid_record().__dict__,
                        "payload": payload,
                    }
                )
                self.assert_encoding_outcome(record, want_error)

    def test_outer_field_boundary_pairs(self) -> None:
        cases = [
            ("sequence 1", {"sequence": 1}, False),
            ("sequence 2^63-1", {"sequence": codec.INT64_MAX}, False),
            ("sequence 0", {"sequence": 0}, True),
            ("sequence 2^63", {"sequence": 1 << 63}, True),
            ("occurred_at 0", {"occurred_at": 0}, False),
            (
                "occurred_at maximum",
                {"occurred_at": codec.MAX_OCCURRED_AT},
                False,
            ),
            (
                "occurred_at maximum plus one",
                {"occurred_at": codec.MAX_OCCURRED_AT + 1},
                True,
            ),
            ("event_type 1 byte", {"event_type": "x"}, False),
            (
                "event_type 64 bytes",
                {"event_type": "x" * 64},
                False,
            ),
            ("event_type empty", {"event_type": ""}, True),
            (
                "event_type 65 bytes",
                {"event_type": "x" * 65},
                True,
            ),
            ("operator_id 1 byte", {"operator_id": "x"}, False),
            (
                "operator_id 128 bytes",
                {"operator_id": "x" * 128},
                False,
            ),
            ("operator_id empty", {"operator_id": ""}, True),
            (
                "operator_id 129 bytes",
                {"operator_id": "x" * 129},
                True,
            ),
        ]

        for name, changes, want_error in cases:
            with self.subTest(name=name):
                record = codec.Record(
                    **{
                        **valid_record().__dict__,
                        **changes,
                    }
                )
                self.assert_encoding_outcome(record, want_error)

    def test_total_encoded_size_boundary_pair(self) -> None:
        exact = record_with_encoded_size(self, codec.MAX_RECORD_BYTES)
        encoded = codec.encode(exact)
        self.assertEqual(len(encoded), codec.MAX_RECORD_BYTES)

        oversized_payload = dict(exact.payload)
        oversized_payload["d"] += "x"
        oversized = codec.Record(
            **{
                **valid_record().__dict__,
                "payload": oversized_payload,
            }
        )
        self.assertEqual(
            codec._encoded_size(logical_outer_for_test(oversized)),
            codec.MAX_RECORD_BYTES + 1,
        )
        with self.assertRaises(codec.CandidateCodecError):
            codec.encode(oversized)


class FixtureTests(unittest.TestCase):
    def test_duplicate_json_keys_are_rejected(self) -> None:
        with self.assertRaisesRegex(
            codec.CandidateCodecError, "duplicate JSON object key"
        ):
            codec.decode_fixture('{"x":1,"x":2}')

    def test_logical_transport_is_accepted(self) -> None:
        fixture = codec.decode_fixture(
            """
            {
              "artifact_status":"CANDIDATO NO NORMATIVO",
              "profile":"PT2-CBOR-AUTH-RECORD-CANDIDATE-v1",
              "case_id":"unit",
              "record":{
                "domain":"PT2:MEC-A1:HMAC-SHA-256:RECORD:v1",
                "schema_version":1,
                "mechanism_version":1,
                "ledger_id_hex":"000102030405060708090a0b0c0d0e0f",
                "sequence":1,
                "event_type":"x",
                "occurred_at":0,
                "operator_id":"x",
                "amount_cents":-1,
                "payload":{"ok":true,"values":[-1,0,1]}
              }
            }
            """
        )
        self.assertEqual(fixture.case_id, "unit")
        self.assertEqual(len(fixture.record.ledger_id), 16)
        self.assertTrue(codec.encode(fixture.record))


if __name__ == "__main__":
    unittest.main()
