---
decision_id: ADR-002
title: Key scope and provisioning
version: 0.2.0
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-002 — Alcance y provisión de claves

## Contexto

`MEC-A1` requiere una clave HMAC, pero todavía no están definidos su alcance,
identificación, provisión ni política de rotación. `THR-P1` puede leer y
restaurar el dominio local, pero no puede obtener claves activas ni secretos de
desbloqueo. El diseño experimental debe instanciar esa frontera sin construir
una infraestructura productiva de gestión de secretos.

Las claves deben estar disponibles antes de cualquier región `append-hot` o
`verify-hot` que las declare precargadas. Este ADR delimita la decisión
pendiente; no define una API Java, un keystore comercial ni un servicio remoto.

## Problema exacto que requiere decisión

El investigador debe aprobar una política reproducible que determine:

- alcance de la clave: global, por ledger, por dataset o por ejecución;
- tamaño mínimo;
- formato y dominio de unicidad de `key_id`;
- provisión al protector;
- provisión al verificador;
- almacenamiento y frontera de confianza;
- exclusión de claves activas del dominio de `THR-P1`;
- rotación incluida o fuera de alcance;
- equilibrio entre reproducibilidad y generación aleatoria.

La política debe permitir interpretar los resultados de `MEC-A1` sin almacenar
claves, semillas secretas o passphrases en el repositorio o en la evidencia.

## Criterios de evaluación

- consistencia con las capacidades y exclusiones de `THR-P1`;
- aislamiento entre unidades experimentales y prevención de contaminación;
- reproducibilidad del procedimiento, no necesariamente de los bytes secretos;
- posibilidad de seleccionar la clave mediante un `key_id` no secreto;
- disponibilidad simétrica para protección y verificación autorizadas;
- exclusión verificable de generación, carga y derivación de regiones calientes;
- baja complejidad y ausencia de infraestructura productiva fuera de alcance;
- capacidad de documentar fallos de provisión sin revelar material sensible.

## Política candidata para experimentación

**CANDIDATO NO NORMATIVO**

Identificador de política: `ADR002-KEY-POLICY-CANDIDATE-v1`.

Esta sección propone una política técnica concreta exclusivamente para
experimentación controlada con `MEC-A1`. La propuesta permanece pendiente de
aceptación experimental separada y no constituye una decisión del investigador,
una especificación normativa ni una autorización de implementación.

### 1. Alcance de la clave

La candidata asigna una clave HMAC independiente a cada `ledger_id`. Una clave
no puede proteger dos `ledger_id` distintos y cada relación ledger-clave se
registra mediante un `key_id`.

Una clave aleatoria nueva se genera cuando se crea una nueva relación
ledger-clave autorizada. En esta política, «nueva» califica la creación de esa
relación y no implica necesariamente renovar la clave en cada ejecución.

Si el mismo `ledger_id` aparece en distintos datasets o ejecuciones, el
futuro plan experimental debe declarar si persiste la misma relación autorizada
o si se crea una relación nueva con clave nueva y `key_id` nuevo.
ADR-002 v0.2.0 no selecciona entre esas políticas y no permite resolver esa
decisión mediante
reutilización silenciosa. En ningún caso una clave protege dos `ledger_id`
distintos. No se selecciona una clave global, una clave por dataset ni una clave
productiva.

La clave por ledger es la alternativa finalista de esta propuesta, no una
alternativa aprobada.

### 2. Material de clave

Cada clave candidata es una secuencia opaca de exactamente 32 octetos
(256 bits) para HMAC-SHA-256. Debe generarse mediante una fuente
criptográficamente segura, fuera de las regiones `append-hot` y `verify-hot`.

Una clave con longitud distinta de 32 octetos se rechaza. No se permite
normalización, truncamiento, padding ni conversión textual del material. Esta
regla conceptual todavía no define una API ni un formato de almacenamiento.

### 3. `key_id`

Cada `key_id` candidato es un identificador opaco de exactamente 16 octetos.
No es secreto, es externo a `authenticated_record_bytes_v1`, no deriva de la
clave mediante hash o truncamiento, no revela la clave y no la sustituye.

