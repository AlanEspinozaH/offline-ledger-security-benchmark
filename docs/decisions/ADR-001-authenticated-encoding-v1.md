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

### Estructura exterior cerrada

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
Cualquier extensión requiere una nueva `schema_version` o una nueva versión del
perfil. Los elementos de `payload` siempre quedan autenticados aunque su
semántica sea validada por el schema. Esta tarea no genera los bytes CBOR del
array.

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

### Entrada fuera del perfil o no determinista

Una codificación CBOR válida pero fuera del perfil o no determinista se rechaza;
no se normaliza para aceptarla silenciosamente. Puede recodificarse solo para
diagnóstico. La aceptación exige coincidencia byte a byte con la recodificación
determinista candidata.

El rechazo usa el estado superior existente `MALFORMED_RECORD` y el detalle
estable `NON_CANONICAL_ENCODING`. No se añade un estado superior nuevo.

## Semántica secuencial candidata

`sequence` se autentica dentro del array, pero MEC-A1 no determina por sí mismo
continuidad ni extremo terminal. Una política común separada compara el valor
autenticado con un contexto explícito.

- si no se proporciona contexto, su ausencia no produce automáticamente
  `INVALID_SEQUENCE_CONTEXT`;
- si se proporciona contexto y el valor autenticado es incompatible, el
  resultado es `INVALID_SEQUENCE_CONTEXT`;
- `INVALID_SEQUENCE_CONTEXT` solo se evalúa después de que formato, versión y
  tag sean válidos;
- `VALID` no implica frescura terminal ni ausencia de rollback.

La propuesta no modifica ADR-004.

## Relación con ADR-002

`key_id` y el alcance de la clave no se añaden todavía a los bytes candidatos.
Su semántica permanece en ADR-002. ADR-001 no desbloquea MEC-A1 por sí sola.
Cualquier futura decisión de autenticar `key_id` deberá reconciliar ADR-001 y
ADR-002 antes de aprobar bytes normativos.

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
| Registro mínimo válido | Cubrir todos los campos obligatorios en mínimos permitidos. |
| Unicode multibyte | Probar UTF-8 y la política Unicode fuera de ASCII. |
| Cadenas vacías | Distinguir cadenas permitidas en payload de campos exteriores no vacíos, ausencia y null. |
| Límites de enteros | Cubrir int64 mínimo y máximo, cero, negativos permitidos y valores fuera de rango. |
| Identificador binario | Probar `ledger_id` de 16 octetos y rechazar longitudes o tipos alternativos. |
| Timestamp | Probar unidad, límites y prohibición de inferencia, redondeo o tags. |
| Mapa anidado | Probar orden, profundidad, cardinalidad y duplicados internos. |
| Array | Probar orden, array vacío y tipos de elementos. |
| Orden alternativo de map | Exigir core deterministic o rechazar la entrada no canónica. |
| Orden CBOR divergente | Diagnosticar core frente a length-first; claves CBOR 100 y -1 pueden distinguir bibliotecas, pero ese objeto se rechaza porque el perfil exige claves textuales. |
| Clave duplicada | Rechazar antes de que el decoder descarte una ocurrencia. |
| Longitud no mínima | Rechazar longitudes o enteros con representación no mínima. |
| Truncamiento | Cubrir cortes en cabecera, longitud, UTF-8 multibyte y anidamiento. |
| Overflow | Cubrir longitudes, enteros, contadores y cálculos de tamaño fuera de rango. |
| Valores numéricos prohibidos | Rechazar float, cero negativo flotante, NaN, infinito, bignum y texto numérico donde corresponda. |
| Unicode inválido | Rechazar UTF-8 inválido y sustitutos aislados. |
| Unicode compuesto | Distinguir U+00E9 de U+0065 U+0301 sin normalizar. |
| Versión desconocida | Rechazar sin interpretar el resto con reglas de otra versión. |
| Ambigüedad número/texto | Demostrar que un campo entero no admite una representación textual alternativa. |
| Contexto secuencial inválido con tag válido | Producir `INVALID_SEQUENCE_CONTEXT`, no `INVALID_TAG`, después de validar formato, versión y tag. |

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
- No existen bytes autenticados normativos.
- No existe schema normativo.
- No se autoriza integración productiva.
- Esta tarea no autoriza todavía codificadores de referencia ni genera
  vectores.
- Una tarea futura podrá crear codificadores de referencia y vectores marcados
  `CANDIDATO NO NORMATIVO` solo si el investigador acepta primero esta propuesta
  para experimentación.
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
