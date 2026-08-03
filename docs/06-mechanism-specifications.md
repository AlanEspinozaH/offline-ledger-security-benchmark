---
document_id: PT2-DOC-06
title: Mechanism Specifications
version: 0.2.2
status: PROVISIONAL
approved_by: PENDING
---

# Especificaciones de mecanismos

## MEC-A1 — HMAC por registro

### Estado

PROVISIONAL

### Estado de implementación

`BLOCKED`

La implementación permanece bloqueada por:

- `ADR-001`: codificación autenticada y semántica de secuencia;
- ausencia de una tarea de implementación autorizada.

### Primitiva

HMAC-SHA-256.

### Entrada lógica

- `schema_version`;
- `mechanism_version`;
- `ledger_id`;
- `sequence`;
- `canonical_payload`;
- clave secreta asociada al ledger.

### Mensaje autenticado

El mensaje se obtiene exclusivamente mediante la función normativa definida en `docs/05-record-format.md`.

No se permite construir el mensaje mediante concatenación informal de cadenas.

### Salida

- `tag`;
- `key_id`;
- versión del mecanismo.

### Verificación

La verificación debe producir uno de estos estados estructurados:

- `VALID`;
- `MALFORMED_RECORD`;
- `UNSUPPORTED_VERSION`;
- `UNKNOWN_KEY`;
- `INVALID_TAG`;
- `INVALID_SEQUENCE_CONTEXT`.

### Supuestos

- la clave permanece secreta;
- la clave correcta está disponible para el verificador;
- el algoritmo y la versión son conocidos;
- la representación canónica es idéntica en producción y verificación.

### Garantía esperada

Autenticidad individual del mensaje autenticado frente a un adversario que no posee la clave.

### No garantiza por sí sola

- confidencialidad;
- detección de rollback completo;
- conocimiento de la secuencia terminal vigente;
- verificabilidad mediante una clave pública;
- seguridad después del compromiso de la clave.

### Gestión de claves

Estado de política científica: `APPROVED` por `ADR-002` v0.3.0.

La implementación de esta política permanece pendiente de una tarea autorizada.

ADR-002 v0.3.0 establece:

- una clave HMAC independiente por instancia lógica de ledger;
- una asociación nueva por cada unidad experimental completa de `MEC-A1`;
- clave opaca de 32 octetos;
- `key_id` opaco y no secreto de 16 octetos;
- provisión y continuidad exclusivamente en memoria autorizada, sin
  persistencia;
- rotación fuera de alcance.

La topología o API del proveedor, el schema y la implementación concreta no
quedan definidos por esta especificación provisional.
