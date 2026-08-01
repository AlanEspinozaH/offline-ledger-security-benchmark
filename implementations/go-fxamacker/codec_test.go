package candidatecodec

import (
	"bytes"
	"strconv"
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

func TestPayloadBoundaryPairs(t *testing.T) {
	tests := []struct {
		name      string
		payload   map[string]any
		wantError bool
	}{
		{"structural depth 9", map[string]any{"value": nestedArrays(7)}, false},
		{"structural depth 10", map[string]any{"value": nestedArrays(8)}, true},
		{"array 256 elements", map[string]any{"value": integerArray(256)}, false},
		{"array 257 elements", map[string]any{"value": integerArray(257)}, true},
		{"map 256 pairs", integerMap(256), false},
		{"map 257 pairs", integerMap(257), true},
		{"text 16384 UTF-8 bytes", map[string]any{"value": strings.Repeat("x", maxTextBytes)}, false},
		{"text 16385 UTF-8 bytes", map[string]any{"value": strings.Repeat("x", maxTextBytes+1)}, true},
		{"key 128 UTF-8 bytes", map[string]any{strings.Repeat("k", 128): int64(0)}, false},
		{"key 129 UTF-8 bytes", map[string]any{strings.Repeat("k", 129): int64(0)}, true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			record := validRecord()
			record.Payload = test.payload
			requireEncodingOutcome(t, record, test.wantError)
		})
	}
}

func TestOuterFieldBoundaryPairs(t *testing.T) {
	tests := []struct {
		name      string
		mutate    func(*Record)
		wantError bool
	}{
		{"sequence 1", func(record *Record) { record.Sequence = 1 }, false},
		{"sequence 2^63-1", func(record *Record) { record.Sequence = maxInt63 }, false},
		{"sequence 0", func(record *Record) { record.Sequence = 0 }, true},
		{"sequence 2^63", func(record *Record) { record.Sequence = uint64(1) << 63 }, true},
		{"occurred_at 0", func(record *Record) { record.OccurredAt = 0 }, false},
		{"occurred_at maximum", func(record *Record) { record.OccurredAt = maxOccurredAt }, false},
		{"occurred_at maximum plus one", func(record *Record) { record.OccurredAt = maxOccurredAt + 1 }, true},
		{"event_type 1 byte", func(record *Record) { record.EventType = "x" }, false},
		{"event_type 64 bytes", func(record *Record) { record.EventType = strings.Repeat("x", 64) }, false},
		{"event_type empty", func(record *Record) { record.EventType = "" }, true},
		{"event_type 65 bytes", func(record *Record) { record.EventType = strings.Repeat("x", 65) }, true},
		{"operator_id 1 byte", func(record *Record) { record.OperatorID = "x" }, false},
		{"operator_id 128 bytes", func(record *Record) { record.OperatorID = strings.Repeat("x", 128) }, false},
		{"operator_id empty", func(record *Record) { record.OperatorID = "" }, true},
		{"operator_id 129 bytes", func(record *Record) { record.OperatorID = strings.Repeat("x", 129) }, true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			record := validRecord()
			test.mutate(&record)
			requireEncodingOutcome(t, record, test.wantError)
		})
	}
}

func TestTotalEncodedSizeBoundaryPair(t *testing.T) {
	exact := recordWithEncodedSize(t, maxRecordBytes)
	encoded, err := Encode(exact)
	if err != nil {
		t.Fatalf("Encode(exact size) error = %v", err)
	}
	if len(encoded) != maxRecordBytes {
		t.Fatalf("Encode(exact size) length = %d, want %d", len(encoded), maxRecordBytes)
	}

	oversized := exact
	oversized.Payload = make(map[string]any, len(exact.Payload))
	for key, value := range exact.Payload {
		oversized.Payload[key] = value
	}
	oversized.Payload["d"] = oversized.Payload["d"].(string) + "x"

	size, err := encodedSize(logicalOuterForTest(oversized))
	if err != nil {
		t.Fatalf("encodedSize(oversized) error = %v", err)
	}
	if size != maxRecordBytes+1 {
		t.Fatalf("oversized logical record size = %d, want %d", size, maxRecordBytes+1)
	}
	if _, err := Encode(oversized); err == nil {
		t.Fatal("Encode(65537-byte record) error = nil, want rejection")
	}
}

func requireEncodingOutcome(t *testing.T, record Record, wantError bool) {
	t.Helper()

	_, err := Encode(record)
	if wantError && err == nil {
		t.Fatal("Encode() error = nil, want rejection")
	}
	if !wantError && err != nil {
		t.Fatalf("Encode() error = %v, want acceptance", err)
	}
}

func nestedArrays(count int) any {
	var value any = int64(0)
	for range count {
		value = []any{value}
	}
	return value
}

func integerArray(count int) []any {
	result := make([]any, count)
	for index := range result {
		result[index] = int64(0)
	}
	return result
}

func integerMap(count int) map[string]any {
	result := make(map[string]any, count)
	for index := range count {
		result["k"+strconv.Itoa(index)] = int64(0)
	}
	return result
}

func logicalOuterForTest(record Record) []any {
	return []any{
		Domain,
		record.SchemaVersion,
		record.MechanismVersion,
		record.LedgerID,
		record.Sequence,
		record.EventType,
		record.OccurredAt,
		record.OperatorID,
		record.AmountCents,
		record.Payload,
	}
}

func recordWithEncodedSize(t *testing.T, target int) Record {
	t.Helper()

	record := validRecord()
	fullText := strings.Repeat("x", maxTextBytes)
	record.Payload = map[string]any{
		"a": fullText,
		"b": fullText,
		"c": fullText,
		"d": "",
	}

	baseSize, err := encodedSize(logicalOuterForTest(record))
	if err != nil {
		t.Fatalf("encodedSize(base record) error = %v", err)
	}
	requiredDelta := target - baseSize

	for textLength := 0; textLength <= maxTextBytes; textLength++ {
		encodedTextDelta := headSize(uint64(textLength)) + textLength - headSize(0)
		if encodedTextDelta != requiredDelta {
			continue
		}
		record.Payload["d"] = strings.Repeat("x", textLength)
		size, err := encodedSize(logicalOuterForTest(record))
		if err != nil {
			t.Fatalf("encodedSize(target record) error = %v", err)
		}
		if size != target {
			t.Fatalf("constructed record size = %d, want %d", size, target)
		}
		return record
	}

	t.Fatalf("unable to construct candidate record of %d bytes", target)
	return Record{}
}
