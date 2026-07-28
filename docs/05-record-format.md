---
document_id: PT2-DOC-05
title: Record Format
version: 0.2.0
status: PROVISIONAL
approved_by: PENDING
---

# Formato de registro

## 1. Payload lógico

El payload transaccional contiene:

| Campo | Tipo | Obligatorio |
|---|---|---:|
| `event_type` | cadena enumerada | Sí |
| `occurred_at` | instante UTC | Sí |
| `operator_id` | cadena | Sí |
| `amount_cents` | entero de 64 bits | Condicional |
| `payload` | objeto estructurado | Sí |

## 2. Metadatos del sobre

| Campo | Tipo |
|---|---|
| `schema_version` | entero |
| `ledger_id` | UUID o identificador normativo |
| `sequence` | entero positivo de 64 bits |
| `mechanism_version` | entero |

## 3. Canonicalización

`canonicalPayload` es la representación determinista del payload lógico.

Debe definirse:

- UTF-8;
- nombres de campos;
- orden;
- representación de enteros;
- representación temporal;
- tratamiento de nulos;
- normalización Unicode;
- rechazo de números en coma flotante;
- estructura de objetos y listas.

## 4. Entrada autenticada

La entrada autenticada se construye mediante una codificación inequívoca:

`encode(domain, mechanism_version, ledger_id, sequence, canonicalPayload)`

No se permite concatenar cadenas sin longitudes o tipos explícitos.

## 5. Decisiones pendientes

- formato binario exacto;
- normalización Unicode;
- estructura cerrada o extensible de `payload`;
- límites máximos de tamaño.
