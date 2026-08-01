# ADR-001 candidate codec interoperability

> **CANDIDATO NO NORMATIVO**

This directory contains experimental reference producers for
`PT2-CBOR-AUTH-RECORD-CANDIDATE-v1`.

The artifacts in this directory:

- do not approve ADR-001;
- do not define normative authenticated bytes;
- do not implement MEC-A1;
- do not calculate or verify HMAC;
- do not resolve keys;
- do not validate sequential context;
- do not authorize productive integration;
- do not constitute the complete twenty-vector suite.

The Go and Python producers must remain implementation-independent.
They may share logical fixtures, but they must not share CBOR encoding code.

Any byte mismatch is a blocking experimental finding. A mismatch must not be
resolved by silently selecting one producer as authoritative.

## Fixture transport

The shared JSON files are logical test transport only.

`ledger_id_hex` is a lowercase hexadecimal representation used by the seed
fixtures to transport exactly 16 opaque octets. It does not define a normative
UUID, textual, SQLite, or network representation.

The producers validate only the candidate encoding profile. Values such as
`event_type` and names inside `payload` are not evidence of acceptance by a
future application schema.

## Reproduction

Run the local checks from the repository root:

```text
(cd implementations/go-fxamacker && go test -count=1 ./...)
(cd implementations/go-fxamacker && go vet ./...)
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s implementations/python-manual \
  -p 'test_*.py' \
  -v
scripts/check_candidate_codec_interop.sh
```

The interoperability script records the source commit, working-tree state,
toolchain versions and pinned Go dependency before comparing the two producers.

Printed hexadecimal remains transient candidate evidence. It is not an approved
vector, a stable contract or the complete twenty-vector suite.
