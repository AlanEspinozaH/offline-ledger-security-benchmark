---
decision_id: ADR-001
title: Authenticated encoding v1
version: 0.3.0
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-001 — Codificación autenticada v1

## Estado y alcance del expediente

Este expediente congela una propuesta técnica concreta para los bytes que
podría autenticar MEC-A1. ADR-001 permanece `DRAFT` y la decisión del
investigador permanece `PENDING`.

La selección del finalista y todas las reglas del perfil se marcan
**CANDIDATO NO NORMATIVO**. No constituyen aprobación, no definen bytes
normativos, no crean un schema normativo, no autorizan implementación productiva
y no desbloquean MEC-A1. Esta tarea tampoco genera bytes, vectores ni
codificadores.

## Contexto

MEC-A1 autentica una secuencia exacta de bytes. Productor y verificador deben
obtener los mismos bytes desde el mismo registro lógico sin depender de
lenguaje, locale, plataforma, orden accidental de contenedores ni valores
predeterminados de bibliotecas.

`docs/05-record-format.md` exige una codificación inequívoca de `domain`,
`schema_version`, `mechanism_version`, `ledger_id`, `sequence` y el payload
lógico. `docs/06-mechanism-specifications.md` mantiene MEC-A1 con implementación
`BLOCKED`. Esta propuesta no modifica esos documentos.

RFC 8949 define CBOR y requisitos de codificación determinista, pero cada
protocolo debe cerrar su modelo, límites y condiciones de rechazo. RFC 8785
define JCS sobre I-JSON. Ninguna referencia externa ni esta propuesta sustituyen
la aprobación expresa del investigador.

## Problema exacto que requiere decisión

Antes de aprobar ADR-001, el investigador deberá evaluar un perfil completo que
determine:

- modelo lógico y tipos admitidos;
- estructura exterior y extensibilidad;
- representación única de cada campo;
- separación de dominio y versionado;
- políticas Unicode, temporal y numérica;
- límites y condiciones de rechazo;
- conducta ante CBOR válido pero fuera del perfil o no determinista;
- nombres separados para el valor lógico y los bytes autenticados;
- relación entre autenticación de `sequence` y validación contextual;
- validación independiente mediante vectores byte a byte.

Esta versión congela una propuesta verificable para revisión y posible
experimentación. No resuelve la decisión científica, que continúa `PENDING`.

## Distinción obligatoria sobre secuencia

Deben permanecer separadas tres propiedades:

1. `sequence` forma parte del mensaje autenticado; un tag válido demuestra que
   ese valor fue autenticado, no que sea el valor esperado.
2. Inicio, huecos, duplicados o reordenamiento requieren comparar el valor con un
   contexto secuencial explícito.
3. Ni un tag válido ni la continuidad interna demuestran que el último registro
   presentado sea el extremo terminal vigente.

`INVALID_TAG` se reserva para un fallo criptográfico.
`INVALID_SEQUENCE_CONTEXT` describe un fallo de política contextual y no prueba
falsificación.

## Criterios conceptuales de evaluación

Las alternativas se conservan bajo los mismos criterios conceptuales:

- inyectividad práctica y determinismo;
- independencia de lenguaje y facilidad de producir vectores byte a byte;
- complejidad del verificador y rechazo de formas no canónicas;
- tratamiento de int64, tiempo, identificadores binarios y Unicode;
- objetos, listas, duplicados, nulos y coma flotante;
- versionado, separación de dominio, tamaño y dependencia de bibliotecas;
- validación cruzada independiente.

## Alternativas evaluadas y clasificación provisional

### Alternativa A — Perfil binario propio

**Alternativa evaluada no finalista.** Un formato propio con posiciones fijas o
TLV puede ser compacto e inyectivo, pero PT2 tendría que especificar y validar
cada ancho, signo, endianess, prefijo de longitud, orden, duplicado, límite y
regla de extensión. El parser podría ser pequeño, pero toda la seguridad del
framing, overflow, truncamiento y contenido sobrante quedaría a cargo del
proyecto.

A conserva ventajas de tamaño predecible, enteros naturales y trazas
hexadecimales simples. Su riesgo dominante es el framing inventado, junto con el
costo de dos implementaciones independientes y vectores exhaustivos para un
modelo recursivo propio. Por ese riesgo y costo permanece evaluada, pero no se
producirán sus bytes candidatos completos en la siguiente etapa.

### Alternativa B — Perfil CBOR determinista restringido

**Único perfil candidato finalista.** CBOR ofrece enteros binarios, arrays y
mapas, representaciones compactas y reglas deterministas estandarizadas. El
perfil PT2 aún debe ser más estricto que CBOR genérico para excluir tipos,
representaciones y opciones no necesarias.

Su riesgo dominante es aceptar opciones CBOR no cerradas o utilizar un decoder
que pierda duplicados o no canonicalidad. La propuesta concreta se define en
`Perfil candidato finalista`. La clasificación es técnica, no vinculante y puede
cambiar mientras ADR-001 siga `DRAFT`.

### Alternativa C — Perfil JCS restringido

**Alternativa evaluada no finalista.** JCS aporta texto legible, serialización
UTF-8 y orden recursivo determinista, pero JSON no posee un tipo entero separado
y JCS serializa JSON number conforme a binary64. El rango int64 completo exige
convenciones adicionales, como cadenas decimales con gramática cerrada o una
selección por campo entre número seguro y cadena.

C conserva ventajas de legibilidad y disponibilidad de parsers. Sus riesgos
dominantes son pérdida numérica, aceptación de propiedades duplicadas y
convenciones textuales adicionales para int64, tiempo e identificadores. Debido
a esas convenciones para int64 y JSON number permanece evaluada, pero no se
producirán sus bytes candidatos completos en la siguiente etapa.

### Comparación resumida

