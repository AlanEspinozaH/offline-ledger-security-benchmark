---
document_id: PT2-DOC-04
title: Threat Model
version: 0.2.1
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
- identificadores de claves y parámetros públicos;
- contenedores cifrados de claves tratados como bytes opacos restaurables.

### Fuera del dominio local restaurable

- estado del anclaje externo;
- copia confiable de la clave pública conocida independientemente;
- evidencia externa aceptada conforme al protocolo;
- secreto de desbloqueo de cualquier contenedor cifrado, cuando sea requerido.

### Fuera de la capacidad de THR-P1

El adversario no puede:

- obtener la clave HMAC activa;
- obtener la clave privada Ed25519 activa;
- acceder a claves activas en la memoria del proceso legítimo;
- modificar el estado del anclaje externo;
- modificar la copia confiable de la clave pública;
- falsificar un HMAC o una firma válida sin poseer la clave correspondiente.

## THR-P1 — Escritura arbitraria offline sin secretos

### Estado

PROVISIONAL

### Punto de actuación

El adversario actúa cuando la aplicación legítima se encuentra detenida.

### Capacidades

Puede:

- leer todos los archivos del dominio local restaurable;
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

Un escenario que almacene una clave HMAC o una clave privada Ed25519
en texto claro dentro del dominio local legible no satisface `THR-P1`.

El atacante puede copiar y restaurar contenedores cifrados, pero no
recibe el secreto de desbloqueo ni acceso a claves activas en memoria.

Este modelo define la frontera necesaria para el experimento y no una
solución productiva definitiva de gestión de claves.

### Estado confiable disponible al verificador

El estado confiable dependerá del escenario:

- ninguno;
- clave HMAC válida obtenida mediante un proveedor fuera de la capacidad de `THR-P1`;
- secuencia terminal esperada;
- copia confiable de la clave pública;
- último checkpoint anclado.

### Relación con ataques

Las operaciones concretas se definen mediante identificadores `ATT-*` en `docs/09-attack-catalog.md`.
