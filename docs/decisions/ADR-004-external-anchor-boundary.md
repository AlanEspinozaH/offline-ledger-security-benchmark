---
decision_id: ADR-004
title: External Anchor and Checkpoint Externalization Boundary
version: 0.2.1
status: APPROVED
date: 2026-07-30
decided_by: Alan Espinoza
---

# ADR-004 — Frontera del anclaje externo y externalización de checkpoints

## Estado y alcance del expediente

Este expediente registra la decisión aprobada por el investigador sobre la
frontera arquitectónica de externalización y el papel experimental de las
alternativas A–F. La aprobación no autoriza implementación y no define todavía
clases, endpoints, sockets, formatos binarios, tablas SQLite ni servicios de
red.

Los contratos `docs/07-checkpoint-protocol.md` y
`docs/08-anchor-protocol.md` todavía no contienen una especificación normativa
implementable. Este ADR autoriza que sus especificaciones derivadas se redacten
en tareas posteriores y separadas conforme a `docs/01-change-control.md`.

## Historial de aprobación

- ADR-004 v0.2.0 fue aprobada el `2026-07-29` como decisión inicial de la
  frontera arquitectónica.
- ADR-004 v0.2.1 fue aprobada el `2026-07-30` como revisión exclusivamente
  documental.
- v0.2.1 restaura la recomendación técnica no vinculante exigida por la
  convención de ADR.
- v0.2.1 sustituye documentalmente a v0.2.0 como versión vigente.
- v0.2.1 no modifica la resolución científica, los papeles de A–F, el alcance
  experimental, `THR-P1`, la verificación independiente, la ausencia de recibo
  importado por el POS, los bloqueos existentes ni los protocolos, amenazas,
  ataques o métricas pendientes.

> Apruebo ADR-004 versión 0.2.1 como revisión documental de la versión 0.2.0. La restauración de la recomendación técnica no vinculante no modifica la resolución científica aprobada, los papeles de las alternativas A–F ni el alcance experimental. ADR-004 v0.2.1 pasa a ser la versión vigente aprobada y sustituye documentalmente a v0.2.0.

Decidido por: Alan Espinoza

Fecha de aprobación de v0.2.1: 2026-07-30

## Contexto

`RQ-03` pregunta en qué condiciones un anclaje externo intermitente permite
detectar la restauración de un historial local anterior e internamente válido.
`RQ-04` requiere separar costos por fase y sobrecosto incremental. Ambas
preguntas están en estado `DRAFT` en `docs/02-research-questions.md`.

`THR-P1`, definido en `docs/04-threat-model.md`, puede copiar y restaurar como
conjunto el dominio local restaurable, pero no puede modificar el estado del
anclaje externo ni falsificar una firma válida. Esa exclusión delimita al
adversario local; no describe ataques de red, una pasarela hostil ni la
disponibilidad de un servicio externo.

La resolución aprueba para esta frontera arquitectónica la siguiente premisa:

> El estado necesario para detectar rollback debe conservarse fuera del dominio
> que `THR-P1` puede restaurar junto con la base local.

Esta formulación delimita la comparación aprobada. No redefine `THR-P1` y no
demuestra por sí sola que cualquier canal o almacenamiento externo sea seguro.

## Pregunta exacta que requiere decisión

> ¿Qué frontera de confianza y qué modalidad de externalización deben utilizarse
> para mantener checkpoints fuera del dominio local restaurable, sin ampliar
> innecesariamente el alcance científico de PT2?

La resolución registrada identifica la configuración experimental principal,
el control, las demostraciones opcionales y las afirmaciones que cada papel
permite o prohíbe.

## Propiedad estudiada y aspectos de sistema

La propiedad de seguridad de interés es la capacidad de un verificador para
distinguir un historial local presentado de un estado anterior e internamente
válido cuando existe estado externo pertinente que el adversario local no puede
restaurar junto con ese historial.

Esta propiedad debe separarse de los siguientes aspectos:

| Aspecto | Papel conceptual | Lo que no debe asumirse |
|---|---|---|
| Propiedad de seguridad | Comparación del historial presentado con estado externo conservado. | No implica seguridad integral del canal, del servicio ni del dispositivo. |
| Almacenamiento externo | Retiene una confirmación o estado fuera del snapshot local. | “Externo” no implica automáticamente íntegro, disponible, confidencial ni vigente. |
| Transporte | Mueve el checkpoint desde el dominio local al externo. | Entrega iniciada no equivale a persistencia confirmada. |
| Pasarela | Puede transportar, validar estructura o registrar un sobre sin clave privada del POS. | No debe suponerse que una pasarela disponible sea honesta, ni que una pasarela honesta esté siempre disponible. |
| Recibo | Vincula un intento de externalización con una confirmación conservada. | Un recibo no asociado inequívocamente al checkpoint correcto no demuestra persistencia. |
| Verificador | Compara historial, checkpoint y estado externo usando material confiable apropiado. | No debe depender exclusivamente de una copia restaurable del supuesto estado externo. |
| Disponibilidad | Determina si la externalización y la consulta pueden completarse a tiempo. | Una falla de disponibilidad no prueba una violación de integridad. |
| Integridad | Permite detectar cambios no autorizados en sobres, recibos o registros. | Una firma válida no prueba por sí sola que el objeto sea el más reciente. |
| Confidencialidad | Limita exposición de identificadores, secuencias, tiempos y patrones de uso. | La firma no cifra metadatos. |
| Conectividad directa | Permite al POS comunicarse sin intermediario con un servicio externo. | No es requisito lógico para conservar estado fuera del snapshot ni prueba seguridad de red. |

## Fronteras conceptuales

### Dominio local restaurable

Conjunto de estado que `THR-P1` puede copiar y restaurar como una unidad,
incluida la base local y los artefactos locales contemplados por
`docs/04-threat-model.md`. Un archivo guardado en otra carpeta del mismo snapshot
no se vuelve externo solo por cambiar de ruta.

### Dominio externo

Estado conservado fuera del snapshot restaurable. Su separación debe poder
demostrarse en el montaje experimental. La independencia frente al rollback
local no resuelve por sí sola la disponibilidad, integridad, confidencialidad o
política de retención del componente externo.

### Canal de externalización

Mecanismo mediante el cual un checkpoint sale del dominio local. Puede ser una
abstracción en proceso, una pasarela lógica, un canal visual, un medio removible
o una conexión directa. El canal no se confunde con el almacenamiento que
finalmente conserva el estado.

### Pasarela

Componente opcional que transporta o registra el checkpoint. No posee ni recibe
la clave privada del POS. Puede afectar disponibilidad, orden y oportunidad de
entrega, pero no debe poder fabricar una firma válida atribuible al POS.

### Registro externo

Componente que conserva una confirmación o estado que el adversario local no
puede restaurar. La política futura deberá precisar qué conserva, cómo evita
confundir ledgers o terminales y qué significa que una confirmación sea vigente.

### Verificador independiente

Entidad que compara el historial presentado con el estado externo y con el
material público confiable requerido. Su independencia exige que la referencia
externa relevante no provenga únicamente del mismo snapshot local presentado.

## Supuestos y límites comunes

- el expediente no define todavía el formato ni la semántica normativa de un
  checkpoint;
- una firma solo puede evaluarse después de aprobar la codificación autenticada,
  el identificador de clave pública y las reglas de verificación;
- conservar un sobre firmado en almacenamiento no confiable puede proteger su
  autenticidad, pero no garantiza que el último sobre siga disponible;
- la frescura depende de qué confirmación externa se conserva y no solo de que
  una firma sea válida;
- la copia confiable de la clave pública debe obtenerse fuera de la capacidad de
  sustitución de `THR-P1`, conforme al modelo vigente;
- ninguna alternativa autoriza afirmar resistencia frente a ataques de red
  usando únicamente `THR-P1`;
- separar procesos en una misma máquina no basta si ambos quedan incluidos en el
  snapshot restaurable;
- los detalles productivos de identidad, alta disponibilidad, operación en nube
  y gestión comercial permanecen fuera del alcance de PT2.

## Criterios de evaluación

Cada alternativa debe evaluarse cualitativamente mediante los siguientes
criterios, sin asignar puntuaciones numéricas mientras no exista una escala
justificada:

1. **Capacidad para detectar rollback:** estado externo disponible para
   distinguir una copia antigua internamente válida.
2. **Separación respecto del dominio restaurable:** evidencia de que el estado
   relevante no se restaura junto con la base local.
3. **Reproducibilidad:** posibilidad de reconstruir el montaje desde un
   protocolo versionado.
4. **Automatización:** ejecución repetible sin intervención manual no
   controlada.
5. **Complejidad de implementación:** componentes, dependencias y fallos
   adicionales.
6. **Ampliación del alcance:** nuevas preguntas de red, operación, dispositivos
   o infraestructura introducidas.
7. **Superficie de ataque:** puntos adicionales de modificación, sustitución,
   retraso, pérdida o asociación errónea.