| Dimensión | A — Binario propio | B — CBOR restringido | C — JCS restringido |
|---|---|---|---|
| Inyectividad | Depende totalmente del framing PT2 | Alta con modelo y tipos cerrados | Alta si cada campo tiene un único tipo |
| Determinismo | Debe especificarse por completo | Formas mínimas y orden CBOR seleccionado | JCS fija serialización; PT2 fija tipos |
| Independencia de lenguaje | Posible, con control manual de overflow | Buena, sujeta a decoders estrictos | Buena, sujeta a precisión y orden JCS |
| Vectores | Directos, pero requieren codec propio independiente | Compactos y contrastables entre bibliotecas | Legibles; deben compararse bytes UTF-8 |
| Verificador | Parser y validación propios | Biblioteca más validación estricta del perfil | Parser I-JSON más validación PT2 |
| int64 | Natural si se congelan ancho y signo | Natural dentro de rangos cerrados | Requiere convención fuera de binary64 seguro |
| Tiempo | Entero o texto propio por definir | Entero candidato sin tag | Convención numérica o textual adicional |
| Identificador | Bytes o texto propio por definir | Byte string candidato de 16 octetos | Convención textual adicional |
| Unicode | UTF-8 y política totalmente propias | UTF-8 con política explícita | JCS preserva texto; parser debe ser estricto |
| Estructuras | Gramática recursiva propia | Arrays y mapas nativos restringidos | Arrays y objetos nativos restringidos |
| Duplicados | Rechazo implementado por PT2 | Decoder debe detectarlos antes de perderlos | Parser debe detectarlos antes de perderlos |
| Null y float | Decisión y tags propios | Excluidos por el candidato | JSON los admite; el perfil tendría que cerrarlos |
| Versionado y dominio | Cabecera o framing propios | Posiciones exteriores candidatas fijas | Propiedad o framing exterior adicional |
| Tamaño | Potencialmente menor | Compacto | Generalmente mayor |
| Bibliotecas | Poca dependencia, más código propio | Varias implementaciones disponibles | Ecosistema amplio, JCS no siempre disponible |
| Validación cruzada | Requiere crearla | Favorable entre bibliotecas o lenguajes | Posible entre implementaciones JCS |

B pasa a ser el único finalista propuesto. A y C permanecen como alternativas
conceptualmente evaluadas no finalistas. La clasificación puede modificarse
mientras ADR-001 siga `DRAFT`, no equivale a aprobación del investigador y no
convierte futuros bytes en normativos.

## Perfil candidato finalista

> **CANDIDATO NO NORMATIVO**

El identificador exacto del perfil propuesto es
`PT2-CBOR-AUTH-RECORD-CANDIDATE-v1`. Todas las reglas de esta sección son
candidatas, no aprobadas y sujetas a cambio.

### Nombres candidatos y modelo lógico

- `record_payload_v1`: valor lógico formado por `event_type`, `occurred_at`,
  `operator_id`, `amount_cents` y `payload`;
- `authenticated_record_bytes_v1`: secuencia de bytes producida por la
  codificación candidata del array exterior completo.

Los nombres siguen siendo candidatos. El primero designa un valor lógico; el
segundo, el mensaje autenticado exterior completo. No son sinónimos.

### Estructura exterior cerrada y responsabilidades de versionado

`authenticated_record_bytes_v1` se propone como la codificación CBOR de un
array de longitud exacta 10, nunca como un mapa exterior:

| Posición | Elemento |
|---:|---|
| 0 | `domain` |
| 1 | `schema_version` |
| 2 | `mechanism_version` |
| 3 | `ledger_id` |
| 4 | `sequence` |
| 5 | `event_type` |
| 6 | `occurred_at` |
| 7 | `operator_id` |
| 8 | `amount_cents` |
| 9 | `payload` |

No se permiten campos adicionales, posiciones ausentes ni arrays de longitud
distinta. Productor y verificador no ignoran elementos exteriores desconocidos.
Los elementos de `payload` siempre quedan autenticados aunque su semántica sea
validada por el schema. Esta tarea no genera los bytes CBOR del array.

Las responsabilidades candidatas de versionado se separan así:

- `schema_version` gobierna la semántica del registro lógico, incluidos
  `event_type` y `payload`;
- la versión del perfil candidato y `mechanism_version` gobiernan el array
  exterior, `domain`, los tipos exteriores, las reglas CBOR y
  `authenticated_record_bytes_v1`;
- `PT2-CBOR-AUTH-RECORD-CANDIDATE-v1` acepta únicamente
  `schema_version = 1` y `mechanism_version = 1`;
- modificar el array exterior, sus posiciones, `domain` o las reglas CBOR
  requiere una nueva versión del perfil y reconciliarla expresamente con
  `mechanism_version`;
- una nueva `schema_version` no puede cambiar implícitamente el array exterior;
- una futura `schema_version` deberá ser admitida expresamente por una nueva
  revisión del perfil, incluso si conserva la misma forma exterior;
- no se infiere compatibilidad entre versiones.

### Sobre candidato estable para descubrimiento de versión

Dentro de la familia `PT2-CBOR-AUTH-RECORD-CANDIDATE`, las siguientes reglas son
**CANDIDATO NO NORMATIVO**. Antes del despacho de versión se determina primero
la estructura lógica mínima:

- los bytes contienen exactamente un elemento CBOR;
- el elemento exterior es un array CBOR;
- el array contiene como mínimo las posiciones 0, 1 y 2;
- la posición 0 es `domain`, con tipo CBOR text string;
- la posición 1 es `schema_version`, entero CBOR no negativo;
- la posición 2 es `mechanism_version`, entero CBOR no negativo.

Esta comprobación lógica no exige todavía que el array use longitud definida.
En una fase separada, todavía anterior al despacho, se comprueban las
invariantes de canonicalidad del sobre candidato:

- el array exterior usa longitud definida;
- su longitud está codificada mínimamente;
- `domain` usa representación determinista;
- los campos de versión usan representación mínima, sin tags ni
  representaciones alternativas.

La longitud definida continúa siendo una invariante del sobre candidato, pero
su incumplimiento se clasifica como canonicalidad, no como falta de pertenencia
lógica. Un array exterior de longitud indefinida con exactamente los diez
elementos lógicos admitidos por v1 produce
`MALFORMED_RECORD / NON_CANONICAL_ENCODING`, no
`MALFORMED_RECORD / ENCODING_PROFILE_VIOLATION`.

Estas comprobaciones todavía no exigen que el array tenga longitud 10, no
validan el literal exacto de `domain` y no aplican tipos, límites, orden de mapas
ni otras reglas propias de v1 al resto del registro. El literal exacto de
`domain`, la longitud exacta 10 y las demás reglas de
`PT2-CBOR-AUTH-RECORD-CANDIDATE-v1` solo se verifican después de determinar que
las versiones son soportadas.

Una futura versión de esta familia debe conservar este sobre de descubrimiento.
Una versión que necesite mover esos campos o usar otra estructura requerirá una
familia o mecanismo de despacho diferente y una nueva decisión expresa.

### Separación de dominio candidata

La posición 0 es un CBOR text string cuyo contenido ASCII exacto es:

`PT2:MEC-A1:HMAC-SHA-256:RECORD:v1`

