package candidatecodec

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"unicode/utf8"
)

// Fixture is the shared logical transport used only by the seed experiment.
type Fixture struct {
	CaseID string
	Record Record
}

// LoadFixture reads a positive logical fixture. It rejects duplicate JSON map
// keys before constructing Go maps, but it does not parse CBOR bytes.
func LoadFixture(path string) (Fixture, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Fixture{}, fmt.Errorf("read fixture: %w", err)
	}
	return DecodeFixture(data)
}

// DecodeFixture decodes the JSON transport shared by the two producers.
func DecodeFixture(data []byte) (Fixture, error) {
	decoder := json.NewDecoder(bytes.NewReader(data))
	if err := validateFixtureUnicode(data); err != nil {
		return Fixture{}, err
	}
	decoder.UseNumber()
	rootValue, err := decodeJSONValue(decoder)
	if err != nil {
		return Fixture{}, fmt.Errorf("decode fixture JSON: %w", err)
	}
	if token, trailingErr := decoder.Token(); trailingErr != io.EOF {
		if trailingErr != nil {
			return Fixture{}, fmt.Errorf("decode trailing JSON: %w", trailingErr)
		}
		return Fixture{}, fmt.Errorf("fixture contains trailing JSON token %v", token)
	}

	root, err := requireObject(rootValue, "fixture")
	if err != nil {
		return Fixture{}, err
	}
	if err := requireExactKeys(root, "fixture", "artifact_status", "profile", "case_id", "record"); err != nil {
		return Fixture{}, err
	}
	status, err := requireString(root["artifact_status"], "artifact_status")
	if err != nil {
		return Fixture{}, err
	}
	if status != ArtifactStatus {
		return Fixture{}, fmt.Errorf("artifact_status must be %q", ArtifactStatus)
	}
	profile, err := requireString(root["profile"], "profile")
	if err != nil {
		return Fixture{}, err
	}
	if profile != ProfileID {
		return Fixture{}, fmt.Errorf("profile must be %q", ProfileID)
	}
	caseID, err := requireString(root["case_id"], "case_id")
	if err != nil {
		return Fixture{}, err
	}
	if caseID == "" {
		return Fixture{}, fmt.Errorf("case_id must not be empty")
	}

	recordObject, err := requireObject(root["record"], "record")
	if err != nil {
		return Fixture{}, err
	}
	if err := requireExactKeys(recordObject, "record", "domain", "schema_version", "mechanism_version", "ledger_id_hex", "sequence", "event_type", "occurred_at", "operator_id", "amount_cents", "payload"); err != nil {
		return Fixture{}, err
	}
	domain, err := requireString(recordObject["domain"], "domain")
	if err != nil {
		return Fixture{}, err
	}
	if domain != Domain {
		return Fixture{}, fmt.Errorf("domain must be %q", Domain)
	}
	schemaVersion, err := requireNonnegativeInteger(recordObject["schema_version"], "schema_version")
	if err != nil {
		return Fixture{}, err
	}
	mechanismVersion, err := requireNonnegativeInteger(recordObject["mechanism_version"], "mechanism_version")
	if err != nil {
		return Fixture{}, err
	}
	ledgerHex, err := requireString(recordObject["ledger_id_hex"], "ledger_id_hex")
	if err != nil {
		return Fixture{}, err
	}
	ledgerID, err := decodeLedgerID(ledgerHex)
	if err != nil {
		return Fixture{}, err
	}
	sequence, err := requireNonnegativeInteger(recordObject["sequence"], "sequence")
	if err != nil {
		return Fixture{}, err
	}
	eventType, err := requireString(recordObject["event_type"], "event_type")
	if err != nil {
		return Fixture{}, err
	}
	occurredAt, err := requireNonnegativeInteger(recordObject["occurred_at"], "occurred_at")
	if err != nil {
		return Fixture{}, err
	}
	operatorID, err := requireString(recordObject["operator_id"], "operator_id")
	if err != nil {
		return Fixture{}, err
	}
	amountCents, err := requireInteger(recordObject["amount_cents"], "amount_cents")
	if err != nil {
		return Fixture{}, err
	}
	payloadObject, err := requireObject(recordObject["payload"], "payload")
	if err != nil {
		return Fixture{}, err
	}
	payload, err := convertPayload(payloadObject)
	if err != nil {
		return Fixture{}, err
	}

	fixture := Fixture{
		CaseID: caseID,
		Record: Record{
			SchemaVersion:    schemaVersion,
			MechanismVersion: mechanismVersion,
			LedgerID:         ledgerID,
			Sequence:         sequence,
			EventType:        eventType,
			OccurredAt:       occurredAt,
			OperatorID:       operatorID,
			AmountCents:      amountCents,
			Payload:          payload,
		},
	}
	if err := validateRecord(fixture.Record); err != nil {
		return Fixture{}, fmt.Errorf("invalid candidate fixture: %w", err)
	}
	return fixture, nil
}

func decodeJSONValue(decoder *json.Decoder) (any, error) {
	token, err := decoder.Token()
	if err != nil {
		return nil, err
	}
	delimiter, isDelimiter := token.(json.Delim)
	if !isDelimiter {
		return token, nil
	}
	switch delimiter {
	case '{':
		result := make(map[string]any)
		for decoder.More() {
			keyToken, err := decoder.Token()
			if err != nil {
				return nil, err
			}
			key, ok := keyToken.(string)
			if !ok {
				return nil, fmt.Errorf("JSON object key is not text")
			}
			if _, exists := result[key]; exists {
				return nil, fmt.Errorf("duplicate JSON object key %q", key)
			}
			value, err := decodeJSONValue(decoder)
			if err != nil {
				return nil, err
			}
			result[key] = value
		}
		closing, err := decoder.Token()
		if err != nil {
			return nil, err
		}
		if closing != json.Delim('}') {
			return nil, fmt.Errorf("object did not end with }")
		}
		return result, nil
	case '[':
		result := make([]any, 0)
		for decoder.More() {
			value, err := decodeJSONValue(decoder)
			if err != nil {
				return nil, err
			}
			result = append(result, value)
		}
		closing, err := decoder.Token()
		if err != nil {
			return nil, err
		}
		if closing != json.Delim(']') {
			return nil, fmt.Errorf("array did not end with ]")
		}
		return result, nil
	default:
		return nil, fmt.Errorf("unexpected JSON delimiter %q", delimiter)
	}
}

