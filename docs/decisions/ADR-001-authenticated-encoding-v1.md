---
decision_id: ADR-001
title: Authenticated encoding v1
version: 0.2.0
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-001 — Codificación autenticada v1

## Estado y alcance del expediente

Este expediente compara perfiles técnicos concretos para producir los bytes que
autenticará MEC-A1. Permanece en estado DRAFT: no selecciona una codificación,
no define bytes normativos y no autoriza implementación, schema ni vectores
definitivos.

El investigador deberá aprobar una versión concreta del expediente antes de que
sus decisiones puedan trasladarse a los documentos normativos afectados. El
nombre de un estándar no basta para obtener una codificación normativa: cualquier
alternativa seleccionada deberá restringir tipos, opciones, límites,
extensibilidad y condiciones de rechazo.

## Contexto

MEC-A1 autentica una secuencia exacta de bytes. Productor y verificador deben
obtener los mismos bytes desde el mismo registro lógico sin depender del
lenguaje, locale, plataforma, orden accidental de contenedores ni valores
predeterminados de una biblioteca.

docs/05-record-format.md exige una codificación inequívoca de domain,
schema_version, mechanism_version, ledger_id, sequence y el payload lógico.
docs/06-mechanism-specifications.md mantiene MEC-A1 con implementación BLOCKED.
También existe una diferencia todavía no resuelta entre los nombres
canonicalPayload y canonical_payload.

RFC 8949 define CBOR y sus requisitos de codificación determinista, pero permite
que cada protocolo construya un modelo específico y determine cómo rechazar
datos inesperados. RFC 8785 define JCS sobre el subconjunto I-JSON, con
serialización y orden deterministas. Ninguna referencia se considera seleccionada
o aprobada por este expediente.

## Problema exacto que requiere decisión

El investigador debe seleccionar y aprobar un perfil completo que determine:

- el modelo lógico y los tipos admitidos;
- la estructura externa y su política de extensión;
- la representación única de cada campo;
- los bytes de separación de dominio;
- el versionado y las condiciones de rechazo;
- la política Unicode, temporal y numérica;
- el tratamiento de entradas válidas para el formato base pero no canónicas;
- el nombre normativo del payload y de los bytes autenticados;
- la relación entre autenticación de sequence y validación contextual;
- los vectores independientes que demuestren interoperabilidad byte a byte.

La decisión no puede reducirse a escoger una biblioteca o escribir “CBOR”,
“CBOR determinista”, “JSON” o “JCS”. Debe congelar un perfil PT2 verificable.

## Distinción obligatoria sobre secuencia

Tres propiedades diferentes deben permanecer separadas:

1. **Autenticación del valor declarado:** sequence forma parte de los bytes
   autenticados. Un tag válido demuestra que ese valor fue autenticado bajo la
   clave y el mensaje correspondientes; no demuestra que sea el valor esperado.
2. **Validación contextual:** detectar inicio inválido, huecos, duplicados o
   reordenamiento requiere comparar el valor autenticado con un contexto
   secuencial explícito.
3. **Conocimiento del extremo terminal vigente:** ni un tag válido ni la
   continuidad interna demuestran por sí solos que el último registro presentado
   sea el extremo vigente. Esa referencia requiere estado terminal confiable o
   una propiedad externa aprobada.

INVALID_TAG debe reservarse para un fallo de autenticación criptográfica.
INVALID_SEQUENCE_CONTEXT debe describir un fallo de la política contextual y no
debe presentarse como prueba de falsificación.

## Criterios y dimensiones de evaluación

Las alternativas se comparan sin puntuación numérica mediante:

- inyectividad práctica;
- determinismo;
- independencia de lenguaje;
- facilidad para crear vectores byte a byte;
- complejidad del verificador;
- tipos admitidos y rechazo de entradas no canónicas;
- enteros de 64 bits, tiempo, UUID y Unicode;
- objetos, listas, duplicados, nulos y coma flotante;
- versionado y separación de dominio;
- tamaño y dependencia de bibliotecas;
- posibilidad de validación cruzada independiente.

## Alternativa A — Perfil binario propio

Perfil diseñado para PT2, con estructura externa de posiciones fijas o TLV,
enteros de ancho y endianess explícitos y prefijos de longitud para todo valor
variable. La aprobación tendría que escoger una sola variante y documentar cada
octeto.

### Estructura y framing

