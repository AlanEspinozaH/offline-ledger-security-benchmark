package candidatecodec

import (
	"bytes"
	"strings"
	"testing"
)

func validRecord() Record {
	return Record{
		SchemaVersion:    1,
		MechanismVersion: 1,
		LedgerID:         make([]byte, 16),
		Sequence:         1,
		EventType:        "x",
		OccurredAt:       0,
		OperatorID:       "x",
		AmountCents:      0,
		Payload:          map[string]any{},
	}
}

func TestEncodeUsesTenElementArrayAndIsRepeatable(t *testing.T) {
	record := validRecord()
	record.Payload["aa"] = int64(1)
	record.Payload["b"] = int64(2)
	record.Payload["a"] = int64(3)

	first, err := Encode(record)
	if err != nil {
		t.Fatalf("Encode() error = %v", err)
	}
	second, err := Encode(record)
	if err != nil {
		t.Fatalf("second Encode() error = %v", err)
	}
	if !bytes.Equal(first, second) {
		t.Fatal("repeated encoding produced different bytes")
	}
	if first[0] != 0x8a {
		t.Fatalf("outer initial byte = 0x%02x, want 0x8a", first[0])
	}
}

func TestEncodeRejectsOutOfProfileLogicalValues(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(*Record)
	}{
		{"unsupported schema version", func(record *Record) { record.SchemaVersion = 2 }},
		{"short ledger id", func(record *Record) { record.LedgerID = make([]byte, 15) }},
		{"zero sequence", func(record *Record) { record.Sequence = 0 }},
		{"empty event type", func(record *Record) { record.EventType = "" }},
		{"late timestamp", func(record *Record) { record.OccurredAt = maxOccurredAt + 1 }},
		{"empty operator", func(record *Record) { record.OperatorID = "" }},
		{"nil payload", func(record *Record) { record.Payload = nil }},
		{"float payload", func(record *Record) { record.Payload["value"] = 1.5 }},
		{"null-like payload", func(record *Record) { record.Payload["value"] = nil }},
		{"byte string payload", func(record *Record) { record.Payload["value"] = []byte{1} }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			record := validRecord()
			test.mutate(&record)
			if _, err := Encode(record); err == nil {
				t.Fatal("Encode() error = nil, want rejection")
			}
		})
	}
}

func TestDecodeFixtureRejectsDuplicateJSONKeys(t *testing.T) {
	_, err := DecodeFixture([]byte(`{"x":1,"x":2}`))
	if err == nil || !strings.Contains(err.Error(), "duplicate JSON object key") {
		t.Fatalf("DecodeFixture() error = %v, want duplicate-key rejection", err)
	}
}

func TestDecodeFixtureAcceptsLogicalTransport(t *testing.T) {
	data := []byte(`{
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
	}`)
	fixture, err := DecodeFixture(data)
	if err != nil {
		t.Fatalf("DecodeFixture() error = %v", err)
	}
	if fixture.CaseID != "unit" || len(fixture.Record.LedgerID) != 16 {
		t.Fatalf("unexpected fixture: %+v", fixture)
	}
	if _, err := Encode(fixture.Record); err != nil {
		t.Fatalf("Encode(decoded fixture) error = %v", err)
	}
}

func TestDecodeFixtureRejectsInvalidUnicodeTransport(t *testing.T) {
	_, err := DecodeFixture([]byte(`{"x":"\ud800"}`))
	if err == nil || !strings.Contains(err.Error(), "Unicode surrogate") {
		t.Fatalf("DecodeFixture() error = %v, want surrogate rejection", err)
	}

	_, err = DecodeFixture([]byte{0xff})
	if err == nil || !strings.Contains(err.Error(), "valid UTF-8") {
		t.Fatalf("DecodeFixture(invalid UTF-8) error = %v, want UTF-8 rejection", err)
	}
}

func TestEncodeRejectsRecordAboveRawByteLimit(t *testing.T) {
	record := validRecord()
	value := strings.Repeat("x", maxTextBytes)
	record.Payload = map[string]any{
		"a": value,
		"b": value,
		"c": value,
		"d": value,
	}
	if _, err := Encode(record); err == nil || !strings.Contains(err.Error(), "maximum") {
		t.Fatalf("Encode(oversized record) error = %v, want size rejection", err)
	}
}
