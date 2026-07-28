---
decision_id: ADR-001
title: Authenticated encoding v1
version: 0.1.0
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-001 — Codificación autenticada v1

## Contexto

`MEC-A1` autentica exactamente una secuencia de bytes. El productor y el
verificador deben obtener los mismos bytes desde el mismo registro lógico sin
depender de opciones implícitas de una biblioteca, plataforma o locale.

`docs/05-record-format.md` exige una codificación inequívoca y
`docs/06-mechanism-specifications.md` mantiene `MEC-A1` en estado de
implementación `BLOCKED`. En este momento existe además una diferencia de nombre
entre `canonicalPayload` y `canonical_payload`; el expediente la registra, pero
no la resuelve.

## Problema exacto que requiere decisión

El investigador debe aprobar una especificación completa que determine los
bytes autenticados y la validación contextual de la secuencia. La decisión debe
cubrir conjuntamente:

- formato de codificación inequívoca;
- separación de dominio;
- representación de enteros;
- representación temporal;
- tratamiento de longitudes;
- orden de campos;
- normalización Unicode;
- nombre normativo único del concepto hoy referido como `canonical_payload`;
- semántica de `INVALID_SEQUENCE_CONTEXT`;
- responsabilidad de `MEC-A1` sobre la continuidad de secuencia.

No basta con elegir un serializador: debe congelarse un perfil verificable y
producirse vectores de bytes para casos válidos e inválidos.

## Criterios de evaluación

- inyectividad práctica: dos tuplas distintas no deben compartir codificación;
- determinismo entre productor y verificador;
- especificación independiente del lenguaje y de la biblioteca;
- posibilidad de construir vectores de conformidad byte a byte;
- tratamiento explícito de versiones y separación de dominio;
- rechazo inequívoco de entradas malformadas o fuera de rango;
- compatibilidad con los tipos de `docs/05-record-format.md`;
- costo y complejidad razonables para el artefacto PT2;
- estabilidad para comparar mecanismos sin ampliar el alcance del proyecto.

## Alternativas concretas para el formato base

### Alternativa A — Codificación binaria propia con longitudes explícitas

Perfil binario específico de PT2 con etiquetas o posiciones fijas, enteros de
ancho y endianess fijados, y prefijos de longitud para todo valor variable.

#### Ventajas

- control total de los bytes y del rechazo de valores inválidos;
- implementación directa de separación de dominio y versionado;
- vectores compactos y fáciles de comparar en hexadecimal.

#### Desventajas

- crea un formato propio que debe especificarse y probarse exhaustivamente;
- aumenta el riesgo de errores en límites, longitudes y evolución de versión;
- requiere implementaciones independientes o pruebas fuertes para evitar que el
  codec se valide a sí mismo.

#### Consecuencias

La aprobación obligaría a documentar cada octeto, endianess, ancho, prefijo,
límite y condición de rechazo. Cualquier cambio posterior del framing requeriría
una nueva versión del mecanismo o de la codificación.

### Alternativa B — Formato canónico estandarizado

Adoptar un estándar con reglas deterministas y congelar un perfil PT2 que
elimine grados de libertad, incluidos tipos admitidos, orden y tratamiento de
valores no representables en el modelo del benchmark.

#### Ventajas

- aprovecha especificaciones y herramientas existentes;
- reduce la cantidad de framing inventado por el proyecto;
- puede facilitar validación cruzada con otra implementación.

#### Desventajas

- “usar el estándar” no basta si conserva opciones o extensiones;
- las bibliotecas pueden implementar perfiles o versiones diferentes;
- el modelo estándar puede admitir tipos y representaciones fuera del alcance
  de PT2.

#### Consecuencias

La aprobación exigiría identificar estándar, versión, perfil, opciones
prohibidas y comportamiento ante entradas no canónicas. También exigiría fijar
la versión de las bibliotecas usadas para reproducibilidad.

### Alternativa C — Representación textual determinista

Usar una gramática textual cerrada o un perfil textual canónico con UTF-8,
escapado, orden, números y tiempo definidos normativamente.

#### Ventajas

- facilita inspección humana y diagnóstico de vectores;
- puede reutilizar herramientas textuales ampliamente disponibles;
- simplifica el intercambio de ejemplos en documentación.

#### Desventajas

- el escapado, Unicode, números y orden introducen superficies de ambigüedad;
- suele producir más bytes y más trabajo de canonicalización;
- una representación visualmente idéntica no garantiza los mismos bytes.

#### Consecuencias

La aprobación obligaría a congelar gramática, escapes, espacios permitidos,
orden, representación decimal y política Unicode. Las entradas equivalentes no
canónicas tendrían que rechazarse o normalizarse de una sola manera.

## Decisiones ortogonales que deben acompañar al formato