Una estructura fija puede ordenar campos obligatorios por posición y asociar la
versión con una gramática cerrada. Un diseño TLV puede identificar tipo y longitud
para admitir extensiones, pero debe definir orden, unicidad de etiquetas, tags
desconocidos y si una repetición es siempre inválida. Mezclar ambos modelos sin
una regla única produciría más de una representación.

Los anchos de enteros, su signo y endianess deben congelarse. Los prefijos de
longitud deben fijar ancho, endianess, unidad, valor máximo y manejo de overflow,
truncamiento o contenido sobrante. El framing propio aumenta el riesgo de
colisiones de campos, errores de límites y evolución incompatible.

### Evaluación por dimensión

| Dimensión | Análisis del perfil binario propio |
|---|---|
| Inyectividad práctica | Puede ser alta si posiciones o tags, tipos y longitudes son inequívocos; un prefijo ambiguo o una etiqueta repetida la rompe. |
| Determinismo | Alto solo después de fijar orden, anchos, endianess, longitudes, nulos y extensiones. |
| Independencia de lenguaje | Posible porque el formato sería byte a byte, pero exige evitar tipos nativos implícitos y overflow dependiente del lenguaje. |
| Vectores byte a byte | Muy directos en hexadecimal; deben provenir también de una implementación independiente. |
| Complejidad del verificador | El parser puede ser pequeño, pero toda validación de framing, límites y extensiones queda a cargo de PT2. |
| Tipos admitidos | Deben enumerarse expresamente; no existe un modelo estándar que cierre el conjunto. |
| Rechazo no canónico | Deben rechazarse anchos alternativos, orden alternativo, tags duplicados, longitudes redundantes y bytes sobrantes según el perfil aprobado. |
| Enteros de 64 bits | Representación natural con ancho fijo o longitud mínima; deben fijarse signo, rango y endianess. |
| Tiempo | Puede ser entero de ancho fijo o texto con longitud; unidad y rango siguen siendo decisiones separadas. |
| UUID | Puede usar 16 bytes o texto; el perfil debe seleccionar una sola representación y orden de bytes. |
| Unicode | Las cadenas pueden codificarse en UTF-8, pero normalización, validez y rechazo siguen a cargo del perfil. |
| Objetos y listas | Requieren gramática propia recursiva, límites de profundidad y reglas de orden. |
| Campos duplicados | Deben prohibirse explícitamente en TLV u objetos; una estructura fija evita duplicados de campos conocidos. |
| Nulos | Deben prohibirse o recibir un tag único; ausencia y null no pueden confundirse. |
| Coma flotante | Puede excluirse de forma simple; si se admite, requiere ancho, NaN, infinitos y cero negativo. |
| Versionado | Puede integrarse en cabecera o primer campo, con política explícita para versiones desconocidas. |
| Separación de dominio | Puede usar un prefijo binario exacto, pero cada byte, longitud y relación con mechanism_version debe congelarse. |
| Tamaño | Potencialmente el menor, especialmente con posiciones fijas; TLV añade overhead controlado. |
| Bibliotecas | Poca dependencia externa, a cambio de mayor código y responsabilidad propios. |
| Validación cruzada | Exige una segunda implementación o herramienta independiente y vectores exhaustivos para evitar que el codec se valide a sí mismo. |

### Ventajas, desventajas y consecuencias

- Ventajas: control completo, tamaño predecible y trazas hexadecimales simples.
- Desventajas: framing inventado, mayor superficie de errores y menor
  interoperabilidad disponible de antemano.
- Consecuencia de una futura selección: documentar cada byte, crear al menos dos
  implementaciones independientes y congelar todos los límites antes de
  implementar MEC-A1.

## Alternativa B — Perfil CBOR determinista restringido

Perfil PT2 construido sobre RFC 8949 y sus requisitos de codificación
determinista. La alternativa usaría longitudes definidas y representaciones
mínimas, pero todavía debe decidir un modelo específico y más estrecho que el
modelo genérico de CBOR.

No se aprueba en este expediente que la estructura externa sea array o mapa, que
use un tag, ni un conjunto concreto de claves. Esas elecciones pertenecen a la
decisión posterior del investigador.

### Restricciones que requeriría el perfil

- usar longitudes definidas y prohibir elementos de longitud indefinida;
- limitar enteros al rango exacto requerido y exigir su representación mínima;
- si se usan mapas, fijar los tipos de clave, prohibir duplicados y aplicar el
  orden determinista elegido conforme a RFC 8949;