Se codifica como UTF-8, sin terminador NUL y sin espacios. No se selecciona
durante ejecución y se relaciona de forma fija con `mechanism_version = 1`.
El literal continúa como **CANDIDATO NO NORMATIVO**.

### Tipos y rangos exteriores candidatos

| Campo | Tipo y restricciones candidatas |
|---|---|
| `schema_version` | Entero CBOR no negativo, valor inicial 1 y representación mínima. Se rechaza otro valor mientras el perfil sea v1. |
| `mechanism_version` | Entero CBOR no negativo, valor inicial 1 y representación mínima. Se rechaza otro valor mientras el perfil sea v1. |
| `ledger_id` | CBOR byte string de exactamente 16 octetos, identificador binario opaco. No admite texto alternativo ni tags. |
| `sequence` | Entero CBOR positivo en `1..2^63-1`, con representación mínima. Cero y negativos son inválidos. |
| `event_type` | CBOR text string no vacío de 1 a 64 octetos UTF-8. Su enumeración pertenece al schema. |
| `occurred_at` | Entero CBOR en `0..253402300799999`, milisegundos UTC desde Unix epoch. No admite texto ni tag temporal. |
| `operator_id` | CBOR text string no vacío de hasta 128 octetos UTF-8. |
| `amount_cents` | Entero con signo en `-9223372036854775808..9223372036854775807`, con representación mínima. Prohibidos float y texto. |
| `payload` | CBOR map sujeto al modelo recursivo y límites siguientes. |

La unidad de `occurred_at` no se infiere por magnitud. No se redondea ni trunca
silenciosamente: el valor lógico debe llegar ya expresado en milisegundos
enteros.

El valor lógico entregado al codec para `ledger_id` es exactamente una secuencia
opaca de 16 octetos. Cualquier lectura de UUID textual, eliminación de guiones,
interpretación de campos UUID, elección de endianess o conversión desde una
clase UUID del lenguaje ocurre antes del codec y no forma parte de
`authenticated_record_bytes_v1`. Esta propuesta no define una conversión
normativa desde texto UUID.

El límite candidato `253402300799999` de `occurred_at` corresponde al último
milisegundo del año 9999 UTC y funciona como límite operacional candidato.

### Payload candidato

Las claves de todo map son CBOR text string no vacíos de hasta 128 octetos
UTF-8, únicas y sin normalización implícita. La codificación no decide qué
nombres de aplicación son válidos; esa validación pertenece a
`schema_version`.

Los valores permitidos recursivamente son:

- text string;
- int64;
- boolean;
- array;
- map con claves textuales.

Se permiten cadenas, arrays y mapas vacíos cuando el schema lo permita. Se
prohíben `null`, `undefined`, float, byte string, tags, bignums, simple values
distintos de boolean y claves no textuales. No se permiten coerciones entre
tipos.

### Política Unicode candidata

El perfil preserva la secuencia de valores escalares Unicode y la codifica como
UTF-8 sin normalización. Rechaza UTF-8 inválido y sustitutos aislados. Considera
distintas U+00E9 y la secuencia U+0065 U+0301, aunque sean visualmente
similares. Productor y verificador no transforman silenciosamente el texto.
Esta es una decisión candidata, no aprobada.

### Reglas CBOR deterministas candidatas

- todas las longitudes son definidas;
- enteros y longitudes usan representación mínima;
- tags, bignums y coma flotante están prohibidos;
- los mapas tienen claves únicas, detectadas antes de perder entradas;
- todo map dentro de `payload` usa `core deterministic encoding`: sus claves se
  ordenan lexicográficamente, byte a byte, por sus codificaciones deterministas;
- `length-first deterministic ordering` no pertenece al perfil;
- no se permiten bytes sobrantes después del único elemento exterior;
- profundidad, cardinalidades, longitudes y tamaño total se comprueban antes de
  aceptar el registro.

El array exterior tiene orden posicional y no requiere orden de mapa.

Todas las claves permitidas por el perfil son CBOR text strings. Para ese
subconjunto, core deterministic y length-first producen el mismo orden
observable. La conformidad se define por los bytes candidatos exactos, no por la
configuración interna ni por el nombre de una rutina de biblioteca. Una
implementación que produzca esos bytes exactos no se rechaza solo porque use
internamente una rutina denominada length-first. `core deterministic encoding`
se mantiene como la regla candidata del perfil.

### Límites candidatos

| Límite | Valor candidato |
|---|---:|
| Tamaño máximo de `authenticated_record_bytes_v1` | 65536 octetos |
| Profundidad máxima dentro de `payload` | 8 |
| Elementos máximos por array | 256 |
| Pares máximos por map | 256 |
| Text string general | 16384 octetos UTF-8 |
| Clave de map | 128 octetos UTF-8 |
| `event_type` | 64 octetos UTF-8 |
| `operator_id` | 128 octetos UTF-8 |

La raíz map de `payload` tiene profundidad 1; cada array o map anidado incrementa
la profundidad en uno y los escalares no la incrementan. Los límites se cuentan
en octetos UTF-8 o elementos según corresponda, nunca en unidades dependientes
del lenguaje. Son límites candidatos sujetos a validación con datos reales del
benchmark.

### Taxonomía candidata de errores de codificación

Todos los rechazos de esta sección conservan el estado superior existente
`MALFORMED_RECORD`. Los detalles estables candidatos son:

#### `MALFORMED_CBOR`

Datos que no constituyen exactamente un elemento CBOR bien formado, incluidos
truncamiento, cabecera incompleta, una longitud que excede los bytes disponibles,
break inesperado o bytes sobrantes después del único elemento exterior esperado.

#### `INVALID_CBOR`

Un elemento CBOR bien formado pero inválido conforme a las restricciones
básicas de CBOR o de tags, excepto claves duplicadas. Incluye UTF-8 inválido
dentro de un text string, sustitutos aislados representados en una secuencia no
válida, contenido inválido de un tag reconocido u otra violación de validez
básica identificada antes de aplicar el perfil PT2. Un tag CBOR válido pero
prohibido por PT2 continúa siendo `ENCODING_PROFILE_VIOLATION`.

#### `DUPLICATE_MAP_KEY`

Una clave duplicada es una condición de validez CBOR básica que se expone con
este detalle específico y nunca se degrada a `INVALID_CBOR`. El parser o adapter
que procese `raw_bytes` debe preservar todos los pares de mapas o devolver una
señal específica de clave duplicada. Si una biblioteca estricta rechaza el
elemento por duplicación durante su validación básica, el adapter mapea el error
a `MALFORMED_RECORD / DUPLICATE_MAP_KEY`, no a
`MALFORMED_RECORD / INVALID_CBOR`. Un decoder que descarte silenciosamente una
ocurrencia no es apto para validar bytes adversariales del perfil candidato.