8. **Confianza en la pasarela:** acciones que una pasarela debe o no poder
   realizar.
9. **Confianza en el almacenamiento externo:** retención, disponibilidad,
   aislamiento y frescura exigidos.
10. **Disponibilidad:** posibilidad de exportar, confirmar y consultar.
11. **Integridad:** protección del checkpoint, del recibo y de su asociación.
12. **Confidencialidad de metadatos:** exposición de identidad, secuencia,
    tiempos y patrones de actividad.
13. **Medición computacional:** posibilidad de aislar operaciones ejecutadas por
    software.
14. **Medición operacional:** intervención humana, traslado y tiempo de proceso.
15. **Factibilidad para PT2:** costo y alcance compatibles con el artefacto.
16. **Validez de las conclusiones permitidas:** afirmaciones respaldadas por el
    montaje.
17. **Conclusiones que no pueden sostenerse:** límites explícitos de inferencia.

## Alternativas consideradas

El análisis de esta sección se conserva como fundamento de la resolución. El
papel decidido de cada alternativa se registra en `Estado de las alternativas`.

### Alternativa A — Sin anclaje externo

Todos los datos de confianza permanecen en el dominio local restaurable.

#### Capacidad y frontera

Sirve como control o línea base. Si `THR-P1` restaura una copia antigua completa
que conserva consistencia interna, no existe evidencia externa que permita al
verificador distinguirla del estado vigente.

#### Confianza, disponibilidad e integridad

No requiere pasarela ni almacenamiento externo. Su disponibilidad depende solo
de los componentes locales, pero esa simplicidad no aporta separación frente a
rollback. La autenticidad interna puede detectar modificaciones incompatibles
con los mecanismos, no la restauración completa de un estado antiguo válido.

#### Medición y alcance

Es altamente reproducible y automatizable. Permite medir el comportamiento
local sin costos de externalización y ofrece una línea base para comparaciones.
No permite concluir que el rollback completo sea detectable.

#### Ventajas

- mínima complejidad y superficie adicional;
- control claro para separar costo local de costo de externalización;
- no introduce supuestos de transporte o infraestructura externa.

#### Desventajas y consecuencias

- no satisface la propiedad de detección de rollback completo;
- toda referencia de frescura puede restaurarse con la base;
- solo permite conclusiones negativas o de línea base sobre evidencia externa.

### Alternativa B — Anclaje externo simulado

Un almacenamiento o proceso experimental se mantiene separado del snapshot
local. El transporte se abstrae mediante una interfaz controlada.

#### Capacidad y frontera

Puede permitir detectar rollback si el estado simulado realmente queda fuera de
la restauración local y conserva la confirmación pertinente. Una simulación
ubicada accidentalmente dentro del mismo snapshot invalidaría esa separación.

#### Confianza, disponibilidad e integridad

El montaje deberá declarar la política del proceso simulado y su retención
cuando esas especificaciones sean aprobadas. Puede aceptar sobres firmados sin
poseer claves privadas. Su integridad y disponibilidad son propiedades del
modelo simulado, no de una red real. Esta decisión no autoriza inyección de
fallos contra el canal.

#### Medición y alcance

Es automatizable, reproducible y apropiado para el benchmark principal. Permite
aislar generación, codificación, verificación y persistencia externa bajo un
entorno controlado. No permite afirmar seguridad, disponibilidad o latencia de
una red real.

#### Ventajas

- separación controlable respecto del snapshot;
- baja variación operacional;
- comportamiento reproducible y ejecución automatizada;
- menor ampliación de alcance que dispositivos o Internet.

#### Desventajas y consecuencias

- puede ocultar fallos propios de transporte y operación reales;
- exige demostrar que el almacenamiento simulado no se restaura con la base;
- sus conclusiones se limitan al modelo experimental implementado.

### Alternativa C — Pasarela lógica independiente

El POS o harness exporta un sobre firmado y una pasarela separada lo registra en
un dominio externo.

#### Capacidad y frontera

Puede permitir detectar rollback cuando la pasarela o el registro posterior
conservan un estado que el adversario local no restaura. Su selección como
demostración opcional no autoriza simular modificación, retraso, repetición,
duplicación, reordenamiento, descarte ni intercambio entre terminales.

#### Confianza, disponibilidad e integridad

La pasarela no recibe claves privadas y no debe poder fabricar una firma válida
del POS. Sus capacidades, garantías de disponibilidad y relación con el
registro externo requerirán especificación posterior. Este ADR no aprueba un
modelo de pasarela hostil.

#### Medición y alcance

