---
document_id: PT2-DOC-05
title: Record Format
version: 0.2.1
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
| `amount_cents` | entero con signo de 64 bits | Sí |
| `payload` | objeto estructurado | Sí |

Para `schema_version = 1`, todos los registros del benchmark deben representar
eventos con importe monetario. `amount_cents` es obligatorio, no admite `null`
y no se representa mediante números de coma flotante.

Los eventos sin importe monetario quedan fuera del esquema v1. Su incorporación
requerirá una nueva versión del esquema.

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

`encode(domain, schema_version, mechanism_version, ledger_id, sequence, canonicalPayload)`

No se permite concatenar cadenas sin longitudes o tipos explícitos.

`schema_version` debe formar parte del mensaje autenticado porque puede afectar
la interpretación y validación del payload.

### 4.1. Separación de dominio

`domain` no puede elegirse libremente durante la ejecución.

Cada mecanismo debe definir en `docs/06-mechanism-specifications.md`:

- el literal normativo exacto;
- su codificación;
- el tratamiento de terminadores;
- su relación con la versión del mecanismo.

## 5. Decisiones pendientes

- formato binario exacto;
- normalización Unicode;
- estructura cerrada o extensible de `payload`;
- límites máximos de tamaño.