El `key_id` debe ser único dentro del corpus o campaña experimental. Una
colisión detectada invalida la preparación de la unidad experimental. Los
fixtures podrán transportarlo como hexadecimal lowercase de exactamente
32 caracteres, exclusivamente como transporte no normativo.

Esta propuesta no define una representación normativa SQLite, Java, UUID o de
red.

### 4. Asociación y resolución

La asociación candidata es:

```text
(ledger_id, key_id) -> key_bytes
```

El resolver debe comprobar conjuntamente ambos identificadores. Si no existe
exactamente la pareja `(ledger_id, key_id)`, el resultado de `MEC-A1` es
`UNKNOWN_KEY`. Esta regla incluye el caso en que el `key_id`
exista para otro `ledger_id`; el resolver no intenta HMAC con la clave
asociada al otro ledger y no produce un estado alternativo de resolución.

Los fallos de configuración quedan reservados para material aprovisionado
inválido detectado antes de iniciar la unidad experimental o la verificación.
Una clave configurada con longitud distinta de 32 octetos produce ese fallo de
configuración, no `UNKNOWN_KEY` ni `INVALID_TAG`. `INVALID_TAG` solo puede
ocurrir después de resolver correctamente una clave válida de 32 octetos y
comparar el HMAC completo.

Esta asociación no constituye una API, una clase ni un schema ejecutable.

### 5. Provisión al protector y verificador

La candidata propone provisión previa mediante registros en memoria. Protector
y verificador reciben la relación `(ledger_id, key_id) -> key_bytes` antes de
comenzar la región medida. Pueden utilizar instancias separadas de un proveedor
experimental, cargadas con la misma relación.

La generación o derivación de claves, la lectura de contenedores, el desbloqueo
y la carga quedan fuera de `append-hot` y `verify-hot`. Una ausencia de
provisión se registra antes o durante la operación según el punto exacto en que
se detecte, sin ocultar ni recategorizar el fallo.

Este ADR no selecciona un keystore comercial, un servicio remoto ni una API
Java.

### 6. Frontera de confianza

En la candidata base, la clave activa existe únicamente en memoria de procesos
legítimos autorizados y `THR-P1` no obtiene esos bytes. SQLite, WAL, SHM,
manifests, resultados y evidencia no contienen la clave.

La evidencia puede contener `key_id`, `ledger_id`, tamaño, algoritmo, estado
de provisión y versión de política. Nunca puede contener la clave, una
passphrase, una semilla recuperable ni un secreto maestro.

Los core dumps, swap, depuración privilegiada y compromiso del proceso están
fuera del alcance de `THR-P1`. Esta delimitación no afirma que el diseño sea
productivamente seguro ni promete borrado perfecto o zeroization garantizada
por runtimes administrados.

### 7. Rotación

La rotación queda fuera del alcance de
`ADR002-KEY-POLICY-CANDIDATE-v1`. Un ledger usa una sola asociación activa
durante la unidad experimental. No se definen periodos, historial ni selección
de claves antiguas.

Estudiar rotación requerirá un tratamiento y una decisión separados. Excluirla
reduce variables del caso base, pero no demuestra soporte de rotación.

### 8. Reproducibilidad

#### Vectores candidatos de conformidad

Una tarea posterior podrá proponer una clave fija, pública y marcada
exactamente como:

```text
TEST KEY — NOT SECRET — NOT FOR EXPERIMENTAL RUNS
```

junto con un `key_id` fijo de prueba. Su finalidad exclusiva será reproducir
bytes HMAC y resultados esperados. Este ADR no genera todavía esa clave ni
vectores.

#### Corridas experimentales

Al crear una nueva relación ledger-clave para una unidad experimental
autorizada, la clave se genera aleatoriamente y es nueva para esa relación. Si
un mismo `ledger_id` reaparece entre datasets o ejecuciones, el futuro plan
experimental debe declarar si conserva la relación autorizada o crea una nueva
relación con nueva clave y nuevo `key_id`. Esta política candidata no
selecciona entre esas opciones y prohíbe resolverlas mediante reutilización
silenciosa.

