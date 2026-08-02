---
decision_id: ADR-002
title: Key scope and provisioning
version: 0.3.0
status: APPROVED
date: 2026-08-02
decided_by: Alan Espinoza
---

# ADR-002 — Alcance y provisión de claves

## Estado y alcance del expediente

Este expediente registra la decisión aprobada por el investigador sobre el
alcance, identificación, provisión, continuidad y frontera de confianza de las
claves HMAC utilizadas por `MEC-A1`.

Historial:

- ADR-002 v0.2.0 documentó
  `ADR002-KEY-POLICY-CANDIDATE-v1` como candidata no normativa.
- ADR-002 v0.3.0 selecciona una clave por instancia lógica de ledger y congela
  la regla de creación y continuidad de la relación ledger-clave.
- v0.3.0 sustituye documentalmente a v0.2.0 como versión vigente.
- La sección candidata se conserva como antecedente de la evaluación y no como
  política normativa vigente.

La política aprobada se identifica mediante `ADR-002 v0.3.0`. El identificador
`ADR002-KEY-POLICY-CANDIDATE-v1` permanece únicamente como identificador
histórico de la propuesta evaluada.

La aprobación resuelve la dependencia científica de política de claves, pero no
define todavía clases Java, tablas SQLite, formatos de almacenamiento,
keystores, servicios remotos, generación efectiva de claves, vectores HMAC,
regiones de medición ni una implementación productiva de gestión de secretos.

Decidido por: Alan Espinoza

Fecha de aprobación: 2026-08-02

## Contexto

`MEC-A1` requiere una clave HMAC, pero todavía no están definidos su alcance,
identificación, provisión ni política de rotación. `THR-P1` puede leer y
restaurar el dominio local, pero no puede obtener claves activas ni secretos de
desbloqueo. El diseño experimental debe instanciar esa frontera sin construir
una infraestructura productiva de gestión de secretos.

Las claves deben estar disponibles antes de cualquier región `append-hot` o
`verify-hot` que las declare precargadas. Este ADR registra la política
experimental aprobada, pero no define una API Java, un keystore comercial ni un
servicio remoto.

## Problema exacto que requiere decisión

La decisión aprobada debía seleccionar una política reproducible que determinara:

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

## Política candidata considerada

**ANTECEDENTE NO NORMATIVO DE ADR-002 v0.2.0**

Identificador histórico:
`ADR002-KEY-POLICY-CANDIDATE-v1`.

Esta sección conserva la propuesta técnica que fue sometida a evaluación. Sus
formulaciones describen el estado previo a la decisión del investigador. Cuando
exista una diferencia entre esta sección y `## Resolución aprobada`, prevalece
la resolución aprobada de ADR-002 v0.3.0.

La candidata no autorizó por sí sola implementación, métricas, claves, tags o
vectores. Su contenido se conserva para auditar las alternativas consideradas,
los riesgos identificados y la evolución de la decisión.

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

### 11. Efecto histórico de la candidata

En ADR-002 v0.2.0, incorporar la candidata no aprobó la decisión, no desbloqueó
`MEC-A1`, no autorizó implementación y no generó claves, tags o vectores.

ADR-002 v0.3.0 sustituye ese estado pendiente mediante la resolución aprobada
registrada posteriormente. Los permisos derivados, límites y bloqueos vigentes
se encuentran exclusivamente en `## Consecuencias de la decisión seleccionada`.


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

## Recomendación técnica no vinculante considerada

La recomendación de ADR-002 v0.2.0 propuso una clave por ledger, material opaco
de 32 octetos, `key_id` opaco de 16 octetos, resolución conjunta de
`ledger_id` y `key_id`, y provisión previa en memoria.

La recomendación fue considerada y modificada por el investigador. La decisión
vigente no se limita a seleccionar el alcance por ledger: también congela la
creación de una nueva relación para cada nueva unidad experimental y la
continuidad de esa relación durante todo el ciclo de vida del artefacto.

## Resolución aprobada

### Alcance seleccionado

Se selecciona la alternativa B como alcance normativo: cada instancia lógica de
ledger posee una clave HMAC independiente. Ninguna clave puede proteger dos
`ledger_id` distintos.

Para los tratamientos que instancien `MEC-A1`, cada unidad experimental
completa, tal como la defina el plan experimental aprobado, crea:

- una instancia lógica y de almacenamiento independiente de ledger;
- un nuevo `ledger_id`;
- un nuevo `key_id`;
- una nueva clave HMAC aleatoria de 32 octetos;
- una nueva asociación `(ledger_id, key_id) -> key_bytes`.

Dos unidades experimentales distintas de `MEC-A1` no comparten una clave,
aunque utilicen el mismo dataset lógico. Los tratamientos que no utilizan HMAC
no reciben material de clave por efecto de este ADR.