#### `ENCODING_PROFILE_VIOLATION`

Un elemento CBOR bien formado y válido, pero fuera del modelo PT2, incluidos
tipo prohibido, tag, bignum, float, `null`, byte string dentro de `payload`,
clave no textual, array exterior de longitud diferente de 10, rango lógico
excedido o profundidad o cardinalidad excedida. Las versiones enteras
desconocidas no pertenecen a esta categoría.

#### `NON_CANONICAL_ENCODING`

Un valor admitido por el perfil que usa bytes no deterministas, incluidos entero
o longitud con representación no mínima, longitud indefinida, mapas con orden
incorrecto u otra representación CBOR alternativa del mismo valor permitido.

No se crean estados superiores nuevos. Una recodificación se permite solo para
diagnóstico y nunca convierte una entrada rechazada en aceptada. Cuando se
valida una representación recibida, la aceptación exige coincidencia byte a
byte con la recodificación determinista candidata.

### Tratamiento candidato de versiones no admitidas

#### `MALFORMED_RECORD` / `ENCODING_PROFILE_VIOLATION`

Este resultado se usa cuando `schema_version` o `mechanism_version` tienen un
tipo CBOR incorrecto, el entero está fuera del rango lógico admitido para un
identificador de versión, faltan las posiciones de versión o la estructura
impide leer inequívocamente ambos campos.

#### `UNSUPPORTED_VERSION`

Este estado superior existente se usa cuando el campo es un entero CBOR bien
formado y determinista y la estructura permite identificar la versión, pero el
valor no está soportado por el verificador. Se aplica tanto a una
`schema_version` no soportada como a una `mechanism_version` no soportada.

`UNSUPPORTED_VERSION` no está subordinado a `MALFORMED_RECORD` y no es un estado
nuevo: ya forma parte de MEC-A1 en `docs/06-mechanism-specifications.md`. Cuando
una versión es desconocida no se interpreta el resto con reglas de v1; solo se
aplican las comprobaciones genéricas de CBOR y del sobre estable necesarias para
reconocer de forma segura sus campos de versión.

### Frontera conceptual entre valores lógicos y bytes recibidos

Esta propuesta distingue cuatro interfaces conceptuales sin implementar código.

#### `encode_record(logical_record)`

- recibe el registro lógico ya tipado;
- valida estructura, tipos, rangos y límites lógicos;
- produce directamente `authenticated_record_bytes_v1`;
- no recibe ni produce `key_id`, `tag` o contexto secuencial;
- es la ruta aplicable cuando se leen columnas lógicas de SQLite.

#### `validate_encoded_record(raw_bytes)`

- recibe únicamente `raw_bytes` y se limita a validar la representación
  codificada;
- ejecuta las fases 1 a 8 definidas en la sección siguiente: análisis CBOR,
  descubrimiento de versión, pertenencia al perfil y canonicalidad;
- propaga un rechazo de codificación o versión y, si todas esas fases tienen
  éxito, devuelve una estructura interna conceptual `ValidatedEncodedRecord`;
- esa estructura contiene los mismos `raw_bytes` exactos, las versiones
  identificadas, los campos exteriores interpretados, el `sequence` autenticado
  y el `payload` lógico interpretado;
- no resuelve claves, no verifica HMAC, no evalúa contexto secuencial y no
  produce por sí sola el estado superior `VALID`.

`ValidatedEncodedRecord` no crea un schema, una clase de código ni un nuevo
estado superior.

#### `verify_encoded_record(raw_bytes, tag, key_id, sequence_context: SequenceContextCandidateV1 | None = None)`

Esta interfaz conceptual representa la verificación completa cuando existen los
bytes CBOR originales:

1. llama a `validate_encoded_record(raw_bytes)`;
2. propaga cualquier resultado de codificación o versión;
3. resuelve la clave mediante el `key_id` externo;
4. verifica el `tag` externo sobre exactamente los mismos `raw_bytes`;
5. evalúa el contexto secuencial opcional usando el `sequence` autenticado;
6. produce uno de los errores existentes de MEC-A1 o `VALID` de MEC-A1 junto
   con el registro lógico autenticado necesario para validación posterior.

`tag` y `key_id` no forman parte de `authenticated_record_bytes_v1`; sus
semánticas continúan sujetas a ADR-002 y MEC-A1. `sequence_context` es una
entrada externa opcional y su ausencia no produce automáticamente
`INVALID_SEQUENCE_CONTEXT`.

#### `verify_logical_record(logical_record, tag, key_id, sequence_context: SequenceContextCandidateV1 | None = None)`

Esta interfaz conceptual se aplica cuando SQLite conserva campos lógicos y no
un blob CBOR original:

1. valida y codifica el registro mediante `encode_record(logical_record)`;
2. resuelve la clave mediante el `key_id` externo;
3. verifica el `tag` sobre los bytes deterministas recién producidos;
4. evalúa el contexto secuencial opcional;
5. devuelve uno de los errores existentes de MEC-A1 o `VALID` de MEC-A1 junto
   con el registro lógico autenticado.

Reconstruir bytes desde campos de SQLite no demuestra que una serialización
CBOR original fuera canónica. Afirmar que se rechazó una codificación no
canónica requiere disponer de los bytes originales. Por ello,
`verify_logical_record(...)` no usa `validate_encoded_record(raw_bytes)` ni
afirma nada sobre la canonicalidad de una serialización original. Ambas rutas
autentican exactamente `authenticated_record_bytes_v1`. Esta tarea no decide si
el sistema almacenará el blob CBOR. Las cuatro firmas son conceptuales: no
autorizan una API, código productivo ni una modificación de HMAC.

### Fronteras de validez y significado de `VALID`

Esta propuesta separa tres niveles conceptuales. La separación completa es
**CANDIDATO NO NORMATIVO** y no crea API, clases, schemas ni código.

#### Nivel 1 — Validez de codificación y perfil

`validate_encoded_record(raw_bytes)` es responsable de CBOR bien formado,
validez CBOR básica, duplicados, descubrimiento y soporte de versión, tipos y
rangos del perfil de codificación, límites y canonicalidad. En caso
satisfactorio devuelve `ValidatedEncodedRecord`; no devuelve `VALID`.