Tiene potencial de automatización y hace visible una frontera operativa
adicional, pero se conserva únicamente como demostración opcional. No pertenece
al benchmark principal ni habilita inyección de fallos. Su implementación
requerirá una tarea separada.

#### Ventajas

- hace visible la separación entre productor, transporte y registro;
- evita entregar la clave privada a la pasarela;
- permite demostrar una separación lógica sin atribuirle capacidad de
  falsificación.

#### Desventajas y consecuencias

- aumenta estados, asociaciones y rutas de fallo;
- requiere definir semántica de recibos y retención;
- no demuestra seguridad de una red real salvo que exista un perfil y protocolo
  adicionales aprobados.

### Alternativa D — Canal visual QR

El POS presenta un sobre codificado visualmente para que otro dispositivo lo
capture y lo conserve fuera del dominio local.

#### Capacidad y frontera

Puede producir separación física y un flujo potencialmente unidireccional. La
detección depende de que el escaneo sea correcto, el sobre se asocie al ledger
adecuado y la confirmación quede efectivamente conservada.

#### Confianza, disponibilidad e integridad

La pantalla, cámara, codificación visual, dispositivo receptor y operador
afectan disponibilidad y asociación. La firma puede permitir detectar cambios
del sobre, pero no corrige automáticamente truncamiento, lectura incompleta,
repetición o asociación errónea.

#### Medición y alcance

Es útil como demostración. Introduce variación por cámara, pantalla, iluminación,
codificación, operador y errores de lectura. Sus tiempos operacionales no deben
mezclarse automáticamente con las métricas computacionales principales.

#### Ventajas

- externalización físicamente visible;
- posible canal unidireccional desde el POS;
- demostración intuitiva de separación de dominios.

#### Desventajas y consecuencias

- reproducibilidad y automatización menores;
- dependencias de hardware y operador;
- amplía el alcance hacia factores físicos y humanos;
- no permite generalizar rendimiento a otros canales.

### Alternativa E — Medio removible

El POS genera un archivo mínimo firmado que se transporta mediante
almacenamiento removible tratado como no confiable.

#### Capacidad y frontera

Puede separar el checkpoint del snapshot local después de retirar físicamente
el medio. La detección requiere que una copia pertinente se conserve y que el
verificador pueda identificarla como correspondiente al ledger y secuencia
correctos.

#### Confianza, disponibilidad e integridad

El medio puede sustituirse, perderse, contaminarse o presentar contenido
antiguo. La firma puede detectar modificación del sobre, pero no garantiza
disponibilidad ni selección del archivo más reciente. El POS no debe aceptar
archivos arbitrarios de retorno como requisito de este flujo.

#### Medición y alcance

La generación y verificación del archivo pueden automatizarse; el montaje,
desmontaje, traslado y selección son costos operacionales. Deben medirse
separadamente si una tarea futura autoriza métricas para ellos.

#### Ventajas

- no requiere conectividad directa;
- separación física sencilla de demostrar;
- sobre mínimo transportable y verificable.

#### Desventajas y consecuencias

- riesgos de sustitución, contaminación, montaje y operación;
- menor automatización y mayor variación humana;
- la pérdida o uso de una copia antigua afecta disponibilidad y frescura;
- no demuestra seguridad general del dispositivo removible.

### Alternativa F — Internet directo desde el POS

El POS establece una conexión directa con un servicio externo que conserva la
confirmación.

#### Capacidad y frontera

Puede permitir detección de rollback cuando el servicio conserva un estado
vigente fuera del snapshot y el verificador puede consultarlo de manera
confiable.

#### Confianza, disponibilidad e integridad

Introduce pila de red, DNS, TLS, autenticación, credenciales, reintentos,
bibliotecas, configuración y mantenimiento. Debe declararse qué aspectos de la
red y del servicio quedan fuera de alcance. `THR-P1` no basta para afirmar
resistencia frente a adversarios de red.

#### Medición y alcance

Reduce fricción operacional una vez configurado, pero incorpora variación de
red y dependencias externas. La latencia observada combina componentes que no
pertenecen automáticamente al núcleo computacional del benchmark.

#### Ventajas

- externalización directa y automatizable;
- menor intervención humana durante la operación normal;
- parecido superficial a un despliegue conectado.

#### Desventajas y consecuencias

- mayor ampliación del alcance y superficie de ataque;
- reproducibilidad dependiente de red y servicio;
- gestión de credenciales y fallos operativos adicionales;
- no permite sostener seguridad de red basándose solo en el experimento local.

## Matriz comparativa cualitativa

