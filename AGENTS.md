# AGENTS.md

## Propósito del repositorio

Este repositorio contiene el artefacto experimental de Proyecto de Tesis II.

Las especificaciones normativas se encuentran actualmente en `docs/`. No se debe crear una jerarquía alternativa como `docs/spec/` salvo que exista una decisión explícitamente aprobada y registrada conforme a `docs/01-change-control.md`.

El repositorio no contiene ni pretende reconstruir un sistema POS completo.

## Autoridad del investigador

El investigador es la autoridad final sobre:

- preguntas de investigación;
- hipótesis;
- alcance;
- modelo de amenaza;
- mecanismos;
- métricas;
- diseño experimental;
- interpretación de resultados.

Codex y otros agentes pueden detectar ambigüedades, proponer alternativas e implementar decisiones aprobadas. No pueden aprobar decisiones científicas o metodológicas.

Fusionar un pull request no implica automáticamente que su contenido tenga estado `APPROVED`.

## Orden de autoridad

En caso de conflicto, prevalece el siguiente orden:

1. Decisiones explícitas aprobadas por el investigador y registradas conforme a `docs/01-change-control.md`.
2. Contrato de investigación aprobado.
3. Especificaciones normativas aprobadas en `docs/`.
4. Esquemas ejecutables aprobados, cuando existan.
5. Pruebas de conformidad.
6. Planes experimentales.
7. Implementación.
8. Documentación descriptiva.

El código no puede redefinir silenciosamente una especificación.

Los documentos con estado `DRAFT` o `PROVISIONAL` no deben tratarse como decisiones científicas definitivas.

## Restricciones de alcance

No implementar salvo que una tarea aprobada lo solicite explícitamente:

- interfaz gráfica;
- lógica comercial de ventas o inventario;
- sincronización de transacciones;
- CRDT;
- blockchain;
- autenticación comercial;
- panel web;
- ataques de red;
- compromiso de claves;
- múltiples algoritmos alternativos no especificados;
- backend completo de un POS;
- despliegue productivo en la nube.

## Restricciones arquitectónicas provisionales

Las siguientes reglas son propuestas provisionales hasta que sean aprobadas mediante el procedimiento de control de cambios:

- utilizar una representación canónica común para mecanismos comparables;
- evitar tratamientos especiales por mecanismo en el orquestador;
- separar lógica específica mediante contratos, adaptadores o políticas;
- producir resultados de verificación estructurados;
- separar datos crudos de conclusiones académicas.

Una tarea de implementación debe indicar expresamente cuáles de estas propuestas han sido aprobadas para su alcance.

## Reglas generales de implementación

- No incorporar passphrases, claves privadas, secretos o credenciales en el código fuente.
- No modificar documentos normativos salvo que la tarea lo autorice explícitamente.
- No modificar esquemas ejecutables salvo que la tarea lo autorice explícitamente.
- Todo comportamiento nuevo debe incluir pruebas aplicables.
- Todo campo nuevo de evidencia debe estar relacionado con un requisito, una métrica o una necesidad de reproducibilidad.
- La generación, carga o derivación de claves no debe incluirse en una región de medición salvo que el contrato de la métrica lo indique expresamente.
- El harness debe conservar datos crudos y no redactar conclusiones académicas.
- Una ambigüedad normativa no debe resolverse silenciosamente dentro del código.

## Manejo de ambigüedades

Cuando una tarea dependa de una decisión no especificada, el agente debe:

1. identificar la ambigüedad;
2. indicar los documentos y requisitos afectados;
3. proponer alternativas y consecuencias;
4. evitar implementar una elección arbitraria;
5. registrar la decisión cuando sea aprobada.

## Gobierno de contexto y tareas de agentes

Las tareas de agentes se rigen además por
`docs/17-agent-workflow.md`.

