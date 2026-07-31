---
document_id: PT2-DOC-17
title: Context-budgeted Agent Workflow
version: 0.1.0
status: PROVISIONAL
approved_by: PENDING
approval_date: PENDING
---

# Context-budgeted Agent Workflow

## 1. Propósito

Este documento establece un procedimiento operativo para reducir contexto
innecesario, conservar trazabilidad y mantener pequeños los cambios realizados
por agentes.

No aprueba decisiones científicas, mecanismos, formatos, métricas, tratamientos
ni protocolos experimentales.

## 2. Autoridad

Este procedimiento está subordinado a:

1. decisiones aprobadas por el investigador;
2. contrato de investigación aprobado;
3. especificaciones normativas aprobadas;
4. esquemas ejecutables aprobados;
5. pruebas de conformidad;
6. planes experimentales;
7. implementación;
8. documentación descriptiva.

Un task brief, un manifest, un resumen o una salida de agente son artefactos
derivados y no cambian este orden.

## 3. Unidad mínima de trabajo

Cada tarea debe:

- perseguir un único objetivo principal;
- declarar archivos permitidos y prohibidos;
- conservar explícitamente los estados científicos aplicables;
- evitar combinar gobierno, decisión científica, implementación y resultados;
- producir un diff revisable de manera independiente.

Cuando una tarea necesite resolver más de una decisión bloqueante, debe
dividirse salvo que el investigador autorice expresamente el alcance conjunto.

## 4. Presupuesto de contexto

El presupuesto documental predeterminado es:

```yaml
max_repository_source_lines: 600
target_document_tokens_approx: 12000
max_full_document_reads: 2
max_selective_ranges: 8
```

El presupuesto incluye reglas, especificaciones, ADR, planes y documentación
utilizados para decidir el cambio.

No incluye:

* el código o documento que constituye el objeto directo de edición;
* el diff producido;
* salidas de compilación;
* salidas de pruebas;
* datos experimentales necesarios para una tarea experimental autorizada.

Superar el presupuesto requiere registrar:

* cantidad adicional;
* fuente adicional;
* razón concreta;
* riesgo que no puede resolverse mediante lectura selectiva.

La frase “por si acaso” no constituye justificación.

## 5. Lectura obligatoria y selectiva

### 5.1 Lectura íntegra

`AGENTS.md` se lee íntegramente una vez al inicio de cada tarea o sesión.

`docs/01-change-control.md` se lee íntegramente cuando la tarea:

* modifica gobierno o estados;
* propone, aprueba o rechaza una decisión;
* modifica contenido normativo;
* altera protocolos, métricas o tratamientos;
* presenta una ambigüedad de autoridad.

### 5.2 Lectura selectiva

Los ADR extensos se consultan por defecto mediante:

* front matter;
* estado y alcance;
* decisión del investigador;
* consecuencias;
* secuencia de trabajo posterior;
* sección directamente afectada;
* identificadores y documentos afectados.

La lectura íntegra de un ADR se reserva para:

* modificar o refactorizar el ADR completo;
* auditar su consistencia integral;
* resolver una contradicción que atraviesa varias secciones;
* preparar una decisión científica final.

Las revisiones posteriores deben reutilizar el mismo brief y consultar el diff,
los hallazgos y las secciones afectadas. No deben recargar automáticamente todas
las fuentes.

## 6. Task brief

Todo task brief debe comenzar con:

```markdown
# Agent Task Brief — <TASK-ID>

status: DERIVED_NON_NORMATIVE
base_commit: <40-character-commit-sha>
created_at: <ISO-8601>
prepared_by: <actor>
task_owner: <researcher-or-authorized-owner>

## Objective

<one principal objective>

## Authorized changes

- <path or change class>

## Forbidden changes

- scientific approval
- implicit candidate acceptance
- blocker removal
- unapproved metric or treatment changes
- productive implementation outside scope

## Scientific state to preserve

- <identifier>: <state>
- <identifier>: <state>

## Deliverables

- <deliverable>

## Dependencies

### Hard dependencies

- <dependency or none>

### Soft dependencies

- <dependency or none>

## Context budget

max_repository_source_lines: 600
target_document_tokens_approx: 12000
max_full_document_reads: 2
max_selective_ranges: 8
exception: NONE

## Source manifest

<embedded source manifest>

## Ambiguities and stop conditions

- <condition that requires stopping or escalation>

## Acceptance checks

- <command or invariant>

## Review plan

round_1: full authorized scope
round_2: corrections and consistency
third_round: STRUCTURAL_ESCALATION
```