Las matrices siguientes conservan el análisis cualitativo de los diecisiete
criterios sin asignar puntuaciones numéricas. Los papeles decididos se registran
posteriormente y prevalecen sobre las posibilidades descritas en este análisis.

### Seguridad, separación y confianza

| Alternativa | Detección de rollback | Separación del dominio restaurable | Superficie de ataque | Confianza en pasarela | Confianza en almacenamiento externo |
|---|---|---|---|---|---|
| A — Sin anclaje | No distingue rollback completo internamente válido. | Ninguna. | Solo local; no añade canal. | No aplica. | No existe. |
| B — Simulado | Posible si conserva la confirmación pertinente. | Lógica o de proceso, demostrable fuera del snapshot. | Interfaz y proceso simulado. | Política controlada del simulador. | Retención y aislamiento configurados experimentalmente. |
| C — Pasarela | Posible tras registro externo confirmado. | Pasarela o registro separado. | Superficie adicional no evaluada adversarialmente en esta etapa. | No recibe claves privadas; sus demás capacidades siguen pendientes. | Debe conservar estado verificable y vigente. |
| D — QR | Posible después de escaneo y conservación correctos. | Física mediante dispositivo receptor. | Pantalla, cámara, codificación, operador y asociación. | Operador o receptor afecta entrega, no debe falsificar firmas. | Retención en dispositivo o registro receptor. |
| E — Removible | Posible si se conserva y selecciona la copia pertinente. | Física después de retirar el medio. | Sustitución, contaminación, pérdida, montaje y selección. | Operación humana; no requiere pasarela lógica. | Medio no confiable para disponibilidad o frescura; firma protege autenticidad del sobre. |
| F — Internet | Posible tras confirmación conservada por el servicio. | Servicio externo al snapshot. | DNS, TLS, autenticación, red, servicio y dependencias. | No aplica o queda integrada en el servicio. | Requiere retención, consulta y operación del servicio. |

### Reproducibilidad, automatización, complejidad y factibilidad

| Alternativa | Reproducibilidad | Automatización | Complejidad | Ampliación del alcance | Factibilidad para PT2 |
|---|---|---|---|---|---|
| A — Sin anclaje | Alta. | Alta. | Mínima. | Ninguna adicional. | Alta como control, insuficiente para la propiedad externa. |
| B — Simulado | Alta con protocolo y estado aislado. | Alta. | Baja a media. | Limitada al modelo simulado. | Alta para el benchmark principal. |
| C — Pasarela | Alta si la pasarela es controlada y versionada. | Alta. | Media. | Añade una frontera lógica; no añade tratamientos aprobados de fallos. | Media como demostración opcional. |
| D — QR | Sensible a hardware y entorno. | Baja a media. | Media a alta. | Añade dispositivos y factores humanos. | Media como demostración, baja como núcleo repetible. |
| E — Removible | Sensible al procedimiento físico. | Media para archivos, baja para traslado. | Media. | Añade operación y seguridad del medio. | Media como demostración. |
| F — Internet | Sensible a red, proveedor y configuración. | Alta durante operación. | Alta. | Añade red y servicio externo. | Baja a media para el núcleo de PT2. |

### Propiedades, medición y validez de conclusiones

| Alternativa | Disponibilidad | Integridad | Confidencialidad de metadatos | Medición computacional | Medición operacional | Conclusiones permitidas | Conclusiones no sostenibles |
|---|---|---|---|---|---|---|---|
| A — Sin anclaje | Solo local. | Mecanismos locales, sin frescura externa. | No hay exportación. | Clara línea base local. | No aplica. | Costos y límites del caso local. | Detección de rollback completo. |
| B — Simulado | Pendiente de especificación; no se evalúa un canal hostil. | Verificable dentro del modelo. | Debe registrarse la exposición del sobre. | Aislable y repetible. | Mínima. | Detección y costos bajo el simulador. | Seguridad o rendimiento de red real. |
| C — Pasarela | Garantías pendientes de especificación. | Firma del sobre y asociación aún por especificar. | La pasarela observa metadatos exportados. | Fuera de las métricas principales. | Baja si se automatiza. | Factibilidad demostrativa de una separación lógica. | Fallos adversariales, seguridad de Internet o disponibilidad productiva. |
| D — QR | Depende de lectura y operador. | Firma detectable; asociación y lectura pueden fallar. | Visible para observadores y dispositivo receptor. | Codificación y verificación aislables. | Escaneo y confirmación relevantes. | Factibilidad demostrativa del canal visual. | Comparabilidad directa con latencias puramente computacionales. |
| E — Removible | Depende de medio y custodia. | Firma detectable; selección y frescura no garantizadas. | Metadatos visibles a quien acceda al medio. | Archivo, firma y verificación aislables. | Montaje, traslado y selección relevantes. | Factibilidad de transporte físico de un sobre mínimo. | Seguridad general del medio o ausencia de contaminación. |
| F — Internet | Depende de red y servicio. | Requiere transporte y servicio configurados; alcance pendiente. | Servicio y red observan metadatos salvo protección adicional. | Se mezcla con bibliotecas y red si no se separa. | Baja intervención humana normal. | Comportamiento de la configuración concreta. | Seguridad de red general usando solo `THR-P1`. |

