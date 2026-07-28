---
decision_id: ADR-001
title: Authenticated encoding v1
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-001 — Codificación autenticada v1

## Contexto

`MEC-A1` depende de una representación común e inequívoca del registro.

## Decisiones pendientes

- codificación binaria exacta;
- literal y bytes de separación de dominio;
- nombre normativo de `canonical_payload`;
- semántica de `INVALID_SEQUENCE_CONTEXT`;
- relación entre secuencia explícita y continuidad.

## Recomendación técnica

Usar campos tipados y delimitados, autenticar `schema_version` y evitar
concatenaciones informales.

## Decisión del investigador

PENDING

## Documentos afectados

- `docs/05-record-format.md`
- `docs/06-mechanism-specifications.md`

## Identificadores de trazabilidad

- `RQ-01`
- `MEC-A1`
- `THR-P1`
