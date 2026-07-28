---
decision_id: ADR-003
title: Append measurement boundary
version: 0.1.0
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-003 — Frontera de medición del append

## Contexto

`MET-APPEND-READY-E2E` pretende medir una inserción individual con conexión,
esquema y claves preparados. El contrato actual fija el éxito después del
retorno de `COMMIT`, pero no determina completamente cómo se establece la
transacción ni dónde termina el intervalo cuando una fase falla.

La frontera elegida afecta la comparabilidad entre mecanismos y el significado
de la duración observada. Este ADR no autoriza una implementación y la métrica
permanece `BLOCKED` hasta una decisión aprobada.

## Problema exacto que requiere decisión

El investigador debe aprobar una frontera temporal única que determine:

- `BEGIN` dentro o fuera de la región medida;
- transacción explícita o implícita;
- final temporal ante éxito;
- final temporal ante fallo;
- `ROLLBACK` dentro o fuera de la métrica;
- cierre y limpieza dentro o fuera;
- campos de evidencia para operaciones fallidas;
- reglas de comparabilidad entre mecanismos;
- prevención de doble conteo entre métricas parciales y extremo a extremo.

La decisión debe describir una operación que nunca haya abierto transacción, una
que falle antes de `INSERT`, una que falle durante `INSERT` y una que falle en
`COMMIT`.

## Criterios de evaluación

- mismo significado temporal para todos los mecanismos comparados;
- intervalo continuo medido con reloj monotónico;
- endpoint observable tanto en éxito como en fallo;
- separación entre costo normal del append y recuperación posterior;
- evidencia suficiente para interpretar y filtrar fallos sin borrarlos;
- política de transacción congelada y visible en cada ejecución;
- ausencia de trabajo preparado dentro de una métrica “ready”;
- posibilidad de relacionar métricas parciales sin sumarlas dos veces;
- complejidad compatible con el artefacto PT2.

## Alternativas concretas de frontera

### Alternativa A — Ciclo transaccional explícito completo

El temporizador comienza antes de `BEGIN`. Ante éxito termina después de
`COMMIT`; ante fallo termina después de completar o intentar `ROLLBACK`. El
cierre de conexión y la limpieza general quedan fuera.

#### Ventajas

- representa el costo de dejar la transacción en un estado recuperado;
- ofrece un endpoint posterior a la recuperación para fallos;
- incluye de forma visible el establecimiento transaccional.

#### Desventajas

- los fallos mezclan costo del append con costo de recuperación;
- un rollback lento o fallido domina la duración y dificulta comparar etapas;
- el camino de éxito y el de fallo no terminan en eventos equivalentes.

#### Consecuencias

`ROLLBACK` formaría parte de la métrica solo en fallos. La evidencia tendría que
separar etapa del fallo, duración hasta el fallo y duración de recuperación para
evitar interpretar todo el intervalo como costo criptográfico o de persistencia.

### Alternativa B — Intento explícito con fallo terminal inmediato

El temporizador comienza antes de `BEGIN`. Ante éxito termina después de
`COMMIT`; ante fallo termina al observar la excepción o resultado terminal del
intento. `ROLLBACK`, cierre y limpieza se ejecutan después y quedan fuera.

#### Ventajas

- mide un intervalo continuo del intento sin mezclar recuperación;
- el endpoint de fallo es inmediato y comparable entre implementaciones;
- permite medir rollback por separado si alguna métrica futura lo autoriza.

#### Desventajas

- no refleja el tiempo total hasta que el recurso vuelve a estar utilizable;
- exige capturar el tiempo antes de iniciar manejo de la excepción;
- la exclusión de rollback debe probarse para evitar contaminación accidental.

#### Consecuencias

La duración fallida significaría “tiempo hasta observar el fallo”, no “tiempo
hasta recuperar el sistema”. El resultado de rollback seguiría siendo evidencia
necesaria, pero no se sumaría a `MET-APPEND-READY-E2E`.

### Alternativa C — Transacción explícita preestablecida

`BEGIN` ocurre antes del temporizador. La región empieza con una transacción
activa y termina después de `COMMIT` en éxito o al observar el fallo; rollback,
cierre y limpieza quedan fuera.

#### Ventajas

- aísla canonicalización, protección, `INSERT` y `COMMIT` del costo de `BEGIN`;
- reduce una fuente de variación si el establecimiento se mide aparte;
- mantiene visible el costo de persistencia de `COMMIT`.

#### Desventajas

- contradice una interpretación natural de extremo a extremo del append;
- requiere estado preexistente que puede variar entre mecanismos o repeticiones;
- facilita doble conteo si otra métrica incluye establecimiento y append.

#### Consecuencias

El contrato “ready” tendría que declarar explícitamente que una transacción
activa es una precondición y definir qué ocurre si `BEGIN` falla antes de obtener
una muestra.

### Alternativa D — Transacción implícita por operación

No se emite `BEGIN` ni `COMMIT` explícitos desde el harness. El temporizador
abarca la operación que provoca la transacción implícita y termina cuando esa
operación retorna o falla; cierre y limpieza quedan fuera.

#### Ventajas

- flujo simple con menos llamadas del harness;
- el endpoint coincide con el retorno de una operación;
- evita decidir la posición de un `BEGIN` explícito.