Un brief no puede:

* declarar aprobada una fuente `DRAFT`;
* omitir un bloqueo conocido;
* reemplazar reglas normativas por una paráfrasis;
* autorizar archivos fuera de su alcance;
* ocultar una ambigüedad para permitir implementación.

## 7. Manifest de fuentes

El manifest utiliza esta estructura:

```yaml
manifest_version: 1
base_commit: <40-character-commit-sha>
generated_at: <ISO-8601>

sources:
  - path: AGENTS.md
    authority: repository_governance
    blob_sha: <40-character-blob-sha>
    read_mode: full
    ranges:
      - heading: entire_document
        lines: <start-end>
        purpose: repository rules

  - path: docs/example.md
    authority: <approved_specification|draft_decision|descriptive_document>
    blob_sha: <40-character-blob-sha>
    read_mode: selective
    ranges:
      - heading: <exact heading>
        lines: <start-end>
        purpose: <reason>

external_sources:
  - id: RFC-XXXX
    immutable_reference: RFC XXXX
    sections:
      - <section>
    purpose: <reason>
    copied_normative_text: false

excluded_sources:
  - path: <path>
    reason: <why it is not required>

budget:
  repository_source_lines: <integer>
  approximate_document_tokens: <integer>
  exception: NONE
```

El commit base identifica el estado global utilizado para preparar la tarea.

El blob SHA identifica la versión exacta de cada archivo. Un cambio de `HEAD` no
invalida automáticamente el brief si las fuentes listadas conservan sus blob
SHAs, pero obliga a comprobarlas nuevamente.

Si cambia el blob SHA de una fuente:

1. el rango anterior deja de considerarse válido;
2. debe localizarse nuevamente el encabezado;
3. debe revisarse el brief;
4. no se debe continuar usando el resumen anterior como contrato.

Los rangos de líneas facilitan la recuperación. Los encabezados identifican la
sección semántica.

## 8. Estándares externos por referencia

Los estándares externos se citan mediante identificador y sección.

La documentación PT2 debe describir:

* las elecciones que el estándar deja abiertas;
* restricciones adicionales;
* tipos prohibidos;
* límites;
* condiciones de rechazo;
* comportamiento específico del proyecto.

No debe reproducir extensamente contenido que ya esté definido por el estándar.

La fórmula preferida es:

```text
estándar por referencia + delta explícito de PT2
```

Una referencia externa no aprueba por sí sola una decisión PT2.

## 9. Separación documental futura

Una futura refactorización de decisiones extensas debe separar:

1. ADR compacto: decisión, alternativas, razones y consecuencias;
2. perfil normativo: reglas exactas e interfaces;
3. historial: evolución y deliberación no normativa;
4. conformidad: fixtures y pruebas ejecutables.

El ADR debe apuntar al perfil y a la suite, pero no duplicarlos íntegramente.

Esta regla no mueve, aprueba ni modifica ADR-001. Cualquier refactorización de
ADR-001 requiere una tarea documental independiente y autorizada.

## 10. Vectores y pruebas de conformidad

Los casos narrativos deben transformarse en pruebas ejecutables cuando estén
satisfechas sus dependencias.

Cada vector futuro debe registrar:

* versión del perfil;
* entrada lógica;
* bytes exactos;
* representación hexadecimal;
* resultado esperado;
* categoría y detalle de rechazo;
* productor;
* herramienta o implementación independiente de contraste.

Las pruebas no pueden redefinir una regla ausente del perfil.

Los veinte vectores descritos en ADR-001 no se crean ni se consideran aprobados
por este documento. Permanecen sujetos a la aceptación experimental expresa
establecida en ADR-001.

## 11. Rondas de revisión

### Ronda 1

Revisión integral del alcance autorizado:

* autoridad;
* contradicciones;
* comportamiento;
* pruebas;
* trazabilidad;
* archivos fuera de alcance.

Los hallazgos se agrupan y se corrigen como un lote.

### Ronda 2

Verificación de:

* correcciones;
* regresiones;
* consistencia entre archivos;
* conservación de estados y bloqueos;
* validaciones finales.