`AGENTS.md` debe leerse íntegramente una vez al inicio de cada tarea o sesión
de trabajo. `docs/01-change-control.md` debe leerse íntegramente cuando la
tarea sea normativa, de gobierno, de aprobación, de cambio de estado o cuando
exista una ambigüedad sobre autoridad.

Los demás documentos deben consultarse mediante lectura selectiva basada en un
task brief derivado y un manifest de fuentes. El manifest debe registrar el
commit base, el blob SHA de cada archivo, los encabezados o rangos consultados
y el propósito de cada lectura.

Un task brief es `DERIVED_NON_NORMATIVE`. No sustituye una fuente, no cambia su
estado y no puede aprobar una decisión científica o metodológica.

El presupuesto predeterminado se aplica al contexto documental específico
de la tarea:

- máximo de 600 líneas de fuentes específicas de la tarea;
- objetivo aproximado máximo de 12000 tokens específicos de la tarea;
- máximo de dos documentos específicos leídos íntegramente;
- máximo de ocho rangos selectivos adicionales.

El bootstrap obligatorio de gobierno —`AGENTS.md`,
`docs/01-change-control.md` cuando corresponda y los rangos aplicables de
`docs/17-agent-workflow.md`— se registra por separado y no se descuenta de ese
límite. Debe reutilizarse dentro de la misma sesión y releerse cuando cambie su
blob SHA o la tarea requiera una auditoría integral.

El código o diff que constituye el objeto directo de la tarea, así como las
salidas de compilación y pruebas, no se contabilizan como contexto documental.

Toda excepción al presupuesto debe registrarse en el task brief, indicar la
causa y enumerar las fuentes adicionales. No se debe ampliar el contexto por
precaución genérica.

Un pull request admite como máximo dos rondas normales de revisión automática.
La necesidad de una tercera ronda activa escalamiento estructural conforme a
`docs/17-agent-workflow.md`; no autoriza una tercera iteración incremental
automática.

Toda tarea paralela debe declarar sus dependencias, bloqueos y artefactos de
entrada. Un artefacto bloqueado o no aprobado no puede utilizarse como contrato
estable ni como evidencia experimental.

## Trazabilidad

Cada cambio debe indicar los identificadores aplicables cuando existan:

- `RQ-*`: pregunta de investigación;
- `HYP-*`: hipótesis;
- `REQ-*`: requisito;
- `MEC-*`: mecanismo;
- `THR-*`: perfil de adversario;
- `ATT-*`: ataque;
- `MET-*`: métrica;
- `DAT-*`: campo de evidencia;
- `TST-*`: prueba;
- `ADR-*`: decisión registrada.

Los registros `ADR-*` se almacenan en `docs/decisions/`.

## Criterios de finalización

### Tarea documental

Una tarea documental termina cuando:

1. el documento tiene identificador, versión y estado;
2. no contradice decisiones de mayor autoridad;
3. identifica decisiones pendientes;
4. actualiza la trazabilidad cuando corresponda;
5. no presenta errores de formato o referencias rotas.

### Tarea de esquema

Una tarea de esquema termina cuando:

1. el esquema es válido;
2. incluye ejemplos válidos e inválidos;
3. está vinculado con documentos normativos;
4. tiene pruebas automatizadas;
5. mantiene compatibilidad o registra explícitamente una ruptura.

### Tarea de código

Una tarea de código termina cuando:

1. compila;
2. supera pruebas unitarias y de conformidad aplicables;
3. cumple los contratos y esquemas aprobados;
4. no modifica el alcance sin una decisión registrada;
5. actualiza la trazabilidad;
6. documenta desviaciones conocidas.

### Tarea experimental

Una tarea experimental termina cuando:

1. utiliza un protocolo versionado;
2. registra el commit y el entorno;
3. conserva los datos crudos;
4. registra fallos y exclusiones;
5. puede reproducirse mediante un plan y una semilla;
6. no modifica silenciosamente tratamientos o métricas.
