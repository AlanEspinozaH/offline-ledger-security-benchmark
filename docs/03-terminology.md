---
document_id: PT2-DOC-03
title: Terminology
version: 0.1.0
status: DRAFT
approved_by: PENDING
---

# Terminología normativa

## Registro transaccional

Representación lógica versionada de un evento incluido en la bitácora.

## Payload canónico

Representación determinista de los datos del evento que no incluye necesariamente los metadatos externos del sobre criptográfico.

## Sobre autenticado

Estructura que incluye los campos utilizados por un mecanismo para producir o verificar un autenticador.

## Bitácora

Secuencia ordenada de registros transaccionales identificada por un `ledger_id`.

## Secuencia

Entero monotónico asignado dentro de una bitácora.

## Autenticación individual

Protección criptográfica de cada registro sin dependencia explícita del autenticador anterior.

## Autenticación secuencial

Protección criptográfica cuya entrada depende de un estado derivado de registros anteriores.

## Checkpoint

Compromiso criptográfico sobre un estado determinado de la bitácora.

## Anclaje externo

Persistencia de un checkpoint en un dominio de confianza excluido del rollback local.

## Truncamiento

Eliminación de un sufijo del historial.

## Rollback

Sustitución del estado local por una versión anterior que puede ser internamente consistente.

## Estado terminal confiable

Referencia considerada válida por el verificador para determinar cuál debería ser el extremo vigente de una bitácora.

## Detección

Resultado que indica que el estado presentado no cumple las condiciones de verificación.

## Localización

Identificación de una posición o intervalo relacionado con la primera divergencia verificable.

## Verificabilidad independiente

Capacidad de verificar una propiedad utilizando información pública o separada del secreto que produjo el registro.# terminology
