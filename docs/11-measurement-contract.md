---
document_id: PT2-DOC-11
title: Measurement Contract
version: 0.2.0
status: PROVISIONAL
approved_by: PENDING
---

# Contrato de medición

## MET-APPEND-READY-E2E

### Propósito

Medir la latencia de una inserción individual cuando el entorno ya fue preparado.

No mide exclusivamente el costo de la primitiva criptográfica.

### Inicio

El temporizador comienza cuando:

- la conexión ya está abierta;
- el esquema ya existe;
- las claves requeridas ya están cargadas;
- los pragmas ya fueron aplicados;
- el objeto transaccional ya existe;
- no ha comenzado aún la canonicalización del registro medido.

### Fin

El temporizador finaliza después del retorno exitoso del `COMMIT`.

### Incluye

- canonicalización;
- construcción del mensaje autenticado;
- cálculo del mecanismo;
- preparación de parámetros;
- `INSERT`;
- `COMMIT`.

### Excluye

- creación del esquema;
- apertura de base;
- generación de claves;
- derivación de claves;
- carga del keystore;
- generación del dataset;
- exportación de evidencia;
- análisis.

### Condiciones que deben congelarse

- `journal_mode`;
- `synchronous`;
- política de transacción;
- política WAL;
- tamaño de página;
- filesystem;
- hardware;
- versión de JVM;
- versión del driver SQLite.

### Reloj

Se debe utilizar un reloj monotónico.

Los valores crudos se almacenan en nanosegundos.

### Fallos

Las operaciones fallidas no se eliminan silenciosamente. Deben producir:

- estado;
- tipo de fallo;
- duración observada;
- decisión posterior de inclusión o exclusión.