func requireExactKeys(object map[string]any, name string, expected ...string) error {
	if len(object) != len(expected) {
		return fmt.Errorf("%s must contain exactly %d fields", name, len(expected))
	}
	for _, key := range expected {
		if _, ok := object[key]; !ok {
			return fmt.Errorf("%s is missing field %q", name, key)
		}
	}
	return nil
}

func requireObject(value any, name string) (map[string]any, error) {
	object, ok := value.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("%s must be a JSON object", name)
	}
	return object, nil
}

func requireString(value any, name string) (string, error) {
	text, ok := value.(string)
	if !ok {
		return "", fmt.Errorf("%s must be a JSON string", name)
	}
	return text, nil
}

func requireInteger(value any, name string) (int64, error) {
	number, ok := value.(json.Number)
	if !ok {
		return 0, fmt.Errorf("%s must be a JSON integer", name)
	}
	integer, err := number.Int64()
	if err != nil {
		return 0, fmt.Errorf("%s must be an int64: %w", name, err)
	}
	return integer, nil
}

func requireNonnegativeInteger(value any, name string) (uint64, error) {
	integer, err := requireInteger(value, name)
	if err != nil {
		return 0, err
	}
	if integer < 0 {
		return 0, fmt.Errorf("%s must be nonnegative", name)
	}
	return uint64(integer), nil
}

func decodeLedgerID(value string) ([]byte, error) {
	if len(value) != 32 {
		return nil, fmt.Errorf("ledger_id_hex must contain exactly 32 lowercase hexadecimal characters")
	}
	for _, character := range value {
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f')) {
			return nil, fmt.Errorf("ledger_id_hex must contain exactly 32 lowercase hexadecimal characters")
		}
	}
	decoded, err := hex.DecodeString(value)
	if err != nil {
		return nil, fmt.Errorf("decode ledger_id_hex: %w", err)
	}
	return decoded, nil
}

func convertPayload(value any) (map[string]any, error) {
	converted, err := convertPayloadValue(value)
	if err != nil {
		return nil, err
	}
	object, ok := converted.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("payload must be a JSON object")
	}
	return object, nil
}

func convertPayloadValue(value any) (any, error) {
	switch typed := value.(type) {
	case string, bool:
		return typed, nil
	case json.Number:
		integer, err := typed.Int64()
		if err != nil {
			return nil, fmt.Errorf("payload numbers must be int64: %w", err)
		}
		return integer, nil
	case []any:
		converted := make([]any, len(typed))
		for index, item := range typed {
			value, err := convertPayloadValue(item)
			if err != nil {
				return nil, fmt.Errorf("payload array index %d: %w", index, err)
			}
			converted[index] = value
		}
		return converted, nil
	case map[string]any:
		converted := make(map[string]any, len(typed))
		for key, item := range typed {
			value, err := convertPayloadValue(item)
			if err != nil {
				return nil, fmt.Errorf("payload key %q: %w", key, err)
			}
			converted[key] = value
		}
		return converted, nil
	case nil:
		return nil, fmt.Errorf("payload null is prohibited")
	default:
		return nil, fmt.Errorf("payload contains prohibited JSON type %T", value)
	}
}

func validateFixtureUnicode(data []byte) error {
	if !utf8.Valid(data) {
		return fmt.Errorf("fixture JSON must be valid UTF-8")
	}
	inString := false
	for index := 0; index < len(data); {
		if !inString {
			if data[index] == '"' {
				inString = true
			}
			index++
			continue
		}
		switch data[index] {
		case '"':
			inString = false
			index++
		case '\\':
			if index+1 >= len(data) || data[index+1] != 'u' {
				index += 2
				continue
			}
			codeUnit, ok := parseHexQuad(data, index+2)
			if !ok {
				return fmt.Errorf("invalid JSON Unicode escape")
			}
			switch {
			case codeUnit >= 0xd800 && codeUnit <= 0xdbff:
				if index+12 > len(data) || data[index+6] != '\\' || data[index+7] != 'u' {
					return fmt.Errorf("isolated high Unicode surrogate in fixture JSON")
				}
				low, ok := parseHexQuad(data, index+8)
				if !ok || low < 0xdc00 || low > 0xdfff {
					return fmt.Errorf("high Unicode surrogate is not followed by a low surrogate")
				}
				index += 12
			case codeUnit >= 0xdc00 && codeUnit <= 0xdfff:
				return fmt.Errorf("isolated low Unicode surrogate in fixture JSON")
			default:
				index += 6
			}
		default:
			index++
		}
	}
	return nil
}

func parseHexQuad(data []byte, start int) (uint16, bool) {
	if start+4 > len(data) {
		return 0, false
	}
	var value uint16
	for _, character := range data[start : start+4] {
		value <<= 4
		switch {
		case character >= '0' && character <= '9':
			value |= uint16(character - '0')
		case character >= 'a' && character <= 'f':
			value |= uint16(character-'a') + 10
		case character >= 'A' && character <= 'F':
			value |= uint16(character-'A') + 10
		default:
			return 0, false
		}
	}
	return value, true
}
