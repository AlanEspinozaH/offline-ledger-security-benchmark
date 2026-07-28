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
