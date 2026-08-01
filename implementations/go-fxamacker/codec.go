// Package candidatecodec implements a positive-only reference producer for
// PT2-CBOR-AUTH-RECORD-CANDIDATE-v1.
//
// All bytes produced by this package are CANDIDATO NO NORMATIVO.
package candidatecodec

import (
	"fmt"
	"unicode/utf8"

	"github.com/fxamacker/cbor/v2"
)

const (
	ArtifactStatus = "CANDIDATO NO NORMATIVO"
	ProfileID      = "PT2-CBOR-AUTH-RECORD-CANDIDATE-v1"
	Domain         = "PT2:MEC-A1:HMAC-SHA-256:RECORD:v1"

	maxInt63          = uint64(1<<63 - 1)
	maxOccurredAt     = uint64(253402300799999)
	maxRecordBytes    = 65536
	maxContainerItems = 256
	maxTextBytes      = 16384
	maxDepth          = 9
)

// Record is the logical input to the candidate encoder. Payload values are
// restricted to string, int64, bool, []any, and map[string]any.
type Record struct {
	SchemaVersion    uint64
	MechanismVersion uint64
	LedgerID         []byte
	Sequence         uint64
	EventType        string
	OccurredAt       uint64
	OperatorID       string
	AmountCents      int64
	Payload          map[string]any
}

// Encode validates a logical record and serializes the candidate ten-element
// array using fxamacker's Core Deterministic mode. It does not compute a tag,
// HMAC, key identifier, or sequence context.
func Encode(record Record) ([]byte, error) {
	if err := validateRecord(record); err != nil {
		return nil, err
	}

	opts := cbor.CoreDetEncOptions()
	opts.Sort = cbor.SortCoreDeterministic
	opts.IndefLength = cbor.IndefLengthForbidden
	opts.TagsMd = cbor.TagsForbidden
	mode, err := opts.EncMode()
	if err != nil {
		return nil, fmt.Errorf("configure fxamacker encoder: %w", err)
	}

	outer := []any{
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
	candidateSize, err := encodedSize(outer)
	if err != nil {
		return nil, fmt.Errorf("size candidate record: %w", err)
	}
	if candidateSize > maxRecordBytes {
		return nil, fmt.Errorf("candidate record is %d bytes; maximum is %d", candidateSize, maxRecordBytes)
	}

	encoded, err := mode.Marshal(outer)
	if err != nil {
		return nil, fmt.Errorf("encode candidate record: %w", err)
	}
	if len(encoded) > maxRecordBytes {
		return nil, fmt.Errorf("candidate record is %d bytes; maximum is %d", len(encoded), maxRecordBytes)
	}
	if len(encoded) != candidateSize {
		return nil, fmt.Errorf("fxamacker encoded %d bytes; validated size was %d", len(encoded), candidateSize)
	}
	return encoded, nil
}

func validateRecord(record Record) error {
	if record.SchemaVersion != 1 {
		return fmt.Errorf("schema_version must be 1 for %s", ProfileID)
	}
	if record.MechanismVersion != 1 {
		return fmt.Errorf("mechanism_version must be 1 for %s", ProfileID)
	}
	if len(record.LedgerID) != 16 {
		return fmt.Errorf("ledger_id must contain exactly 16 bytes")
	}
	if record.Sequence < 1 || record.Sequence > maxInt63 {
		return fmt.Errorf("sequence must be in 1..2^63-1")
	}
	if err := validateBoundedText("event_type", record.EventType, 1, 64); err != nil {
		return err
	}
	if record.OccurredAt > maxOccurredAt {
		return fmt.Errorf("occurred_at must be in 0..%d", maxOccurredAt)
	}
	if err := validateBoundedText("operator_id", record.OperatorID, 1, 128); err != nil {
		return err
	}
	if record.Payload == nil {
		return fmt.Errorf("payload must be a non-nil map")
	}
	return validatePayload(record.Payload, 2)
}

func validateBoundedText(name, value string, minimum, maximum int) error {
	if !utf8.ValidString(value) {
		return fmt.Errorf("%s must contain valid Unicode scalar values", name)
	}
	size := len([]byte(value))
	if size < minimum || size > maximum {
		return fmt.Errorf("%s UTF-8 length must be in %d..%d bytes", name, minimum, maximum)
	}
	return nil
}

func validatePayload(value any, depth int) error {
	switch typed := value.(type) {
	case string:
		if !utf8.ValidString(typed) {
			return fmt.Errorf("payload text must contain valid Unicode scalar values")
		}
		if len([]byte(typed)) > maxTextBytes {
			return fmt.Errorf("payload text exceeds %d UTF-8 bytes", maxTextBytes)
		}
		return nil
	case int64:
		return nil
	case bool:
		return nil
	case []any:
		if typed == nil {
			return fmt.Errorf("payload arrays must be non-nil")
		}
		if depth > maxDepth {
			return fmt.Errorf("payload exceeds structural depth %d", maxDepth)
		}
		if len(typed) > maxContainerItems {
			return fmt.Errorf("payload array exceeds %d elements", maxContainerItems)
		}
		for index, item := range typed {
			if err := validatePayload(item, depth+1); err != nil {
				return fmt.Errorf("payload array index %d: %w", index, err)
			}
		}
		return nil
	case map[string]any:
		if typed == nil {
			return fmt.Errorf("payload maps must be non-nil")
		}
		if depth > maxDepth {
			return fmt.Errorf("payload exceeds structural depth %d", maxDepth)
		}
		if len(typed) > maxContainerItems {
			return fmt.Errorf("payload map exceeds %d pairs", maxContainerItems)
		}
		for key, item := range typed {
			if err := validateBoundedText("payload map key", key, 1, 128); err != nil {
				return err
			}
			if err := validatePayload(item, depth+1); err != nil {
				return fmt.Errorf("payload key %q: %w", key, err)
			}
		}
		return nil
	default:
		return fmt.Errorf("payload contains prohibited Go type %T", value)
	}
}

func encodedSize(value any) (int, error) {
	switch typed := value.(type) {
	case bool:
		return 1, nil
	case int64:
		if typed >= 0 {
			return headSize(uint64(typed)), nil
		}
		return headSize(uint64(-1 - typed)), nil
	case uint64:
		return headSize(typed), nil
	case string:
		return headSize(uint64(len([]byte(typed)))) + len([]byte(typed)), nil
	case []byte:
		return headSize(uint64(len(typed))) + len(typed), nil
	case []any:
		total := headSize(uint64(len(typed)))
		for _, item := range typed {
			size, err := encodedSize(item)
			if err != nil {
				return 0, err
			}
			total += size
			if total > maxRecordBytes {
				return total, nil
			}
		}
		return total, nil
	case map[string]any:
		total := headSize(uint64(len(typed)))
		for key, item := range typed {
			keySize, err := encodedSize(key)
			if err != nil {
				return 0, err
			}
			itemSize, err := encodedSize(item)
			if err != nil {
				return 0, err
			}
			total += keySize + itemSize
			if total > maxRecordBytes {
				return total, nil
			}
		}
		return total, nil
	default:
		return 0, fmt.Errorf("unsupported validated type %T", value)
	}
}

func headSize(argument uint64) int {
	switch {
	case argument < 24:
		return 1
	case argument <= 0xff:
		return 2
	case argument <= 0xffff:
		return 3
	case argument <= 0xffff_ffff:
		return 5
	default:
		return 9
	}
}