| Dimensión | Alternativas defendibles | Ventajas y desventajas | Consecuencia normativa |
|---|---|---|---|
| Separación de dominio | literal fijo por mecanismo; identificador estructurado con versión; prefijo binario reservado | Un literal fijo es simple pero menos extensible. Un identificador estructurado evoluciona mejor, pero añade framing. | Deben fijarse bytes exactos, longitud o terminador y relación con `mechanism_version`; no puede elegirse en ejecución. |
| Enteros | ancho fijo con signo y endianess; entero canónico de longitud mínima; decimal textual sin signo redundante | El ancho fijo es simple y estable, pero menos compacto. La longitud mínima ahorra bytes, pero requiere reglas de minimalidad. El decimal es legible, pero necesita más validación. | Deben definirse rangos, cero, negativos, overflow y rechazo de representaciones no mínimas. |
| Tiempo | entero UTC desde epoch con unidad fijada; texto UTC con precisión y sufijo fijados | El entero evita variantes textuales, pero la unidad debe congelarse. El texto es legible, pero exige reglas de precisión, zona y años. | Deben prohibirse zonas locales, precisión implícita, leap-second ambiguo y redondeo no especificado. |
| Longitudes | prefijo para cada valor variable; longitudes provistas por el contenedor estándar; estructura textual cerrada | Los prefijos propios son explícitos, pero sensibles a overflow. El contenedor reduce código, pero depende de su perfil. El texto depende de una gramática inequívoca. | Deben fijarse unidad de longitud, ancho, máximo y conducta ante truncamiento o longitud excedida. |
| Orden de campos | posiciones fijas; mapa con orden canónico; lista ordenada de pares | Las posiciones son simples, pero dificultan extensión. Los mapas son extensibles, pero requieren orden y duplicados normativos. | Debe definirse el orden exacto y prohibirse campos duplicados; la extensibilidad queda pendiente. |
| Unicode | preservar secuencia de code points y autenticar sus bytes; exigir una forma normalizada; normalizar antes de codificar | Preservar evita transformaciones, pero admite cadenas visualmente equivalentes. Exigir normalización detecta entradas divergentes. Normalizar mejora convergencia, pero transforma datos. | Debe fijarse una política y el punto de rechazo o transformación; ninguna normalización puede depender del locale. |
| Nombre normativo | `canonical_payload`; `canonicalPayload`; un nombre nuevo versionado | `canonical_payload` coincide con `MEC-A1`; `canonicalPayload` coincide con parte de `docs/05`; renombrar ambos evita privilegiar uno, pero amplía el cambio. | Un solo nombre deberá sustituir a los demás en documentos, esquemas, evidencia y futuras APIs. Hasta la aprobación, la discrepancia permanece explícita. |
| `INVALID_SEQUENCE_CONTEXT` | falta de contexto requerido; discontinuidad respecto del contexto; ambas causas con detalle estructurado | Un significado único es fácil de probar, pero menos expresivo. Agrupar causas mantiene una salida estable, pero exige un subcódigo o detalle. | Debe distinguirse de `INVALID_TAG`: el autenticador puede ser válido para el valor de `sequence` y aun fallar la política contextual. |
| Continuidad en `MEC-A1` | solo autenticar el valor declarado; verificar continuidad cuando se entrega contexto ordenado; delegar continuidad a una política común | La primera opción mantiene autenticación individual pura, pero no detecta huecos sin otro componente. La segunda concentra conducta, pero mezcla autenticidad y política. La tercera mejora comparación entre mecanismos, pero requiere contrato adicional. | Debe declararse quién detecta duplicados, huecos, reordenamiento, inicio distinto de uno y ausencia de extremo terminal confiable. |

## Riesgos

- aprobar un nombre o diagrama sin congelar los bytes reales;
- aceptar dos representaciones del mismo valor y producir tags incompatibles;
- confundir autenticación del campo `sequence` con prueba de continuidad;
- usar normalización Unicode dependiente de biblioteca o versión;
- tratar `INVALID_SEQUENCE_CONTEXT` como evidencia de falsificación;
- permitir que una optimización cambie silenciosamente el mensaje autenticado;
- aprobar una alternativa sin vectores negativos de longitudes, enteros y tiempo.

## Recomendación técnica no vinculante

Antes de seleccionar una alternativa, conviene exigir una tabla byte a byte, un
perfil cerrado y vectores de conformidad compartidos por productor y
verificador. Cualquiera de las tres familias puede ser defendible si satisface
los criterios, pero no debería aprobarse una codificación que dependa de valores
predeterminados de una biblioteca o que no separe `INVALID_TAG` de errores de
contexto secuencial.

Esta recomendación no selecciona codificación, política Unicode, nombre ni
responsabilidad de continuidad.

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING. `MEC-A1` permanece `BLOCKED` y no existen todavía bytes normativos para
implementar o verificar.

## Documentos afectados

- `docs/03-terminology.md`
- `docs/05-record-format.md`
- `docs/06-mechanism-specifications.md`
- futuros esquemas y vectores de conformidad, cuando sean autorizados

## Identificadores de trazabilidad

- `RQ-01`
- `MEC-A1`
- `THR-P1`
- `ADR-001`