Este nivel no resuelve claves, no verifica HMAC ni contexto secuencial, y no
valida la enumeración de `event_type`, las reglas semánticas de `payload` ni
reglas de negocio de la aplicación.

#### Nivel 2 — Validez del mecanismo MEC-A1

`verify_encoded_record(...)` y `verify_logical_record(...)` son responsables de
la validez del mecanismo. Un resultado superior `VALID`, denominado en este ADR
**`VALID` de MEC-A1**, significa únicamente que:

1. la representación o el registro lógico satisfacen el perfil candidato;
2. `schema_version` y `mechanism_version` están soportadas por este perfil;
3. `key_id` pudo resolverse;
4. el `tag` HMAC es válido sobre los bytes autenticados exactos;
5. el contexto secuencial, cuando fue proporcionado, coincide con el registro.

`verify_encoded_record(...)` puede devolver uno de los errores existentes de
MEC-A1 o `VALID` de MEC-A1 junto con el registro lógico autenticado necesario
para una validación posterior. `verify_logical_record(...)` puede devolver los
mismos resultados y, en el caso satisfactorio, el registro lógico autenticado.
El registro junto al resultado es conceptual y no crea una clase ni un schema.

`VALID` de MEC-A1 no significa que `event_type` pertenezca a una enumeración de
aplicación, que `payload` cumpla la semántica de un evento, que existan
referencias de negocio válidas, que una venta, producto u operador sea aceptable
para la aplicación, que el registro sea el extremo terminal vigente, que no
haya ocurrido rollback ni que el contexto recibido sea fresco o confiable.

#### Nivel 3 — Validación semántica del schema de aplicación

`validate_application_schema(verified_record)` es una operación conceptual
separada y exterior a la máquina de estados de MEC-A1. Recibe únicamente un
registro que ya obtuvo `VALID` de MEC-A1, selecciona las reglas mediante el
`schema_version` autenticado, valida la enumeración de `event_type`, nombres,
presencia y semántica de campos de `payload`, y restricciones cruzadas propias
de la aplicación. Produce un resultado de aplicación separado.

ADR-001 no define la enumeración de eventos, las reglas de cada `payload`, una
taxonomía de errores de aplicación ni un schema productivo. Esas reglas
requieren un documento, schema o decisión posterior. No se crea un estado
superior adicional dentro de MEC-A1.

#### Precedencia antes del uso por la aplicación

El orden conceptual es:

1. construir o validar los bytes autenticados;
2. verificar la versión soportada;
3. resolver la clave;
4. verificar HMAC;
5. evaluar el contexto secuencial opcional;
6. producir `VALID` de MEC-A1;
7. solo después, antes de usar el registro en la aplicación, ejecutar
   `validate_application_schema`.

La aplicación no interpreta ni ejecuta semántica de negocio sobre un registro
que todavía no tenga `VALID` de MEC-A1. Autenticar primero evita utilizar
semántica de un registro no autenticado. La validación posterior del schema no
modifica los bytes ni el tag: un registro puede ser `VALID` para MEC-A1 y ser
rechazado después por el schema de aplicación, sin que el tag se vuelva inválido
ni que el fallo se convierta en `ENCODING_PROFILE_VIOLATION`, `INVALID_TAG` o
`INVALID_SEQUENCE_CONTEXT`. La aceptación final de la aplicación requiere tanto
`VALID` de MEC-A1 como un resultado satisfactorio del schema de aplicación.

#### Responsabilidad autenticada de `schema_version`

`schema_version` forma parte de `authenticated_record_bytes_v1` y gobierna la
interpretación semántica de `event_type` y `payload`. El perfil candidato v1
solo admite `schema_version = 1`; una versión desconocida produce
`UNSUPPORTED_VERSION`. Admitir el número 1 no equivale a definir en ADR-001 todas
las reglas semánticas del schema v1.

Como el selector forma parte de los bytes autenticados, no puede cambiarse sin
invalidar el HMAC. La definición efectiva y verificable del schema de aplicación
continúa pendiente.

### Precedencia candidata de verificación

`verify_encoded_record(...)` evalúa en este orden:

1. Comprueba que exista exactamente un elemento CBOR bien formado. Si falla:
   `MALFORMED_RECORD / MALFORMED_CBOR`.
2. Comprueba validez CBOR básica y de tags con enrutamiento especial. Si la
   condición detectada es una clave duplicada, produce
   `MALFORMED_RECORD / DUPLICATE_MAP_KEY`; si es otra violación de validez,
   produce `MALFORMED_RECORD / INVALID_CBOR`. La duplicación se clasifica de
   forma específica aunque la biblioteca la detecte dentro de su modo de
   validación básica.
3. Comprueba la estructura lógica mínima para descubrir las versiones: el
   elemento exterior es un array, posee al menos las posiciones 0, 1 y 2,
   `domain` es text string, y `schema_version` y `mechanism_version` son enteros
   no negativos. Todavía no comprueba longitud exacta 10, literal exacto de
   `domain`, tipos del cuerpo ni representación definida o mínima del array
   exterior. Si falla:
   `MALFORMED_RECORD / ENCODING_PROFILE_VIOLATION`.
4. Comprueba la representación determinista del sobre de descubrimiento: array
   exterior de longitud definida, longitud codificada mínimamente, `domain` y
   versiones con representaciones mínimas, y ausencia de representaciones
   alternativas en las posiciones 0 a 2. Si falla:
   `MALFORMED_RECORD / NON_CANONICAL_ENCODING`.
5. Comprueba si `schema_version` y `mechanism_version` están soportadas. Si
   cualquiera no está soportada: `UNSUPPORTED_VERSION`. La evaluación se
   detiene aquí y no se aplican reglas de v1 al resto.
6. Para v1 soportado, comprueba estructura y pertenencia de tipos: array
   exterior con longitud lógica 10, `domain` exacto, tipos exteriores, tipos
   permitidos de `payload`, tipos prohibidos, tags válidos pero prohibidos,
   bignums, floats, null, byte strings en `payload` y claves no textuales. Si
   falla:
   `MALFORMED_RECORD / ENCODING_PROFILE_VIOLATION`.
7. Comprueba valores y límites del perfil: rangos, longitudes lógicas, tamaño
   total, profundidad, cardinalidad y límites de textos, arrays y maps. Si
   falla:
   `MALFORMED_RECORD / ENCODING_PROFILE_VIOLATION`.
8. Para un valor admitido por completo, comprueba la codificación determinista:
   enteros y longitudes mínimos, longitudes definidas, orden de mapas y
   representación única de cada valor permitido. Si falla:
   `MALFORMED_RECORD / NON_CANONICAL_ENCODING`.