## Sobre candidato de exportación

Los siguientes son únicamente campos candidatos para discusión:

- `protocol_version`
- `ledger_id`
- `checkpoint_sequence`
- `terminal_sequence`
- `checkpoint_hash`
- `previous_checkpoint_hash`
- `mechanism_id`
- `created_at_claim`
- `public_key_id`
- `signature`

Los campos no están aprobados y no crean todavía un esquema. Debe decidirse la
codificación autenticada exacta, el orden, los tipos, los dominios, el
versionado y las condiciones de rechazo. `created_at_claim` sería una afirmación
del reloj local y no necesariamente una fuente temporal confiable.

La exportación no debe incluir:

- la base SQLite completa;
- la clave HMAC;
- la clave privada Ed25519;
- credenciales del anclaje provenientes del POS cuando se utilice una pasarela.

Una pasarela que necesite credenciales propias deberá mantenerlas fuera del POS
y fuera del sobre, conforme a una decisión futura autorizada.

## Recibo y confirmación

Debe distinguirse entre:

1. intento de envío;
2. recepción por el canal o pasarela;
3. persistencia en el registro externo;
4. confirmación disponible para el verificador.

La semántica, autenticidad, asociación y retención de un recibo continúan
pendientes. Un recibo útil tendría que vincularse inequívocamente al checkpoint
correcto y no puede inferirse solo porque una operación de transporte retornó
sin error. Este expediente no fija campos ni formato de recibo.

## Canal adversarial pendiente

La selección de C como demostración opcional no autoriza inyección de fallos.
No se aprueban ataques contra el canal, no se crea `THR-P2` y no se crean
identificadores `ATT-*`.

Continúan pendientes, como posibles materias de una evaluación futura:

- modificación;
- repetición;
- duplicación;
- reordenamiento;
- retraso;
- descarte;
- intercambio entre terminales;
- asociación con un recibo incorrecto.

Cualquier evaluación adversarial del canal requerirá primero un perfil de
amenaza independiente, con capacidades explícitas, activos y fronteras
definidos, ataques normativos trazables y aprobación posterior del investigador.
Este expediente no modifica `THR-P1`. Hasta obtener esas aprobaciones, las
conductas enumeradas no son ataques normativos implementables.

## Costos y futuras mediciones

Este ADR clasifica costos, pero no crea nuevas métricas normativas.

### Costos computacionales

- generación del checkpoint;
- firma;
- codificación;
- verificación;
- persistencia externa.

### Costos de comunicación

- bytes exportados;
- bytes de recibo;
- número de mensajes;
- latencia de transferencia.

### Costos operacionales

- intervención humana;
- traslado físico;
- escaneo;
- tiempo hasta confirmación.

El tiempo humano, el traslado y el escaneo no forman parte de
`MET-APPEND-READY-E2E` y no deben mezclarse con esa métrica. Cualquier región de
medición futura requerirá un contrato y trazabilidad aprobados.

## Ventana conceptual de rollback

La capacidad de detección depende conjuntamente de:

- frecuencia de generación de checkpoints;
- frecuencia de externalización;
- confirmaciones efectivamente conservadas;
- retrasos;
- checkpoints perdidos o descartados.

Un checkpoint generado pero nunca externalizado no aporta el mismo estado
externo que una confirmación conservada. Un retraso o descarte puede ampliar el
intervalo durante el cual una restauración no es distinguible mediante el
estado disponible.

Este expediente no fija una fórmula normativa, un intervalo, parámetros
experimentales ni reglas de agregación. Esas decisiones deberán coordinarse con
el protocolo de checkpoints y el plan de medición cuando sean autorizadas.

## Riesgos transversales