La reproducibilidad corresponde al procedimiento, versiones, tamaño, proveedor
y metadatos no secretos, no a publicar el secreto.

Las claves públicas de vectores no pueden reutilizarse en experimentos. Esta
candidata tampoco selecciona una derivación desde un secreto maestro.

### 9. Evidencia candidata

Como mínimo se proponen estos campos conceptuales no secretos:

- `key_policy_id`;
- `key_id`;
- `ledger_id`;
- `key_length_bytes`;
- `key_generation_mode`;
- `provider_kind`;
- `provisioned_before_measurement`;
- `rotation_enabled`;
- estado de resolución.

Son campos conceptuales y no modifican todavía ningún schema. Cada
incorporación futura requiere trazabilidad y autorización. Ninguno puede
contener material de clave.

### 10. Fallos y precedencia

La precedencia conceptual candidata es:

1. una configuración inválida de la política o de la clave impide iniciar la
   unidad experimental;
2. un `key_id` no resoluble para el `ledger_id` produce `UNKNOWN_KEY`;
3. con una clave resuelta, un tag con longitud distinta de 32 octetos produce
   `INVALID_TAG`;
4. con una clave resuelta, un tag de 32 octetos diferente produce
   `INVALID_TAG`;
5. un tag válido permite continuar al contexto secuencial cuando exista.

Esta secuencia no redefine la precedencia completa pendiente en ADR-001.

### 11. Dependencias posteriores

Incluir esta política candidata en ADR-002:

- no aprueba ADR-002;
- no desbloquea `MEC-A1`;
- no desbloquea `MET-APPEND-READY-E2E`, que permanece `BLOCKED`;
- no autoriza implementación productiva;
- no autoriza regiones de medición;
- no genera claves, tags ni vectores;
- no modifica ADR-001;
- permite preparar posteriormente una solicitud separada de aceptación
  experimental;
- solo después de esa aceptación podrán autorizarse vectores HMAC candidatos.

## Alternativas concretas para el alcance de clave

### Alternativa A — Clave global del benchmark

**Clasificación respecto de la política propuesta:** no finalista.

Una clave activa compartida por todos los ledgers, datasets y ejecuciones del
protocolo que adopten la misma versión de mecanismo.

#### Ventajas

- configuración y selección simples;
- minimiza operaciones de provisión;
- facilita repetir verificaciones dentro del mismo entorno controlado.

#### Desventajas

- amplía el impacto de una exposición accidental;
- acopla unidades experimentales que deberían estar aisladas;
- dificulta atribuir inequívocamente un `key_id` a una unidad.

#### Consecuencias

Todos los resultados dependerían de una misma frontera secreta. Habría que
justificar por qué esa dependencia no introduce contaminación ni reutilización
indebida entre tratamientos.

### Alternativa B — Clave por ledger

**Clasificación respecto de la política propuesta:** candidata finalista.

Cada `ledger_id` recibe una relación ledger-clave. La relación puede persistir
durante la vida autorizada del ledger que defina el futuro plan experimental,
pero nunca se reutiliza automáticamente entre datasets o ejecuciones.

#### Ventajas

- alinea la clave con el objeto lógico protegido;
- limita el impacto entre ledgers;
- hace natural resolver `key_id` junto con `ledger_id`.

#### Desventajas

- exige definir si un ledger persiste entre datasets o ejecuciones;
- aumenta el número de claves y operaciones de provisión;
- puede correlacionar repeticiones si se reutiliza el mismo ledger.

#### Consecuencias

El protocolo tendría que congelar la vida de `ledger_id`, la unicidad de la
pareja ledger-clave y el tratamiento de recreaciones o copias del ledger.

### Alternativa C — Clave por dataset

**Clasificación respecto de la política propuesta:** no finalista.

Todos los ledgers o tratamientos derivados de un dataset comparten una clave,
o cada dataset define el conjunto de claves que utilizarán sus tratamientos.

#### Ventajas

- facilita preparar tratamientos comparables sobre los mismos datos;
- reduce variación de provisión dentro del dataset;
- permite aislar datasets entre sí.

#### Desventajas

