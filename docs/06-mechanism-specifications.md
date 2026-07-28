---
document_id: PT2-DOC-06
title: Mechanism Specifications
version: 0.2.0
status: PROVISIONAL
approved_by: PENDING
---

# Especificaciones de mecanismos

## MEC-A1 — HMAC por registro

### Estado

PROVISIONAL

### Primitiva

HMAC-SHA-256.

### Entrada lógica

- `ledger_id`;
- `sequence`;
- `canonical_payload`;
- `mechanism_version`;
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

Estado: pendiente de decisión.

Deben definirse como mínimo:

- alcance de cada clave;
- identificación mediante `key_id`;
- provisión al mecanismo;
- provisión al verificador;
- exclusión o inclusión de rotación.
