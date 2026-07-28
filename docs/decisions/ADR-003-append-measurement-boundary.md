---
decision_id: ADR-003
title: Append measurement boundary
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-003 — Frontera de medición del append

## Contexto

`MET-APPEND-READY-E2E` no define completamente la transacción ni los fallos.

## Decisiones pendientes

- posición de `BEGIN`;
- final temporal ante excepción;
- inclusión o exclusión de `ROLLBACK`;
- tratamiento de cierre y limpieza;
- campos estructurados de una operación fallida.

## Recomendación técnica

Iniciar sin transacción activa, incluir su establecimiento, terminar al
retornar `COMMIT` o al observar el fallo terminal, y excluir rollback y limpieza.

## Decisión del investigador

PENDING

## Documentos afectados

- `docs/11-measurement-contract.md`

## Identificadores de trazabilidad

- `RQ-04`
- `MET-APPEND-READY-E2E`