9. Resuelve la clave mediante el `key_id` externo. Si falla: `UNKNOWN_KEY`.
10. Verifica el `tag` externo sobre los bytes exactos. Si falla:
    `INVALID_TAG`.
11. Evalúa `SequenceContextCandidateV1` cuando exista. Si el ledger es distinto,
    produce `INVALID_SEQUENCE_CONTEXT / LEDGER_ID_MISMATCH`; si la secuencia es
    distinta, produce `INVALID_SEQUENCE_CONTEXT / UNEXPECTED_SEQUENCE`.
12. En otro caso: `VALID` de MEC-A1.

En particular, un array exterior de longitud indefinida que contenga exactamente
los diez elementos lógicos admitidos por v1 supera la comprobación lógica de la
fase 3, pero falla la canonicalidad del sobre en la fase 4 con
`MALFORMED_RECORD / NON_CANONICAL_ENCODING`. No se clasifica como
`ENCODING_PROFILE_VIOLATION`.

No se continúa a fases posteriores después de producir un resultado. Esta
precedencia evita que dos implementaciones elijan detalles diferentes ante una
entrada con varios defectos. `encode_record(logical_record)` aplica las
validaciones lógicas equivalentes, pero no produce errores de parsing o
canonicalidad de raw bytes. Las fases 1 y 2 son comprobaciones genéricas de
CBOR; las fases 3 y 4 comprueban únicamente el sobre estable de descubrimiento;
y las fases 6, 7 y 8 solo se ejecutan para versiones soportadas.

Ninguna regla de canonicalidad específica de v1 se aplica al cuerpo de una
versión desconocida. Una versión desconocida correctamente identificada produce
`UNSUPPORTED_VERSION` aunque el resto sea no canónico según v1, siempre que el
elemento completo siga siendo CBOR bien formado y básicamente válido. CBOR
truncado o inválido continúa fallando en las fases 1 o 2. El orden completo es
**CANDIDATO NO NORMATIVO**.

`validate_encoded_record(raw_bytes)` ejecuta únicamente las fases 1 a 8 y, si
son satisfactorias, devuelve `ValidatedEncodedRecord` en lugar de `VALID`.
`verify_encoded_record(...)` ejecuta las doce fases. Por su parte,
`verify_logical_record(...)` obtiene los bytes mediante `encode_record` y luego
ejecuta conceptualmente la resolución de clave, HMAC y contexto secuencial, sin
afirmar nada sobre la canonicalidad de bytes originales.

### Precedencia ante defectos superpuestos

`ENCODING_PROFILE_VIOLATION` tiene precedencia sobre
`NON_CANONICAL_ENCODING` cuando el valor lógico o el tipo CBOR no está admitido
por el perfil. `NON_CANONICAL_ENCODING` solo se usa cuando el valor pertenece al
perfil, pero sus bytes no son la representación determinista candidata. Por
ejemplo:

- un byte string de longitud definida dentro de `payload` produce
  `ENCODING_PROFILE_VIOLATION`;
- un byte string de longitud indefinida dentro de `payload` también produce
  `ENCODING_PROFILE_VIOLATION`, porque el tipo está prohibido;
- un text string permitido codificado con longitud indefinida produce
  `NON_CANONICAL_ENCODING`;
- un entero permitido codificado con ancho no mínimo produce
  `NON_CANONICAL_ENCODING`;
- un float codificado en una forma no mínima produce
  `ENCODING_PROFILE_VIOLATION`, porque float está prohibido;
- un map con claves textuales válidas, pero en orden incorrecto, produce
  `NON_CANONICAL_ENCODING`.

`DUPLICATE_MAP_KEY` conserva precedencia anterior para detectar la duplicación
antes de que un decoder pierda una ocurrencia. Esta regla también es
**CANDIDATO NO NORMATIVO**.

### Duplicados y despacho de versiones

Las claves duplicadas son una condición de validez CBOR genérica, no una regla
específica de v1. Por ello, un elemento con duplicados produce
`DUPLICATE_MAP_KEY` antes del despacho de versión. Una versión desconocida solo
produce `UNSUPPORTED_VERSION` cuando el elemento es bien formado, no contiene
errores de validez CBOR y el sobre de descubrimiento es determinista.

El subcaso de versión desconocida con cuerpo no canónico según v1 no usa claves
duplicadas, UTF-8 inválido ni tags con contenido inválido. Puede usar una forma
CBOR bien formada y válida que no satisfaría las reglas deterministas completas
de v1, las cuales no se aplican antes del despacho.

## Semántica secuencial candidata

`sequence` se autentica dentro del array, pero MEC-A1 no determina por sí mismo
continuidad ni extremo terminal. La siguiente definición completa la política
contextual común como **CANDIDATO NO NORMATIVO**.

### `SequenceContextCandidateV1`

`SequenceContextCandidateV1` es una entrada conceptual ya tipada. No crea una
clase, schema ni formato serializado. Contiene exactamente dos valores:

- `expected_ledger_id`: secuencia opaca de exactamente 16 octetos;
- `expected_sequence`: entero en `1..2^63-1`.

El contexto es externo a `authenticated_record_bytes_v1`, `tag`, `key_id` y la
base de datos autenticada. No forma parte del mensaje HMAC.

#### Predicado exacto

Después de que formato, versión, clave y tag sean válidos, el registro satisface
el contexto únicamente cuando se cumplen ambas igualdades:

`record.ledger_id == sequence_context.expected_ledger_id`

`record.sequence == sequence_context.expected_sequence`

Si `sequence_context` es `None`, se omite la comprobación y su ausencia no
produce `INVALID_SEQUENCE_CONTEXT`. Si existe un contexto bien construido y
falla la primera igualdad, el resultado es
`INVALID_SEQUENCE_CONTEXT / LEDGER_ID_MISMATCH`. Si la primera igualdad se
cumple y falla la segunda, el resultado es
`INVALID_SEQUENCE_CONTEXT / UNEXPECTED_SEQUENCE`. Cuando fallan ambas,
`LEDGER_ID_MISMATCH` tiene prioridad y la evaluación se detiene.

Estos dos detalles son candidatos y no crean estados superiores nuevos.

#### Primer registro, sucesores y secuencia presentada

Para validar el primer registro esperado de un ledger,
`expected_ledger_id` contiene el identificador esperado y
`expected_sequence = 1`.

