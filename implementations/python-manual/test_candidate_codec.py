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