- aprobar o prohibir tags de forma exhaustiva, incluida su posición;
- prohibir coma flotante si el modelo PT2 no la necesita;
- fijar si la estructura externa es cerrada o extensible y cómo se rechazan
  elementos desconocidos;
- distinguir validez CBOR, pertenencia al perfil y codificación determinista;
- decidir si una entrada CBOR válida pero no determinista se rechaza directamente
  o se decodifica y recodifica solo para diagnóstico, nunca de forma implícita.

### Evaluación por dimensión

| Dimensión | Análisis del perfil CBOR determinista restringido |
|---|---|
| Inyectividad práctica | Alta si cada valor lógico tiene un solo tipo y una sola estructura; permitir tags opcionales o tipos equivalentes reintroduce ambigüedad. |
| Determinismo | RFC 8949 aporta una base: formas mínimas, longitudes definidas y orden de mapas; el perfil debe cerrar consideraciones adicionales. |
| Independencia de lenguaje | Buena en el nivel de bytes, pero debe probarse que cada biblioteca expone enteros, duplicados, tags y errores sin pérdidas. |
| Vectores byte a byte | Adecuados y compactos; pueden contrastarse con herramientas CBOR independientes. |
| Complejidad del verificador | Menor que un framing propio si la biblioteca permite validar el perfil; aumenta si decodifica antes de detectar duplicados o no canonicalidad. |
| Tipos admitidos | CBOR ofrece más tipos de los necesarios; el perfil debe permitir una lista cerrada. |
| Rechazo no canónico | Debe detectarse representación no mínima, longitud indefinida, orden inválido, tags no permitidos, duplicados y tipos fuera del perfil. |
| Enteros de 64 bits | Soporte binario nativo suficiente para los rangos PT2; deben limitarse al rango con signo requerido y rechazarse bignums o valores fuera de rango. |
| Tiempo | Puede ser entero o texto, con o sin tag; el perfil debe escoger exactamente una representación y unidad. |
| UUID | Puede ser bytes, texto o valor etiquetado; solo una opción podría quedar permitida. |
| Unicode | Las cadenas de texto son Unicode codificado en UTF-8; normalización y rechazo de secuencias inválidas deben fijarse en el perfil. |
| Objetos y listas | Mapas y arrays son nativos; deben limitarse claves, profundidad, cardinalidad y tipos recursivos. |
| Campos duplicados | Los mapas no admiten claves duplicadas en el modelo; el decoder elegido debe detectarlas antes de perder entradas. |
| Nulos | CBOR dispone de null, pero el perfil debe permitirlo o prohibirlo por posición. |
| Coma flotante | CBOR la admite en varias precisiones; puede y probablemente debe excluirse si no existe una necesidad aprobada. |
| Versionado | Puede ser un campo de la estructura; su posición, tipo y rechazo de versiones desconocidas siguen pendientes. |
| Separación de dominio | Puede ser un campo o prefijo exterior, pero deben aprobarse sus bytes exactos y evitar dos representaciones equivalentes. |
| Tamaño | Generalmente compacto, con overhead dependiente de array, mapa, claves y tags que aún no se han seleccionado. |
| Bibliotecas | Existen implementaciones múltiples; deben evaluarse modo determinista, preservación de enteros y capacidad de rechazo estricto. |
| Validación cruzada | Favorable mediante dos bibliotecas o lenguajes, más comparación de bytes y casos negativos no canónicos. |

### Ventajas, desventajas y consecuencias

- Ventajas: soporte binario nativo para enteros, representación compacta, reglas
  deterministas estandarizadas y capacidad de excluir tipos innecesarios.
- Desventajas: el modelo general conserva opciones; algunas bibliotecas aceptan
  formas no deterministas o pierden duplicados antes de que la aplicación pueda
  rechazarlos.
- Consecuencia de una futura selección: publicar un perfil PT2 cerrado, probar
  interoperabilidad entre implementaciones y especificar la conducta exacta ante
  CBOR válido pero fuera del perfil o no determinista.

## Alternativa C — Perfil JCS restringido

Perfil PT2 basado en RFC 8785. JCS canonicaliza datos del subconjunto I-JSON,
ordena propiedades recursivamente, serializa sin espacios y emite UTF-8. El
perfil PT2 todavía tendría que restringir el modelo lógico y resolver los tipos
que JSON no representa directamente.

### Restricciones que requeriría el perfil