#### Desventajas

- delega la frontera transaccional al driver y su configuración;
- dificulta equiparar la persistencia implícita con un `COMMIT` explícito;
- puede producir diferencias entre versiones de driver o configuraciones.

#### Consecuencias

La política implícita y la versión del driver pasarían a ser parte esencial del
tratamiento. No sería válido comparar directamente muestras explícitas e
implícitas bajo el mismo nivel sin una justificación aprobada.

## Comparación de decisiones transversales

| Dimensión | Opciones | Ventajas y desventajas | Consecuencia para la evidencia |
|---|---|---|---|
| `BEGIN` | dentro; fuera; inexistente por transacción implícita | Dentro representa más del append, pero añade variación. Fuera aísla fases, pero requiere transacción preestablecida. Implícito simplifica llamadas, pero depende del driver. | Debe registrarse el modo y excluir muestras cuya precondición no coincida. |
| Transacción | explícita; implícita | La explícita hace visibles fronteras. La implícita reduce código, pero oculta decisiones del driver. | No deben agregarse ambos modos en el mismo tratamiento sin decisión metodológica. |
| Fin exitoso | retorno de `COMMIT`; retorno de operación autocommit | Ambos son observables, pero no necesariamente equivalentes en trabajo de persistencia. | El evento final debe nombrarse y congelarse por modo transaccional. |
| Fin fallido | primera excepción o resultado terminal; después de rollback; después de limpieza | La primera opción aísla el intento. Las otras reflejan recuperación creciente, pero mezclan fases. | Deben conservarse etapa y endpoint usados; una duración sin ambos datos no es comparable. |
| `ROLLBACK` | dentro; fuera; duración separada | Dentro mide recuperación, pero solo en fallos. Fuera mantiene la métrica del intento. Separarlo añade evidencia sin alterar la duración primaria. | Intento y recuperación no pueden sumarse a una métrica extremo a extremo si esta ya incluye rollback. |
| Cierre y limpieza | dentro; fuera; solo para una métrica de ciclo de vida futura | Incluirlos aproxima tiempo hasta liberar recursos, pero mezcla trabajo no específico del append. | Debe documentarse qué recursos permanecen abiertos al capturar el endpoint. |
| Comparabilidad | una política única para todos; políticas distintas como tratamientos separados | Una política única maximiza comparación directa. Separarlas permite estudiar modos, pero aumenta niveles experimentales. | Cada muestra debe vincularse a la versión de frontera y al modo transaccional aprobados. |

## Campos candidatos de evidencia para fallos

Los siguientes nombres son candidatos asociados a
`MET-APPEND-READY-E2E`; no crean identificadores `DAT-*` ni autorizan todavía
un esquema:

- estado de la operación;
- etapa donde se observó el fallo;
- tipo estructurado de fallo;
- endpoint temporal aplicado;
- duración hasta el endpoint, en nanosegundos;
- modo transaccional y posición de `BEGIN`;
- si se intentó `ROLLBACK` y su resultado;
- resultado de cierre o limpieza relevante;
- decisión posterior de inclusión o exclusión y su razón;
- versión del contrato de frontera.

Si se aprueban como campos, deberán incorporarse al esquema y a la trazabilidad
en una tarea autorizada.

## Riesgo de doble conteo

`MET-APPEND-READY-E2E` es un intervalo extremo a extremo, no la suma automática
de métricas parciales. Si se miden canonicalización, protección, persistencia o
recuperación por separado, esas duraciones pueden solaparse o estar contenidas
en el intervalo principal.

Una decisión futura deberá optar entre métricas parciales instrumentadas como
particiones no solapadas o mediciones diagnósticas independientes. En ambos
casos, el análisis debe evitar sumar una fase a un extremo a extremo que ya la
incluye.

## Riesgos

- medir `BEGIN` de forma distinta según el mecanismo;
- capturar el reloj después de iniciar rollback y declararlo como fallo inmediato;
- perder fallos ocurridos antes de que exista transacción;
- comparar transacción explícita e implícita como si fueran el mismo tratamiento;
- incluir cierre solo en algunas rutas de error;
- sumar métricas parciales solapadas al valor extremo a extremo;
- crear campos de evidencia sin esquema ni trazabilidad aprobados.

## Recomendación técnica no vinculante

Conviene que la métrica primaria sea un único intervalo continuo con endpoints
observables, y que recuperación y limpieza se identifiquen separadamente cuando
queden fuera. Antes de aprobar una alternativa deben ejecutarse casos piloto de
fallo en cada etapa para comprobar que el endpoint puede capturarse sin ramas
especiales por mecanismo.

Esta recomendación no selecciona posición de `BEGIN`, modo transaccional,
endpoint de fallo ni inclusión de rollback o limpieza.

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING. `MET-APPEND-READY-E2E` permanece `BLOCKED`; no existe una frontera de
fallo aprobada ni una política transaccional lista para implementar.

## Documentos afectados

- `docs/11-measurement-contract.md`
- futuros planes experimentales y esquemas de evidencia, cuando sean autorizados

## Identificadores de trazabilidad

- `RQ-04`
- `MET-APPEND-READY-E2E`
- `ADR-003`
