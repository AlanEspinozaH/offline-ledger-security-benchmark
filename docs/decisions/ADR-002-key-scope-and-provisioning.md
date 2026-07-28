---
decision_id: ADR-002
title: Key scope and provisioning
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-002 — Alcance y provisión de claves

## Contexto

`MEC-A1` requiere una clave HMAC, pero todavía no están definidos su alcance,
identificación, provisión ni política de rotación.

## Decisiones pendientes

- clave por ledger, dataset o ejecución;
- formato y unicidad de `key_id`;
- tamaño mínimo de clave;
- provisión al protector;
- provisión al verificador;
- inclusión o exclusión de rotación.

## Recomendación técnica

Mantener las claves activas fuera del dominio legible por `THR-P1` y excluir
su generación o carga de las regiones de medición preparadas.

## Decisión del investigador

PENDING

## Documentos afectados

- `docs/04-threat-model.md`
- `docs/06-mechanism-specifications.md`

## Identificadores de trazabilidad

- `MEC-A1`
- `THR-P1`
