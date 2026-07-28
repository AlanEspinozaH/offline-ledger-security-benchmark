---
decision_id: ADR-002
title: Key scope and provisioning
version: 0.1.0
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

## Alternativas concretas para el alcance de clave

### Alternativa A — Clave global del benchmark

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

Cada `ledger_id` recibe una clave; la misma clave puede reutilizarse al repetir
operaciones sobre ese ledger conforme al protocolo.

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

## Decisiones adicionales de la política

| Dimensión | Alternativas defendibles | Ventajas y desventajas | Consecuencia normativa |
|---|---|---|---|
| Tamaño mínimo | exactamente 256 bits; al menos 256 bits con tamaños admitidos congelados | El tamaño exacto simplifica conformidad. Un mínimo permite proveedores distintos, pero puede introducir variación. | Deben definirse unidad, generador, tamaños aceptados y rechazo de claves cortas antes de medir. |
| Formato de `key_id` | UUID aleatorio; huella pública truncada de la clave; identificador opaco estructurado por alcance | El UUID no revela relación criptográfica, pero necesita registro. La huella detecta errores, pero revela igualdad y exige longitud. El estructurado ayuda a auditar, pero puede filtrar metadatos y acoplar formatos. | Deben fijarse codificación, longitud, sensibilidad, colisiones y ámbito de unicidad. `key_id` nunca sustituye a la clave. |
| Unicidad de `key_id` | global al experimento; única por proveedor; única solo dentro del ledger o ejecución | Un ámbito global simplifica evidencia, pero exige coordinación. Ámbitos menores reducen coordinación, pero requieren contexto para resolver. | Toda evidencia y toda API futura deben declarar el ámbito aprobado y tratar colisiones como fallo estructurado. |
| Provisión al protector | clave inyectada en memoria antes de medir; puerto de proveedor consultado antes de medir; contenedor local cifrado desbloqueado mediante secreto externo | La inyección es simple, pero exige disciplina de ciclo de vida. El proveedor desacopla política, pero añade una abstracción. El contenedor prueba restaurabilidad opaca, pero añade carga y desbloqueo. | La región medida debe comenzar solo después de obtener la clave; deben registrarse fallos de provisión fuera de la métrica correspondiente. |
| Provisión al verificador | misma instancia autorizada; proveedor independiente con la misma clave; contenedor cifrado desbloqueado fuera del dominio local | Compartir instancia reduce complejidad, pero prueba menos separación. Un proveedor independiente modela mejor la frontera, pero aumenta configuración. El contenedor conserva estado local opaco, pero depende de un secreto externo. | Protector y verificador deben resolver el mismo `key_id` sin inferir ni regenerar claves dentro de `verify-hot`. |
| Almacenamiento y frontera | solo memoria del proceso legítimo; contenedor cifrado local más secreto externo; proveedor experimental fuera del dominio restaurable | Solo memoria minimiza persistencia, pero no modela reinicios. El contenedor permite reinicio, pero su seguridad depende del desbloqueo. El proveedor separa dominios, pero puede ampliar el montaje experimental. | En todas las opciones, los bytes activos y secretos de desbloqueo quedan fuera de lectura por `THR-P1`; el snapshot puede contener como máximo material cifrado opaco y `key_id`. |
| Rotación | fuera de alcance; un tratamiento experimental separado; incluida en todas las ejecuciones | Excluirla reduce variables. Separarla permite estudiarla sin contaminar el caso base. Incluirla mejora cobertura, pero requiere periodos, selección histórica y errores adicionales. | Si no se aprueba expresamente, no puede asumirse rotación. Si se incluye, deben definirse vigencia, historial de `key_id` y efecto sobre verificabilidad. |
| Reproducibilidad | aleatoriedad nueva y procedimiento reproducible; derivación determinista desde un secreto maestro externo y etiqueta pública; claves fijas solo para vectores de conformidad | La aleatoriedad evita reutilización, pero cambia tags. La derivación repite resultados, pero el maestro es sensible y la separación de etiquetas debe probarse. Los vectores fijos son auditables, pero no representan secretos experimentales. | La evidencia puede registrar algoritmo, tamaño, proveedor y `key_id`, nunca la clave o una semilla que permita recuperarla. Las claves de prueba no deben reutilizarse en corridas experimentales. |

## Riesgos

- guardar una clave activa o passphrase en el dominio legible por `THR-P1`;
- registrar una semilla “reproducible” que permita reconstruir la clave;
- incluir generación, derivación o carga en una región que presupone clave lista;
- usar `key_id` con colisiones o con un ámbito no documentado;
- reutilizar una clave global y confundir dependencia compartida con repetición;
- convertir este ADR en un diseño de gestión de secretos productivo fuera de PT2;
- incluir rotación sin definir selección de claves históricas y sus fallos.

## Recomendación técnica no vinculante

Conviene evaluar las alternativas privilegiando aislamiento explícito,
`key_id` opaco y provisión previa a las regiones medidas. Cualquier alternativa
aprobada debe demostrar que `THR-P1` puede copiar los artefactos locales sin
obtener los bytes activos ni el secreto que los desbloquea.

Para reproducibilidad, es preferible registrar el procedimiento y metadatos no
secretos antes que publicar material capaz de regenerar claves. Esta
recomendación no selecciona alcance, tamaño, formato de `key_id`, proveedor,
rotación ni estrategia de aleatoriedad.

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING. `MEC-A1` permanece `BLOCKED`; no se autoriza provisión, generación,
derivación, almacenamiento ni rotación concreta.

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