### Continuidad durante el ciclo de vida

La asociación permanece invariable durante todas las fases autorizadas de la
misma unidad experimental:

1. creación y preparación del ledger;
2. inserción de registros;
3. cierre del proceso legítimo;
4. manipulación o ataque offline autorizado;
5. reapertura del mismo artefacto;
6. verificación y eventual reverificación;
7. cierre definitivo de la unidad experimental.

Cerrar o reiniciar la aplicación, cambiar de fase o reabrir el mismo archivo no
crea una nueva unidad y no genera una clave nueva.

Una nueva unidad experimental no se crea reasignando un `ledger_id`, un
`key_id` o una clave a una copia ya autenticada. Debe instanciarse desde el
dataset lógico autorizado, con nueva identidad y nueva asociación, y sus tags
deben calcularse bajo esa identidad desde el inicio.

Una copia utilizada únicamente como artefacto atacado dentro del ciclo de la
misma unidad conserva el `ledger_id`, el `key_id` y la clave esperados para que
pueda evaluarse la verificación.

### Aislamiento experimental

La política exige aislamiento criptográfico y operativo entre unidades. Un
fallo de configuración, provisión o resolución en una unidad no debe modificar
la asociación ni el estado de las demás.

El uso de claves distintas evita una causa secreta compartida, pero no demuestra
por sí solo independencia estadística. La aleatorización, el orden de ejecución,
la limpieza de estado, las cachés, el hardware y demás controles pertenecen al
plan experimental.

### Material e identificación

- algoritmo: HMAC-SHA-256;
- clave: exactamente 32 octetos opacos generados por una fuente
  criptográficamente segura;
- `key_id`: exactamente 16 octetos opacos y no secretos;
- el `key_id` no deriva de la clave y no la sustituye;
- la relación autorizada se resuelve mediante
  `(ledger_id, key_id) -> key_bytes`;
- una colisión de `key_id` dentro de la campaña invalida la preparación de la
  unidad.

### Provisión y continuidad autorizada

Protector y verificador deben poder obtener la misma asociación durante todo el
ciclo de vida mediante un proveedor autorizado fuera de la capacidad de
`THR-P1`.

Durante el ciclo de vida autorizado de una unidad de `MEC-A1`, la clave
activa y cualquier material que permita reconstruirla pueden existir únicamente
en memoria de procesos legítimos autorizados y no se persisten.

La continuidad entre creación, cierre, ataque offline, reapertura y verificación
debe conservar la misma asociación únicamente en memoria autorizada durante la
unidad experimental completa. La pérdida de esa asociación no autoriza
regenerar, derivar o sustituir silenciosamente la clave.

La clave y el material reconstructivo no se persisten en ningún soporte,
incluidos keystores, contenedores, archivos, bases de datos o servicios locales
o remotos. En particular, no pueden aparecer en:

- SQLite;
- WAL;
- SHM;
- manifests;
- resultados;
- evidencia;
- logs.

Tampoco pueden registrarse, incorporarse a la evidencia ni almacenarse dentro
del dominio local restaurable:

- passphrases o secretos de desbloqueo;
- semillas recuperables;
- secretos maestros;
- material derivador equivalente.

ADR-002 v0.3.0 no selecciona la topología o API del proveedor experimental. Una
futura política de persistencia requeriría una decisión científica separada y no
está autorizada por esta versión.

### Medición

La generación, derivación, desbloqueo, lectura y carga de claves se realizan
antes de `append-hot` y `verify-hot`. La política de provisión no se incluye
silenciosamente en una métrica que presuponga la clave precargada.

### Fallos

La precedencia aprobada es:

1. material o configuración inválidos impiden iniciar la unidad;
2. una pareja `(ledger_id, key_id)` ausente produce exclusivamente
   `UNKNOWN_KEY`;
3. esto incluye un `key_id` conocido para otro ledger;
4. `INVALID_TAG` solo puede producirse después de resolver una clave válida de
   32 octetos;
5. un tag válido puede continuar a la evaluación del contexto secuencial cuando
   ADR-001 lo defina.

### Rotación

La rotación queda fuera del alcance de ADR-002 v0.3.0. Cada instancia de ledger
utiliza una sola asociación durante su ciclo de vida experimental. No se
aprueban épocas, claves históricas, migración o selección de claves antiguas.

### Reproducibilidad y vectores

La reproducibilidad experimental se basa en el procedimiento, versiones y
metadatos no secretos, no en publicar las claves experimentales.

Los futuros vectores de conformidad podrán utilizar una clave fija pública
marcada `TEST KEY — NOT SECRET — NOT FOR EXPERIMENTAL RUNS`. Esa clave no podrá
usarse en corridas experimentales.