No debe repetirse una revisión completa por cambios exclusivos en la descripción
del PR o en respuestas a comentarios.

### Tercera ronda

La necesidad de una tercera ronda no inicia otra corrección incremental.
Activa `STRUCTURAL_ESCALATION`.

## 12. Escalamiento estructural

El escalamiento se activa cuando:

* una tercera ronda sería necesaria;
* reaparece el mismo hallazgo de severidad alta;
* el alcance crece más allá del brief;
* aparece una dependencia científica no resuelta;
* el documento mezcla decisión, perfil, historial y pruebas;
* el manifest queda obsoleto durante la tarea.

El escalamiento exige:

1. detener cambios incrementales;
2. registrar la causa raíz;
3. reducir o dividir el PR;
4. actualizar brief y manifest;
5. conservar explícitamente los bloqueos;
6. obtener autorización si cambia el alcance;
7. solicitar una revisión dirigida después de la reestructuración.

La revisión dirigida posterior al escalamiento no constituye aprobación
científica automática.

## 13. Paralelización

| Línea de trabajo                    | Estado de inicio                | Permitido                                                      | No permitido                                          |
| ----------------------------------- | ------------------------------- | -------------------------------------------------------------- | ----------------------------------------------------- |
| Gobierno del flujo                  | READY con autorización          | Documentos operativos y plantillas                             | Cambios científicos                                   |
| Refactor ADR/perfil/historial       | REQUIRES SEPARATE AUTHORIZATION | Reorganización semánticamente neutra                           | Aprobar o reescribir la decisión                      |
| Esqueleto del harness               | READY WITH CONSTRAINTS          | Build, CI, interfaces neutrales, evidencia cruda               | Semántica definitiva de mecanismos                    |
| Framework del generador de datasets | READY WITH CONSTRAINTS          | Semillas, reproducibilidad, manifests, carga fuera de medición | Congelar schema o contenido científico pendiente      |
| Baseline SQLite funcional           | READY WITH CONSTRAINTS          | Apertura, inserción, lectura y smoke tests no oficiales        | Resultados comparativos oficiales o nuevas métricas   |
| Codificadores y vectores candidatos | BLOCKED                         | Ninguno antes de aceptación experimental expresa               | Inferir aceptación desde el merge del PR #8           |
| MEC-A1 definitivo                   | BLOCKED                         | Ninguno                                                        | Implementación productiva o desbloqueo                |
| Métricas oficiales de append        | BLOCKED                         | Ninguna medición oficial                                       | Elegir silenciosamente la región medida               |
| Interpretación científica           | BLOCKED                         | Ninguna conclusión experimental                                | Usar scaffolding o pruebas funcionales como evidencia |

`READY WITH CONSTRAINTS` requiere una tarea explícitamente autorizada.

Una tarea paralela no puede consumir como contrato estable un resultado
`BLOCKED`, `DRAFT` o no validado.

## 14. Tamaño y commits del PR

El objetivo predeterminado es:

```yaml
principal_objectives: 1
normal_review_rounds: 2
implementation_commit: 1
correction_commits_per_round: 1
```

Más de tres commits sustantivos antes del merge es una señal para:

* agrupar correcciones;
* hacer squash;
* o dividir el alcance.

El número de commits es una señal de control, no una razón para ocultar
historial relevante.

## 15. Criterios de finalización

Una tarea regida por este flujo termina cuando:

1. el diff permanece dentro del brief;
2. el manifest coincide con las fuentes;
3. no cambian decisiones o estados fuera de alcance;
4. se ejecutan las validaciones aplicables;
5. los bloqueos se conservan;
6. se documentan excepciones de contexto;
7. no quedan archivos accidentales o cachés rastreados;
8. se informa el SHA del commit;
9. no se realiza merge automático.

## 16. Estado científico conservado

Este documento no:

* aprueba ADR-001;
* acepta `PT2-CBOR-AUTH-RECORD-CANDIDATE-v1`;
* desbloquea MEC-A1;
* desbloquea `MET-APPEND-READY-E2E`;
* modifica ADR-002, ADR-003 o ADR-004;
* modifica preguntas, hipótesis o tratamientos;
* crea código productivo;
* genera bytes, claves, vectores o resultados experimentales.