Cuando un llamador dispone de un predecesor aceptado con secuencia `p`, puede
construir el contexto siguiente con `expected_sequence = p + 1` solo si
`p < 2^63-1`. Si `p = 2^63-1`, no existe un siguiente valor admitido y no debe
construirse un contexto sucesor.

Para verificar registros presentados en orden, el llamador:

1. inicia con `expected_sequence = 1` y el `expected_ledger_id` pertinente;
2. entrega el contexto al verificador;
3. incrementa la expectativa solo después de un resultado `VALID` de MEC-A1;
4. no avanza el contexto después de un rechazo.

Con este predicado, huecos, duplicados o reordenamiento producen
`UNEXPECTED_SEQUENCE` respecto del contexto proporcionado. MEC-A1 no necesita
distinguir la causa histórica exacta del desacuerdo.

#### Procedencia y alcance de la garantía

ADR-001 define el modelo y el predicado del contexto, no su procedencia. El
llamador debe suministrarlo desde estado externo o una fixture de prueba. Un
contexto obtenido del mismo snapshot local restaurable no aporta resistencia
adicional frente a rollback, y un contexto desactualizado o controlado por el
adversario no demuestra frescura.

Un resultado `VALID` de MEC-A1 solo significa coincidencia con el contexto
recibido dentro de las garantías del mecanismo; no demuestra que el registro
sea el extremo terminal vigente. ADR-004 permanece sin cambios.

#### Contexto inválido como entrada

Un `SequenceContextCandidateV1` con `expected_ledger_id` de longitud distinta de
16, `expected_sequence` fuera de rango o tipos incorrectos es un error de
construcción o configuración del llamador. La verificación no se inicia y no se
produce uno de los estados de MEC-A1. `INVALID_SEQUENCE_CONTEXT` se reserva para
un contexto bien construido que no coincide con el registro autenticado.

## Relación con ADR-002

`key_id` es externo a `authenticated_record_bytes_v1`. ADR-001 no define todavía
su formato, longitud, alcance o provisión; estas decisiones y la resolución de
claves permanecen bloqueadas por ADR-002. Definir conceptualmente `key_id` como
entrada de verificación no aprueba ADR-002 ni desbloquea MEC-A1. Cualquier futura
decisión de autenticar `key_id` requerirá revisar y reconciliar ambos ADR antes
de aprobar bytes normativos.

## Plan de vectores previo a una posible aprobación

Después de que el investigador acepte esta propuesta para experimentación, una
tarea futura podrá producir para el único perfil finalista valores lógicos,
contextos, resultados esperados, bytes y hexadecimal candidatos, autenticadores
cuando sean necesarios, versión del perfil y herramienta productora. Cada
artefacto deberá marcarse **CANDIDATO NO NORMATIVO**.

A y C conservan los criterios y casos conceptuales que justifican su
clasificación, pero no requieren codificaciones byte a byte. Los veinte casos
previstos para B son:

| Vector | Propósito mínimo |
|---|---|
| Registro mínimo válido para MEC-A1 | Comprobar que perfil y canonicalidad válidos, versión soportada, `key_id` resoluble, `tag` válido y contexto ausente o exactamente coincidente pueden alcanzar `VALID` de MEC-A1; no afirma aceptación por el schema de aplicación. |
| Unicode multibyte | Probar UTF-8 y la política Unicode fuera de ASCII. |
| Cadenas vacías | Distinguir cadenas permitidas en payload de campos exteriores no vacíos, ausencia y null. |
| Límites de enteros | Cubrir int64 mínimo y máximo, cero, negativos permitidos y valores fuera de rango. |
| Identificador binario | Probar `ledger_id` de 16 octetos y rechazar longitudes o tipos alternativos. |
| Timestamp | Probar cero, límite superior, primer valor superior, negativo y valor que requeriría redondeo o truncamiento; comprobar unidad, rango y prohibición de inferencia o tags. |
| Mapa anidado | Probar orden, profundidad, cardinalidad y duplicados internos. |
| Array | Probar orden, array vacío y tipos de elementos. |
| Orden determinista de map textual | Usar solo claves textuales permitidas, fijar el valor lógico, exigir los bytes candidatos en core deterministic encoding y verificar coincidencia entre dos codificadores independientes. |
| Orden textual no determinista | Usar el mismo map y las mismas claves textuales, presentar deliberadamente los pares en otro orden y esperar `MALFORMED_RECORD` con detalle `NON_CANONICAL_ENCODING`. |
| Clave duplicada | Usar claves textuales individualmente válidas con dos ocurrencias equivalentes y exigir `MALFORMED_RECORD / DUPLICATE_MAP_KEY`, tanto si el parser preserva pares como si una biblioteca estricta reporta la duplicación como error de validez. |
| Longitud no mínima | Cubrir, sobre valores admitidos, un entero con representación no mínima, text string, array y map con longitud indefinida, incluido como subcaso un array exterior indefinido con exactamente diez elementos lógicamente admitidos; todos esperan `MALFORMED_RECORD / NON_CANONICAL_ENCODING`. |
| Truncamiento | Cubrir cortes en cabecera, longitud, UTF-8 multibyte y anidamiento mediante `MALFORMED_RECORD` y detalle `MALFORMED_CBOR`. |
| Overflow | Cubrir longitudes, enteros, contadores y cálculos de tamaño fuera de rango. |
| Tipos y valores prohibidos | Cubrir byte string definida e indefinida dentro de payload, float, cero negativo flotante, NaN, infinito, bignum, null, tag y clave no textual; todos esperan `MALFORMED_RECORD / ENCODING_PROFILE_VIOLATION`. |
| Unicode inválido | Rechazar UTF-8 inválido y sustitutos aislados mediante `MALFORMED_RECORD` con detalle `INVALID_CBOR`. |
| Unicode compuesto | Distinguir U+00E9 de U+0065 U+0301 sin normalizar. |
| Versión desconocida | Cubrir los cuatro subcasos de despacho definidos después de la tabla y demostrar que una versión desconocida no se interpreta mediante reglas completas de v1. |
| Ambigüedad número/texto | Demostrar que un campo entero no admite una representación textual alternativa. |
| Contexto secuencial inválido con tag válido | Con registro autenticado `ledger_id = L`, `sequence = 5`, `tag` válido, `key_id` resoluble y contexto `(L, 6)`, exigir `INVALID_SEQUENCE_CONTEXT / UNEXPECTED_SEQUENCE`; como subcaso, registro con `L1` y contexto con `L2` exige `INVALID_SEQUENCE_CONTEXT / LEDGER_ID_MISMATCH`. |