- llamar “externo” a un proceso o archivo incluido en el snapshot restaurable;
- confundir firma válida con prueba de frescura;
- aceptar como confirmada una entrega que no fue persistida;
- asociar un recibo al ledger, terminal o checkpoint incorrecto;
- presumir garantías de disponibilidad de una pasarela todavía no especificadas;
- permitir que una pasarela reciba claves privadas o credenciales del POS;
- exportar la base completa o material secreto por conveniencia;
- exponer patrones temporales o identificadores sin declarar su impacto;
- mezclar costos humanos, físicos, de red y computacionales;
- generalizar resultados de una simulación a una red real;
- ampliar PT2 hacia infraestructura productiva, seguridad de red o gestión
  comercial de identidades;
- definir fallos del canal como ataques normativos sin un perfil aprobado;
- congelar el formato del sobre antes de resolver su codificación autenticada.

## Recomendación técnica no vinculante considerada

> Utilizar un anclaje externo simulado, fuera del snapshot restaurable, como
> configuración experimental principal; reservar una pasarela fuera de banda
> como demostración opcional; mantener Internet directo fuera del núcleo
> experimental.

Esta recomendación fue una entrada técnica no vinculante y no constituye por sí
sola la decisión normativa. Fue considerada, modificada y resuelta por el
investigador. Se conserva para auditar qué partes fueron aceptadas, ampliadas o
modificadas. La decisión normativa aplicable es la registrada posteriormente en
`## Resolución aprobada` y `## Decisión del investigador`.

## Resolución aprobada

El investigador resolvió la recomendación provisional: B es la configuración
experimental principal, A es el control negativo, C, D y E son demostraciones
opcionales, y F queda fuera del núcleo experimental. Esta resolución se limita a
la frontera arquitectónica; no autoriza todavía las especificaciones derivadas
ni desbloquea mecanismos o métricas.

## Estado de las alternativas

| Alternativa | Estado decidido        | Papel                                                 |
| ----------- | ---------------------- | ----------------------------------------------------- |
| A           | SELECTED_CONTROL       | Control negativo                                      |
| B           | SELECTED_PRIMARY       | Configuración experimental principal                  |
| C           | OPTIONAL_DEMONSTRATION | Demostración opcional; sin ataques de canal aprobados |
| D           | OPTIONAL_DEMONSTRATION | Demostración visual opcional                          |
| E           | OPTIONAL_DEMONSTRATION | Demostración con medio removible opcional             |
| F           | OUT_OF_CORE_SCOPE      | Fuera del núcleo experimental                         |

Estos valores describen exclusivamente el papel decidido dentro de ADR-004. No
son nuevos estados generales del sistema documental y no sustituyen el estado
documental `APPROVED` del expediente.

## Preguntas pendientes para el investigador

- ¿Qué estado mínimo debe retener el registro externo?
- ¿Qué política de retención se exige al almacenamiento externo?
- ¿Qué propiedad de frescura se exige al estado externo?
- ¿Qué evento constituye una confirmación efectivamente conservada?
- ¿Cómo se asocia el estado externo con ledger, terminal y checkpoint?
- ¿Quién verifica la firma y en qué etapa debe hacerlo?
- ¿De dónde obtiene el verificador la clave pública confiable?
- ¿Qué codificación autenticada tendrá el sobre?
- ¿Qué reglas de versionado tendrá el sobre y el protocolo?
- ¿Qué confidencialidad requieren los metadatos exportados?
- ¿Qué costos futuros requieren métricas normativas independientes?
- ¿Qué frecuencias de generación de checkpoints y externalización se definirán?
- ¿Qué perfil separado modelaría al adversario del canal?
- ¿Qué ataques del canal podrían proponerse bajo ese perfil?
- ¿Qué criterios, propósito probatorio y evidencia se exigirían para implementar
  una posible demostración opcional?

## Decisión del investigador

### Configuración experimental principal

Se selecciona la alternativa B, anclaje externo simulado, como configuración
experimental principal. El estado externo pertinente deberá persistir fuera del
dominio local restaurable y esa separación deberá poder demostrarse
experimentalmente.

El anclaje simulado representa la frontera necesaria para estudiar rollback,
pero no representa ni simula necesariamente una red productiva. Sus resultados
no permiten concluir seguridad, disponibilidad o latencia de Internet.

### Control

Se selecciona la alternativa A como control negativo para demostrar las
limitaciones de mantener todo el estado confiable dentro del dominio
restaurable. A no constituye una solución de detección de rollback completo.

### Demostraciones opcionales

Se conservan únicamente como demostraciones opcionales:

- C, pasarela lógica independiente;
- D, canal visual QR;
- E, medio removible.