- exigir entrada compatible con I-JSON y nombres de propiedad no duplicados;
- fijar el conjunto de propiedades y la estructura externa;
- preservar las cadenas Unicode sin normalización implícita, o justificar una
  validación previa más restrictiva compatible con la decisión Unicode;
- prohibir números de coma flotante en el modelo PT2 aunque JCS pueda
  serializarlos;
- representar de forma inequívoca los enteros de 64 bits que no sean seguros
  como números IEEE 754, posiblemente mediante cadenas con gramática cerrada;
- fijar timestamp, UUID, nulos, listas, objetos, límites y versiones;
- decidir si una entrada JSON sintácticamente válida pero no canónica se
  rechaza o se canonicaliza desde un valor lógico previamente validado.

Representar enteros como cadenas evita pérdida de precisión, pero cambia su tipo,
requiere prohibir signo o ceros redundantes según el campo y añade validación. No
puede asumirse que una cadena decimal sea automáticamente un entero normativo.

### Evaluación por dimensión

| Dimensión | Análisis del perfil JCS restringido |
|---|---|
| Inyectividad práctica | Alta para un modelo cerrado si cada valor tiene un solo tipo; cae si un entero puede ser número o cadena, o si ausencia y null son equivalentes. |
| Determinismo | JCS fija serialización, orden recursivo y UTF-8; el perfil debe fijar el valor lógico de entrada y sus tipos. |
| Independencia de lenguaje | Buena para strings y estructuras comunes; la serialización numérica y el orden UTF-16 deben verificarse fuera de entornos ECMAScript. |
| Vectores byte a byte | Legibles y fáciles de difundir; deben comparar los bytes UTF-8, no solo el texto mostrado. |
| Complejidad del verificador | Bibliotecas JSON son comunes, pero se necesita validación estricta antes de perder duplicados o precisión numérica. |
| Tipos admitidos | JSON ofrece string, number, boolean, null, object y array; bytes, UUID, tiempo e int64 requieren convenciones PT2. |
| Rechazo no canónico | Debe distinguirse JSON inválido, I-JSON inválido, modelo PT2 inválido y texto válido que no coincide con la serialización JCS. |
| Enteros de 64 bits | Los valores fuera del rango entero seguro de IEEE 754 no deben pasar como JSON number; una cadena decimal cerrada es una opción pendiente. |
| Tiempo | Normalmente sería texto o entero representado como cadena; formato, zona, precisión y unidad deben congelarse. |
| UUID | Normalmente texto; deben fijarse forma, guiones, mayúsculas y variantes admitidas. |
| Unicode | JCS preserva datos de cadena sin normalización y ordena claves por unidades UTF-16; PT2 debe decidir si acepta esa política o exige validación previa. |
| Objetos y listas | Son nativos; las propiedades se ordenan recursivamente y el orden de listas se conserva. |
| Campos duplicados | I-JSON los prohíbe; el parser debe detectarlos antes de construir un objeto que descarte uno. |
| Nulos | JSON los admite; el perfil debe decidir posiciones permitidas y distinguir null de ausencia. |
| Coma flotante | JCS la admite bajo IEEE 754; el perfil PT2 puede prohibirla y debe rechazarla antes de autenticar. |
| Versionado | Puede ser una propiedad textual o numérica segura; nombre, tipo y versiones admitidas quedan pendientes. |
| Separación de dominio | Requiere una propiedad o framing exterior inequívoco; los bytes exactos no se deducen de JCS. |
| Tamaño | Mayor por nombres, comillas y números textuales; mejora legibilidad y diagnóstico. |
| Bibliotecas | Amplia disponibilidad, pero no todas implementan JCS ni exponen duplicados y precisión de forma segura. |
| Validación cruzada | Posible con implementaciones JCS de lenguajes distintos y comparación de UTF-8; debe incluir claves Unicode y límites numéricos. |

### Ventajas, desventajas y consecuencias

- Ventajas: legibilidad, ecosistema JSON amplio y orden determinista
  estandarizado.
- Desventajas: limitación numérica I-JSON, mayor tamaño y necesidad de perfilar
  int64, UUID y tiempo como convenciones textuales.
- Consecuencia de una futura selección: congelar gramáticas textuales y demostrar
  que parsers distintos rechazan duplicados, Unicode inválido y números fuera
  del perfil antes de autenticar.

## Comparación resumida

