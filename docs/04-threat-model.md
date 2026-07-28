---
document_id: PT2-DOC-04
title: Threat Model
version: 0.2.0
status: PROVISIONAL
approved_by: PENDING
---

# Modelo de amenaza

## Frontera de confianza

### Dentro del dominio local restaurable

- archivo SQLite principal;
- archivos `-wal` y `-shm`;
- configuración local;
- checkpoints locales;
- manifiestos locales;
- material de claves local, cuando el escenario lo indique.

### Fuera del dominio local restaurable

- estado del anclaje externo;
- clave pública conocida independientemente por el verificador;
- evidencia externa aceptada conforme al protocolo.

## THR-P1 — Escritura arbitraria offline sin secretos

### Estado

PROVISIONAL

### Punto de actuación

El adversario actúa cuando la aplicación legítima se encuentra detenida.

### Capacidades

Puede:

- leer archivos locales;
- sustituir archivos locales;
- modificar el contenido lógico de SQLite;
- reconstruir campos públicos;
- recalcular funciones hash públicas;
- restaurar un snapshot local completo.

### Limitaciones

No puede:

- obtener la clave HMAC;
- obtener la clave privada Ed25519;
- modificar el estado del anclaje externo;
- falsificar una firma válida;
- actuar concurrentemente con el proceso legítimo;
- modificar el código del verificador.

### Estado confiable disponible al verificador

El estado confiable dependerá del escenario:

- ninguno;
- secuencia terminal esperada;
- clave pública;
- último checkpoint anclado.

### Relación con ataques

Las operaciones concretas se definen mediante identificadores `ATT-*` en `docs/09-attack-catalog.md`.