## Estado decidido de las alternativas

| Alternativa | Estado decidido | Papel |
|---|---|---|
| A — clave global | `REJECTED` | Comparte una causa secreta entre todas las unidades y amplía el impacto de fallos o exposición. |
| B — clave por ledger | `SELECTED_SCOPE` | Define el objeto lógico propietario de la clave. |
| C — clave por dataset | `REJECTED` | Puede compartir una clave entre tratamientos, escenarios o repeticiones que usan el mismo dataset. |
| D — clave por ejecución | `SELECTED_INSTANTIATION_RULE` | Se acepta únicamente cuando “ejecución” significa una unidad experimental completa de `MEC-A1`, tal como la defina el plan experimental aprobado; no significa apertura, proceso o fase. |

Los valores de la tabla describen exclusivamente el papel decidido dentro de
ADR-002 y no crean nuevos estados documentales generales.


## Decisión del investigador

Se aprueba ADR-002 versión 0.3.0 con la resolución registrada en este
expediente.

La decisión selecciona una clave HMAC independiente por instancia lógica de
ledger y una nueva asociación para cada nueva unidad experimental que instancie
`MEC-A1`. La relación permanece estable durante cierre, ataque offline,
reapertura, verificación y reverificación del mismo artefacto.

La reapertura del mismo ledger no constituye una ejecución independiente y no
genera una clave nueva. Cada nueva unidad experimental completa que instancie
`MEC-A1`, conforme al plan experimental aprobado, recibe nuevo `ledger_id`,
nuevo `key_id` y nueva clave.

Decidido por: Alan Espinoza

Fecha de aprobación: 2026-08-02

## Consecuencias de la decisión seleccionada

### Consecuencias positivas

- aislamiento de material secreto entre unidades experimentales;
- correspondencia inequívoca entre ledger, identificador y clave;
- continuidad verificable durante todo el ciclo de vida del artefacto;
- separación entre datos lógicos compartidos y fronteras secretas independientes;
- clasificación consistente de fallos de configuración, `UNKNOWN_KEY` e
  `INVALID_TAG`;
- compatibilidad con la exclusión de claves activas establecida por `THR-P1`;
- exclusión de generación y carga de las regiones que presuponen clave lista;
- reproducibilidad del procedimiento sin publicar secretos experimentales.

### Limitaciones

- la política no garantiza por sí sola independencia estadística;
- no protege frente al compromiso del proceso legítimo;
- no cubre core dumps, swap, depuración privilegiada o lectura de memoria;
- no define almacenamiento productivo, zeroization garantizada ni recuperación
  comercial de secretos;
- no ofrece confidencialidad;
- no proporciona seguridad después del compromiso de la clave;
- no detecta por sí sola rollback completo;
- no aprueba rotación;
- no congela todavía una API, schema, formato de almacenamiento o proveedor.

### Trabajo derivado autorizado

Esta decisión autoriza preparar, en tareas posteriores y separadas:

- una especificación derivada del proveedor experimental de claves;
- reglas de ciclo de vida y reprovisión del harness;
- casos de prueba para aislamiento, asociación cruzada y continuidad;
- armonización de `docs/06-mechanism-specifications.md`;
- armonización de `docs/13-harness-architecture.md`;
- armonización de `docs/16-traceability-matrix.csv`;
- un plan de vectores HMAC después de resolver la codificación autenticada de
  ADR-001.

Cada tarea requiere su propio alcance, manifest, revisión y autorización. Esta
aprobación no autoriza modificar esos documentos dentro de este cambio.

### Dependencias resueltas y bloqueos vigentes

La dependencia científica de política de claves representada por ADR-002 queda
resuelta.

No obstante:

- `MEC-A1` permanece `BLOCKED` porque ADR-001 continúa `DRAFT` y todavía no
  existe una tarea de implementación autorizada;
- los vectores HMAC completos permanecen bloqueados hasta aprobar ADR-001;
- `MET-APPEND-READY-E2E` permanece `BLOCKED` por ADR-003;
- no se autorizan corridas experimentales oficiales;
- no se autorizan resultados de seguridad o rendimiento;
- no se generan claves, tags o vectores en esta tarea;
- la fusión del cambio documental no constituye implementación.



## Documentos afectados

- `docs/04-threat-model.md`
- `docs/06-mechanism-specifications.md`
- `docs/11-measurement-contract.md`
- `docs/13-harness-architecture.md`
- `docs/16-traceability-matrix.csv`
- `docs/decisions/README.md`
- futuros planes experimentales y esquemas de evidencia, cuando sean autorizados

## Identificadores de trazabilidad

- `RQ-01`
- `MEC-A1`
- `THR-P1`
- `ADR-002`