| Aspecto | A — Binario propio | B — CBOR restringido | C — JCS restringido |
|---|---|---|---|
| Framing inventado | Alto | Bajo a medio | Bajo, salvo dominio y convenciones PT2 |
| Enteros de 64 bits | Naturales | Naturales | Requieren cuidado; posiblemente cadenas |
| Tamaño esperado | Menor | Compacto | Mayor |
| Legibilidad humana | Baja | Baja a media con diagnóstico | Alta |
| Rechazo estricto | Totalmente propio | Depende del perfil y decoder | Depende del parser, I-JSON y perfil |
| Validación cruzada | Requiere crear segunda implementación | Buen soporte potencial | Buen soporte potencial |
| Riesgo dominante | Errores de framing propio | Opciones CBOR no cerradas | Pérdida numérica o textual no perfilada |

Esta tabla no asigna ganador ni equivale a una aprobación.

## Decisiones ortogonales pendientes

Cada fila requiere una resolución expresa, cualquiera sea el formato base.

| Decisión | Alternativas concretas pendientes | Consecuencia que deberá congelarse |
|---|---|---|
| 1. Nombre normativo del payload y de los bytes autenticados | canonical_payload; canonicalPayload; record_payload_v1 y authenticated_record_bytes_v1 como nombres separados | Unificar documentos futuros sin confundir valor lógico con serialización. |
| 2. ledger_id | 16 bytes UUID; texto UUID canónico; identificador opaco con longitud prefijada | Fijar variante, longitud, orden de bytes, mayúsculas y rechazo. |
| 3. occurred_at | entero desde epoch; texto UTC de gramática cerrada | Fijar zona, precisión, rango, redondeo y segundos intercalares. |
| 4. Unidad temporal | segundos; milisegundos; microsegundos; nanosegundos | Una sola unidad, rango y conversión normativa, sin inferencia por magnitud. |
| 5. Política Unicode | preservar secuencia válida; exigir una forma normalizada sin transformar; normalizar antes de codificar | Fijar versión, punto de validación y rechazo; nunca depender del locale. |
| 6. Tipos dentro de payload | conjunto cerrado de string, int64, boolean, objeto y lista; añadir null; añadir bytes | Enumerar tipos, recursión, coerciones prohibidas y posiciones válidas. |
| 7. Límites máximos | límites globales; límites por campo; combinación de ambos | Fijar bytes, caracteres, elementos, profundidad y conducta ante exceso. |
| 8. Estructura fija o extensible | estructura cerrada por versión; extensiones solo con nueva versión; campos desconocidos ignorables pero autenticados | Determinar orden, campos desconocidos y compatibilidad; ignorar no puede cambiar los bytes autenticados. |
| 9. Bytes de separación de dominio | prefijo literal con longitud; identificador binario versionado; campo obligatorio dentro de la estructura | Publicar bytes exactos, framing, relación con mechanism_version y prohibición de selección en ejecución. |
| 10. Responsabilidad de continuidad | MEC-A1 solo autentica sequence; MEC-A1 valida cuando recibe contexto; política común separada valida continuidad | Declarar quién detecta inicio, huecos, duplicados y reordenamiento. |
| 11. INVALID_SEQUENCE_CONTEXT | contexto ausente; valor incompatible con el predecesor; categoría estable con detalle estructurado | Separarlo de INVALID_TAG y definir precondiciones y detalle sin crear estados arbitrarios. |
| 12. Codificación válida pero no determinista | rechazo inmediato; decodificación y comparación con recodificación para diagnosticar, seguida de rechazo | Nunca aceptar silenciosamente dos bytes para el mismo valor ni autenticar después de una normalización implícita. |

## Plan de vectores requerido antes de aprobación

Los vectores deberán declarar valor lógico, contexto, resultado esperado y, solo
cuando el perfil sea aprobado, bytes exactos y autenticador. En esta versión no
se generan bytes normativos definitivos.