Ninguna pertenece al benchmark principal en esta etapa ni forma parte de las
métricas computacionales principales. Sus costos operacionales no deberán
mezclarse con tiempos criptográficos. Cada implementación requerirá una tarea
separada y podrá omitirse sin invalidar el experimento principal.

En particular, C no es una configuración secundaria para inyección de fallos y
su papel opcional no autoriza todavía inyección de fallos.

### Canal adversarial pendiente

No se aprueban ataques contra el canal, no se crea `THR-P2` y no se crean
identificadores `ATT-*`. Modificación, repetición, duplicación, reordenamiento,
retraso, descarte, intercambio entre terminales y cualquier otra conducta
adversarial del canal continúan pendientes.

Cualquier evaluación adversarial requerirá primero un perfil de amenaza
independiente con capacidades explícitas, activos y fronteras definidos, ataques
normativos trazables y aprobación posterior del investigador.

### Fuera del núcleo experimental

La alternativa F, Internet directo desde el POS, queda fuera del núcleo
experimental de PT2. Esta exclusión evita ampliar el proyecto hacia seguridad de
red, TLS, DNS, disponibilidad productiva, autenticación de servicios y operación
remota.

La exclusión no significa que Internet directo sea intrínsecamente inseguro.
`THR-P1` no cubre ataques de red y esta decisión no afirma lo contrario.

### Verificación independiente

El verificador consultará el estado externo de forma independiente. El estado
externo relevante no podrá obtenerse únicamente del snapshot local presentado.
En la configuración principal, el POS no importará un recibo del anclaje; la
ausencia de ese recibo importado reduce el canal de entrada al POS.

Continúa pendiente definir qué constituye una confirmación externa válida y cómo
obtiene el verificador una clave pública confiable.

### Límite de la aprobación

La aprobación se limita a la frontera arquitectónica y al papel experimental de
las alternativas. No aprueba todavía:

- el formato del checkpoint;
- la codificación autenticada del sobre;
- el protocolo de anclaje;
- la semántica normativa de confirmación;
- clases Java;
- tablas SQLite;
- endpoints;
- perfiles de amenaza adicionales;
- ataques;
- nuevas métricas;
- parámetros experimentales.

## Consecuencias de la decisión seleccionada

### Consecuencias positivas

- separación clara entre el estado externo y el dominio local restaurable;
- reproducibilidad y automatización del montaje principal;
- baja variabilidad operacional;
- comparación directa con el control A;
- alcance compatible con PT2;
- aislamiento de la propiedad de detección de rollback respecto de la seguridad
  de red.

### Limitaciones

- las conclusiones solo aplican al modelo de anclaje simulado aprobado;
- no se demuestra seguridad de Internet, nube, TLS, DNS o redes;
- no se evalúa todavía un canal hostil;
- no se demuestra disponibilidad productiva;
- QR, medio removible y pasarela no forman parte de las métricas principales;
- la aprobación no especifica formatos ni parámetros.

### Trabajo derivado autorizado

Esta decisión autoriza redactar, en tareas posteriores y separadas:

- `docs/07-checkpoint-protocol.md`;
- `docs/08-anchor-protocol.md`;
- `docs/13-harness-architecture.md`.

También autoriza evaluar posteriormente si deben armonizarse:

- `docs/02-research-questions.md`;
- `docs/11-measurement-contract.md`;
- `docs/16-traceability-matrix.csv`.

Esta autorización no modifica esos documentos en la tarea actual, salvo las
filas expresamente autorizadas de la matriz de trazabilidad.

### Bloqueos que permanecen

`MEC-A1` y `MET-APPEND-READY-E2E` continúan en estado `BLOCKED`. ADR-004 no
resuelve por sí sola:

- ADR-001;
- ADR-002;
- ADR-003;
- la codificación autenticada;
- la provisión de claves;
- la frontera temporal de medición.

La decisión tampoco congela `RQ-03` o `RQ-04` ni permite implementar ataques,
protocolos o mecanismos nuevos.

## Documentos afectados

- `docs/02-research-questions.md`
- `docs/04-threat-model.md`
- `docs/07-checkpoint-protocol.md`
- `docs/08-anchor-protocol.md`
- `docs/11-measurement-contract.md`
- `docs/13-harness-architecture.md`
- `docs/16-traceability-matrix.csv`
- `docs/decisions/README.md`

Además de este expediente, solo la matriz y el registro de decisiones se
actualizan en esta tarea. Los demás documentos requerirán tareas posteriores
separadas.

## Identificadores de trazabilidad

- `RQ-03`
- `RQ-04`
- `THR-P1`
- `ADR-004`
