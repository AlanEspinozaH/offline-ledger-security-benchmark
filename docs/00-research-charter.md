---
document_id: PT2-DOC-00
title: Research Charter
version: 0.1.0
status: DRAFT
approved_by: PENDING
approval_date: PENDING
---

# Research Charter

## 1. Propósito

Este repositorio contiene el artefacto experimental de Proyecto de Tesis II para estudiar mecanismos de autenticación, continuidad, checkpoints y anclaje externo intermitente aplicados a registros transaccionales locales.

El repositorio no implementa un sistema POS completo.

## 2. Problema operacional provisional

Los registros transaccionales almacenados únicamente en un dispositivo local pueden ser modificados, eliminados, reordenados, truncados o restaurados a una versión anterior.

Los mecanismos locales de autenticación pueden detectar determinadas manipulaciones, pero no necesariamente permiten distinguir una versión vigente de una copia antigua internamente válida cuando todo el estado confiable se encuentra en el mismo dominio restaurable.

## 3. Contribución prevista

La contribución provisional consiste en:

- especificar mecanismos comparables bajo una representación común;
- evaluar autenticación individual y secuencial;
- evaluar checkpoints firmados con diferentes granularidades;
- estudiar anclaje externo intermitente para rollback;
- separar propiedades de seguridad y costos operativos;
- producir evidencia reproducible.

## 4. Unidad experimental

Una unidad experimental es una ejecución aislada de:

- una configuración de protección;
- un dataset determinado;
- una semilla;
- un escenario de ataque;
- un perfil de adversario;
- un protocolo de medición versionado.

## 5. Dentro del alcance

- SQLite como almacenamiento embebido local;
- datos sintéticos reproducibles;
- autenticación mediante HMAC;
- encadenamiento autenticado;
- checkpoints Ed25519;
- anclaje externo mínimo;
- edición, eliminación, inserción, reordenamiento, truncamiento y rollback;
- mediciones separadas de configuración, inserción, verificación, checkpoint y anclaje.

## 6. Fuera del alcance

- POS funcional completo;
- interfaz gráfica;
- inventario y ventas comerciales;
- sincronización entre múltiples terminales;
- CRDT;
- blockchain;
- ataques de red;
- compromiso de claves;
- disponibilidad productiva del servicio;
- fraude comercial;
- despliegue en nube productivo.

## 7. Criterio provisional de éxito

PT2 se considera técnicamente completado cuando:

1. las configuraciones aprobadas cumplen contratos comunes;
2. los ataques son reproducibles;
3. los resultados son estructurados;
4. la evidencia contiene trazabilidad hacia preguntas y métricas;
5. las corridas pueden reproducirse desde un commit y un plan versionado;
6. las conclusiones se derivan de datos crudos conservados.