| Vector | Propósito mínimo |
|---|---|
| Registro mínimo válido | Cubrir todos los campos obligatorios en sus valores mínimos permitidos. |
| Unicode multibyte | Probar UTF-8, orden y política Unicode con caracteres fuera de ASCII. |
| Cadenas vacías | Distinguir cadena vacía, ausencia y null. |
| Límites de enteros | Cubrir mínimo y máximo de int64, cero, negativos permitidos y primer valor fuera de rango. |
| UUID | Probar una representación válida y variantes de texto o bytes que deban rechazarse. |
| Timestamp | Probar instante válido, precisión, zona y límites de la unidad seleccionada. |
| Objeto anidado | Probar orden, profundidad y duplicados en un nivel interno. |
| Lista | Probar preservación de orden, lista vacía y tipos de elementos. |
| Orden alternativo de mapa | Demostrar el mismo valor lógico y exigir los bytes deterministas o el rechazo de entrada no canónica. |
| Campo duplicado | Demostrar rechazo antes de que el parser descarte una ocurrencia. |
| Longitud no mínima | Demostrar rechazo de framing o CBOR más largo que la representación admitida. |
| Truncamiento | Cubrir cortes en cabecera, longitud, valor multibyte y estructura anidada. |
| Overflow | Cubrir longitud, entero, contador y cálculo de tamaño fuera de rango. |
| Coma flotante prohibida | Rechazar valores finitos, cero negativo, NaN o infinito según sea representable en el formato base. |
| Unicode inválido | Rechazar UTF-8 inválido, sustitutos aislados u otra secuencia prohibida por el perfil. |
| Versión desconocida | Rechazar sin interpretar el resto con reglas de otra versión. |
| Contexto secuencial inválido con tag válido | Demostrar que el valor sequence fue autenticado, pero falla continuidad mediante INVALID_SEQUENCE_CONTEXT y no INVALID_TAG. |

Antes de solicitar aprobación, el conjunto deberá incluir:

- vectores positivos y negativos independientes de una API concreta;
- representación hexadecimal de todos los bytes candidatos;
- resultados coincidentes de al menos dos implementaciones o herramientas
  independientes;
- pruebas de que duplicados y formas no canónicas se detectan antes de perder
  información;
- límites, versión del perfil y fuentes exactas de cada expectativa.

## Riesgos transversales

- confundir el formato base con el perfil normativo completo;
- permitir dos tipos o representaciones para el mismo valor lógico;
- decodificar y recodificar silenciosamente una entrada no determinista;
- perder campos duplicados dentro de un parser genérico;
- truncar enteros de 64 bits en una representación IEEE 754;
- transformar Unicode sin una política aprobada;
- confundir autenticación de sequence con continuidad o frescura terminal;
- aprobar un diagrama o nombres sin publicar los bytes;
- confiar solo en vectores generados por la implementación bajo prueba;
- autorizar un schema antes de que tipos, límites y estructura estén aprobados.

## Recomendación técnica no vinculante

Se recomienda evaluar primero la alternativa B, un perfil CBOR determinista
restringido, por su soporte nativo para enteros, representación binaria, reglas
deterministas estandarizadas y posibilidad de excluir tipos innecesarios.

La recomendación es provisional y no selecciona ni aprueba:

- estructura externa;
- array, mapa o claves de mapa;
- tags;
- representación o unidad del timestamp;
- política Unicode;
- nombre normativo;
- límites;
- responsabilidad de continuidad;
- conducta final ante entradas no deterministas;
- bytes de separación de dominio;
- bytes autenticados finales.

La alternativa B deberá compararse con A y C mediante los mismos vectores y
condiciones de rechazo. Si una biblioteca CBOR no permite validar estrictamente
el perfil, su disponibilidad no constituye una ventaja suficiente.

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING.

- MEC-A1 continúa BLOCKED.
- ADR-002 continúa siendo necesaria para alcance y provisión de claves.
- No existen bytes autenticados normativos.
- No se autoriza implementación.
- No se autoriza schema.
- No se autoriza vector definitivo.
- No se modifica la semántica vigente de RQ-01, THR-P1 ni los ataques pendientes.

## Fuentes técnicas consideradas

- RFC 8949 — Concise Binary Object Representation (CBOR):
  https://www.rfc-editor.org/rfc/rfc8949.html
- RFC 8785 — JSON Canonicalization Scheme (JCS):
  https://www.rfc-editor.org/rfc/rfc8785.html

Estas referencias describen candidatos técnicos. No tienen por sí solas estado
normativo dentro de PT2 y no sustituyen la aprobación expresa del perfil.

## Documentos afectados

- docs/03-terminology.md
- docs/05-record-format.md
- docs/06-mechanism-specifications.md
- futuros esquemas y vectores de conformidad, únicamente cuando sean autorizados

Los documentos enumerados no se modifican en esta tarea.

## Identificadores de trazabilidad

- RQ-01
- MEC-A1
- THR-P1
- ADR-001