- el concepto dataset no coincide necesariamente con la frontera de ledger;
- compartir clave entre tratamientos puede crear dependencias no deseadas;
- requiere definir qué ocurre con datasets derivados o regenerados.

#### Consecuencias

La identidad y versión del dataset pasarían a ser parte normativa de la
selección de clave, aunque no necesariamente del mensaje autenticado.

### Alternativa D — Clave por ejecución

**Clasificación respecto de la política propuesta:** alternativa de aislamiento
que podría reconsiderarse si el plan experimental define la ejecución como
unidad principal.

Cada unidad experimental recibe material nuevo o derivado de forma aislada.

#### Ventajas

- máximo aislamiento entre ejecuciones;
- reduce reutilización accidental y contaminación entre tratamientos;
- hace explícita la vida corta de la clave experimental.

#### Desventajas

- aumenta el costo y la complejidad de provisión fuera de la región medida;
- repetir una corrida no reproduce los mismos tags si se usa aleatoriedad nueva;
- exige enlazar de forma no secreta la ejecución con su `key_id`.

#### Consecuencias

La reproducibilidad se basaría en el procedimiento y la distribución de claves,
o en una derivación secreta controlada, no en publicar los bytes de la clave.

## Comparación resumida de alternativas

| Alternativa | Clasificación candidata | Relación con la política propuesta |
|---|---|---|
| Clave global | No finalista | No aísla ledgers y amplía dependencias entre unidades. |
| Clave por ledger | Candidata finalista | Se alinea con el objeto autenticado, la asociación explícita con `ledger_id`, la resolución conjunta, el aislamiento entre ledgers y la verificación posterior. |
| Clave por dataset | No finalista | El dataset no coincide necesariamente con la frontera lógica del ledger. |
| Clave por ejecución | Alternativa de aislamiento | Podría reconsiderarse si el futuro plan experimental define la ejecución como unidad principal. |

La clasificación favorece conceptualmente la clave por ledger porque mantiene
la selección de clave vinculada al objeto autenticado y obliga al resolver a
comprobar `ledger_id` y `key_id`. También limita el uso accidental de una
clave entre ledgers y permite que la verificación posterior solicite
exactamente la relación esperada. Esta comparación es una justificación
técnica de la candidata, no una decisión del investigador.

## Riesgos

- guardar una clave activa o passphrase en el dominio legible por `THR-P1`;
- registrar una semilla “reproducible” que permita reconstruir la clave;
- incluir generación, derivación o carga en una región que presupone clave lista;
- usar `key_id` con colisiones o con un ámbito no documentado;
- reutilizar una clave global y confundir dependencia compartida con repetición;
- convertir este ADR en un diseño de gestión de secretos productivo fuera de PT2;
- incluir rotación sin definir selección de claves históricas y sus fallos.

## Recomendación técnica no vinculante

La política `ADR002-KEY-POLICY-CANDIDATE-v1` concreta la alternativa por
ledger con clave opaca de 32 octetos, `key_id` opaco de 16 octetos, resolución
conjunta y provisión previa en memoria. Se recomienda someterla posteriormente
a una solicitud separada de aceptación experimental.

La recomendación permanece no vinculante: no registra aprobación científica,
no elimina bloqueos y no convierte la política en especificación normativa.

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING

## Estado y dependencias mientras la decisión permanece pendiente

- ADR-002 continúa `DRAFT`;
- `MEC-A1` permanece `BLOCKED`;
- `MET-APPEND-READY-E2E` permanece `BLOCKED`;
- no existe implementación autorizada;
- los vectores de codificación sin HMAC pueden seguir tratándose en tareas
  independientes;
- los vectores con HMAC, `key_id` o contexto autenticado permanecen bloqueados
  hasta una aceptación experimental separada;
- una futura aceptación experimental no equivale a aprobación normativa.

## Documentos afectados

- `docs/04-threat-model.md`
- `docs/06-mechanism-specifications.md`
- `docs/11-measurement-contract.md`
- futuros planes experimentales y esquemas de evidencia, cuando sean autorizados

## Identificadores de trazabilidad

- `RQ-01`
- `MEC-A1`
- `THR-P1`
- `ADR-002`