La suite de vectores de ADR-001 valida codificación, mecanismo y contexto; no
sustituye una futura suite del schema de aplicación. Antes de una integración
productiva deberán existir fixtures de schema separados.

El vector `Versión desconocida` incluye, sin generar todavía sus bytes:

1. sobre de descubrimiento determinista, versión desconocida y resto compatible
   con v1: `UNSUPPORTED_VERSION`;
2. sobre de descubrimiento determinista, versión desconocida y resto bien
   formado y CBOR-válido, pero no canónico conforme a las reglas completas de
   v1: también `UNSUPPORTED_VERSION`;
3. campo de versión con tipo incorrecto:
   `MALFORMED_RECORD / ENCODING_PROFILE_VIOLATION`;
4. campo de versión codificado de forma no mínima:
   `MALFORMED_RECORD / NON_CANONICAL_ENCODING`.

Los dos primeros subcasos demuestran que el verificador no interpreta una
versión desconocida mediante reglas del perfil v1. Los subcasos que esperan
`UNSUPPORTED_VERSION` no contienen claves duplicadas, UTF-8 inválido ni otra
invalidez CBOR genérica.

El vector `Clave duplicada` debe producir el mismo resultado con un parser que
preserve todos los pares y con una biblioteca estricta que señale la duplicación
como error de validez. Un decoder que pierda silenciosamente una ocurrencia no
puede usarse como verificador independiente.

Como diagnóstico opcional de configuración de biblioteca puede usarse un map
CBOR con las claves enteras `100` y `-1` para distinguir core deterministic de
length-first. Ese diagnóstico está fuera del perfil porque sus claves no son
textuales, no cuenta entre los veinte vectores y no constituye evidencia de
conformidad del perfil. Tampoco puede aprobar o rechazar por sí solo una
implementación PT2.

Antes de solicitar aprobación deberán existir bytes candidatos completos y
hexadecimal para B, resultados coincidentes de dos codificadores o herramientas
independientes, casos positivos y negativos, evidencia de rechazo estricto y la
versión exacta del perfil. Mientras ADR-001 sea `DRAFT`, esos artefactos no serán
normativos ni pruebas de conformidad aprobadas.

Solo después de una aprobación expresa se podrán congelar vectores normativos,
resultados, límites y condiciones de rechazo.

## Secuencia de trabajo posterior

1. El investigador acepta el perfil candidato como base para experimentación,
   sin cambiar ADR-001 a `APPROVED`.
2. Una tarea posterior implementa dos codificadores de referencia
   independientes.
3. Esa tarea produce los 20 vectores candidatos.
4. Se comparan bytes y rechazos.
5. Se revisan los límites con datos reales.
6. Se corrige el perfil candidato cuando sea necesario.
7. Se presenta al investigador una versión aprobable.
8. Solo después se congelan vectores normativos y se modifican los documentos
   afectados mediante tareas autorizadas.

Esta tarea documental no autoriza todavía esos codificadores ni produce bytes o
vectores. La futura autorización queda condicionada a que el investigador
acepte primero la propuesta para experimentación.

Continúa sin autorización:

- implementación productiva de MEC-A1;
- integración del perfil en el flujo del POS;
- schema o API normativos;
- desbloqueo de MEC-A1;
- uso de bytes candidatos como contrato estable.

## Riesgos transversales

- confundir CBOR genérico con el perfil candidato completo;
- tratar una propuesta `DRAFT` como decisión aprobada;
- permitir dos tipos o representaciones para el mismo valor lógico;
- decodificar y recodificar silenciosamente una entrada no determinista;
- perder claves duplicadas en un parser genérico;
- truncar int64 o tiempo mediante binary64;
- transformar Unicode sin autorización;
- confundir autenticación de `sequence` con continuidad o frescura terminal;
- validar el codec únicamente contra sí mismo;
- congelar schema o bytes antes de la aprobación correspondiente.

## Recomendación técnica no vinculante

Se propone la alternativa B y
`PT2-CBOR-AUTH-RECORD-CANDIDATE-v1` como único finalista por su soporte nativo
para enteros, representación binaria, reglas deterministas estandarizadas y
capacidad de excluir tipos innecesarios.

A permanece no finalista por el riesgo y costo de framing propio. C permanece no
finalista por las convenciones adicionales requeridas para int64 y JSON number.
La clasificación es provisional, puede cambiar mientras ADR-001 siga `DRAFT`,
no equivale a aprobación del investigador y no convierte bytes futuros en
normativos.

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING.

- ADR-001 continúa `DRAFT`.
- MEC-A1 continúa `BLOCKED`.
- ADR-002 continúa pendiente.
- ADR-001 puede congelar una representación autenticada sin congelar todavía
  todas las reglas de negocio; `schema_version` mantiene autenticada la
  selección del schema.
- La implementación productiva continúa bloqueada porque ADR-001 sigue `DRAFT`,
  ADR-002 sigue pendiente, todavía no existen bytes y vectores candidatos
  validados y falta una definición verificable del schema de aplicación para la
  aceptación final.
- No existen bytes autenticados normativos.
- No existe schema normativo.
- No se autoriza integración productiva.
- Esta tarea no autoriza todavía codificadores de referencia ni genera
  vectores.
- Una tarea futura podrá crear codificadores de referencia y vectores marcados
  `CANDIDATO NO NORMATIVO` solo si el investigador acepta primero esta propuesta
  para experimentación.
- Estas fronteras no modifican ADR-004 ni añaden garantía de frescura.
- No se modifica la semántica vigente de RQ-01, THR-P1 ni los ataques pendientes.

## Fuentes técnicas consideradas

- RFC 8949 — Concise Binary Object Representation (CBOR) — Standards Track:
  https://www.rfc-editor.org/rfc/rfc8949.html
- RFC 8785 — JSON Canonicalization Scheme (JCS) — Informational:
  https://www.rfc-editor.org/rfc/rfc8785.html
- RFC 7493 — The I-JSON Message Format — Standards Track:
  https://www.rfc-editor.org/rfc/rfc7493.html

Las referencias describen candidatos técnicos y no tienen por sí solas estado
normativo dentro de PT2.

## Documentos afectados

- `docs/03-terminology.md`
- `docs/05-record-format.md`
- `docs/06-mechanism-specifications.md`
- futuros esquemas y vectores de conformidad, únicamente cuando sean autorizados

Los documentos enumerados no se modifican en esta tarea.

## Identificadores de trazabilidad

- `RQ-01`
- `MEC-A1`
- `THR-P1`
- `ADR-001`
