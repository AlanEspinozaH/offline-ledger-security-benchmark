---
document_id: PT2-DOC-01
title: Change Control
version: 0.2.0
status: DRAFT
approved_by: PENDING
approval_date: PENDING
---

# Change Control

## 1. Autoridad

El investigador es la autoridad final sobre:

- preguntas de investigación;
- hipótesis;
- alcance;
- modelo de amenaza;
- mecanismos;
- métricas;
- diseño experimental;
- interpretación de resultados.

Codex y otros agentes pueden proponer cambios, pero no aprobarlos.

## 2. Fusión versus aprobación

Fusionar un pull request significa que el contenido se incorpora al repositorio.

No significa automáticamente que:

- la decisión científica esté aprobada;
- la hipótesis sea definitiva;
- el protocolo experimental esté congelado;
- el documento tenga estado `APPROVED`.

## 3. Cambios normativos

Un cambio es normativo cuando modifica:

- alcance;
- pregunta de investigación;
- amenaza;
- propiedad esperada;
- formato autenticado;
- mecanismo;
- métrica;
- tratamiento;
- nivel experimental;
- esquema de evidencia;
- criterio de análisis.

Todo cambio normativo debe incluir:

1. motivo;
2. documentos afectados;
3. consecuencias;
4. identificadores de trazabilidad afectados;
5. decisión del investigador.

## 4. Estados

- `DRAFT`
- `PROVISIONAL`
- `APPROVED`
- `SUPERSEDED`
- `REJECTED`

## 5. Congelamiento del protocolo

Después del piloto, el protocolo podrá etiquetarse como:

`pt2-protocol-v1.0`

Los cambios posteriores deberán registrarse como desviaciones.

## 6. Desviaciones experimentales

Toda desviación debe indicar:

- fecha;
- ejecución afectada;
- versión del protocolo;
- razón;
- impacto;
- decisión sobre inclusión o exclusión de los datos.

## 7. Modificaciones por agentes

Un agente no puede modificar documentos normativos salvo que la tarea lo autorice explícitamente.

Cuando encuentre una ambigüedad debe:

1. detener la decisión afectada;
2. registrar la ambigüedad;
3. proponer alternativas;
4. no seleccionar una alternativa silenciosamente.

## 8. Registro de decisiones

Las decisiones normativas relevantes se registran en `docs/decisions/`
mediante identificadores `ADR-*`.

Los agentes pueden proponer alternativas y recomendaciones, pero únicamente
el investigador puede cambiar una decisión a estado `APPROVED`.

Un ADR en estado `DRAFT` o `PROVISIONAL` no autoriza una implementación
definitiva.

## 9. Gobierno de tareas de agentes

Las tareas ejecutadas por agentes deben cumplir
`docs/17-agent-workflow.md`.

Antes de modificar archivos, la tarea debe disponer de:

1. objetivo y alcance autorizado;
2. archivos permitidos y prohibidos;
3. estado científico que debe conservarse;
4. task brief marcado `DERIVED_NON_NORMATIVE`;
5. manifest de fuentes con commit base y blob SHAs;
6. presupuesto de contexto;
7. dependencias y bloqueos;
8. criterios de aceptación y comandos de validación.

La lectura selectiva no reduce la autoridad de una fuente. Cuando un brief, una
prueba, una implementación o un resumen contradigan una fuente de mayor
autoridad, prevalece la fuente y la tarea debe detener la decisión afectada.

## 10. Rondas de revisión

Un pull request admite dos rondas normales de revisión automática:

1. revisión integral del alcance autorizado;
2. verificación de las correcciones y de la consistencia resultante.

Los hallazgos de cada ronda deben agruparse antes de modificar archivos. Se debe
evitar un commit separado por cada observación individual.

La necesidad de una tercera ronda, la repetición de un hallazgo de severidad
alta o la aparición de una nueva dependencia bloqueante activa escalamiento
estructural.

## 11. Escalamiento estructural

El escalamiento estructural requiere:

1. detener las correcciones incrementales;
2. clasificar la causa raíz;
3. comprobar si el documento o PR mezcla responsabilidades;
4. reducir o dividir el alcance;
5. regenerar el task brief y el manifest;
6. solicitar autorización del investigador si cambia el alcance o una decisión;
7. ejecutar una revisión dirigida después de la reestructuración.

El escalamiento no aprueba decisiones, no elimina bloqueos y no autoriza cambios
fuera del alcance original.

## 12. Trabajo paralelo

Dos tareas pueden ejecutarse en paralelo únicamente cuando:

- no modifican el mismo contrato;
- no consumen como estable una decisión `DRAFT` o `PROVISIONAL`;
- sus dependencias duras están satisfechas;
- sus archivos de salida no se solapan;
- ninguna produce resultados experimentales oficiales antes de aprobar el
  protocolo aplicable.

La infraestructura neutral puede adelantarse cuando la tarea autorizada
demuestre que no congela mecanismos, métricas, tratamientos, formatos o
interpretaciones pendientes.