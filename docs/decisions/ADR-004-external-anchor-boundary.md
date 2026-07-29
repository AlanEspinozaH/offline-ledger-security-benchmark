---
decision_id: ADR-004
title: External Anchor and Checkpoint Externalization Boundary
version: 0.1.0
status: DRAFT
date: PENDING
decided_by: PENDING
---

# ADR-004 — Frontera del anclaje externo y externalización de checkpoints

## Estado y alcance del expediente

Este expediente documenta una decisión pendiente. No selecciona ni aprueba una
modalidad de externalización, no autoriza implementación y no define todavía
clases, endpoints, sockets, formatos binarios, tablas SQLite ni servicios de
red.

Los contratos `docs/07-checkpoint-protocol.md` y
`docs/08-anchor-protocol.md` todavía no contienen una especificación normativa
implementable. Este ADR organiza las alternativas que el investigador deberá
aceptar, modificar o rechazar conforme a `docs/01-change-control.md`.

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

Se evaluará la siguiente hipótesis arquitectónica común:

> El estado necesario para detectar rollback debe conservarse fuera del dominio
> que `THR-P1` puede restaurar junto con la base local.

Esta formulación es una hipótesis de diseño para comparar alternativas. No está
aprobada, no redefine `THR-P1` y no demuestra por sí sola que cualquier canal o
almacenamiento externo sea seguro.

## Pregunta exacta que requiere decisión

> ¿Qué frontera de confianza y qué modalidad de externalización deben utilizarse
> para mantener checkpoints fuera del dominio local restaurable, sin ampliar
> innecesariamente el alcance científico de PT2?

La decisión futura debe identificar una configuración experimental principal,
las demostraciones opcionales —si las hubiera— y las afirmaciones que cada
configuración permite o prohíbe.

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

Ninguna alternativa de esta sección está aprobada o rechazada formalmente.

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

El montaje debe declarar la política del proceso simulado, su retención y los
fallos inyectados. Puede aceptar sobres firmados sin poseer claves privadas. Su
integridad y disponibilidad son propiedades del modelo simulado, no de una red
real.

#### Medición y alcance

Es automatizable, reproducible y apropiado para el benchmark principal. Permite
aislar generación, codificación, verificación y persistencia externa bajo un
entorno controlado. No permite afirmar seguridad, disponibilidad o latencia de
una red real.

#### Ventajas

- separación controlable respecto del snapshot;
- baja variación operacional;
- fallos reproducibles y ejecución automatizada;
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
conservan un estado que el adversario local no restaura. La pasarela puede
simular modificación, retraso, repetición, reordenamiento o descarte.

#### Confianza, disponibilidad e integridad

La pasarela no recibe claves privadas. Puede negar, retrasar, duplicar o
reordenar entregas y afectar disponibilidad, pero no debe poder fabricar una
firma válida del POS. La confianza necesaria en ella depende de si el registro
externo verifica firmas, conserva orden o emite recibos.

#### Medición y alcance

Es automatizable y permite separar fallos de canal de fallos criptográficos.
Añade un componente y una frontera operativa, pero puede mantenerse como
demostración controlada sin desplegar una red productiva.

#### Ventajas

- hace visible la separación entre productor, transporte y registro;
- permite inyectar fallos del canal de forma controlada;
- evita entregar la clave privada a la pasarela;
- permite estudiar disponibilidad sin atribuirle capacidad de falsificación.

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

Las matrices siguientes cubren los diecisiete criterios sin asignar puntuaciones
numéricas ni declarar una alternativa ganadora.

### Seguridad, separación y confianza

| Alternativa | Detección de rollback | Separación del dominio restaurable | Superficie de ataque | Confianza en pasarela | Confianza en almacenamiento externo |
|---|---|---|---|---|---|
| A — Sin anclaje | No distingue rollback completo internamente válido. | Ninguna. | Solo local; no añade canal. | No aplica. | No existe. |
| B — Simulado | Posible si conserva la confirmación pertinente. | Lógica o de proceso, demostrable fuera del snapshot. | Interfaz y proceso simulado. | Política controlada del simulador. | Retención y aislamiento configurados experimentalmente. |
| C — Pasarela | Posible tras registro externo confirmado. | Pasarela o registro separado. | Manipulación, orden, retraso, descarte y asociación. | No falsifica firmas; sí puede afectar entrega. | Debe conservar estado verificable y vigente. |
| D — QR | Posible después de escaneo y conservación correctos. | Física mediante dispositivo receptor. | Pantalla, cámara, codificación, operador y asociación. | Operador o receptor afecta entrega, no debe falsificar firmas. | Retención en dispositivo o registro receptor. |
| E — Removible | Posible si se conserva y selecciona la copia pertinente. | Física después de retirar el medio. | Sustitución, contaminación, pérdida, montaje y selección. | Operación humana; no requiere pasarela lógica. | Medio no confiable para disponibilidad o frescura; firma protege autenticidad del sobre. |
| F — Internet | Posible tras confirmación conservada por el servicio. | Servicio externo al snapshot. | DNS, TLS, autenticación, red, servicio y dependencias. | No aplica o queda integrada en el servicio. | Requiere retención, consulta y operación del servicio. |

### Reproducibilidad, automatización, complejidad y factibilidad

| Alternativa | Reproducibilidad | Automatización | Complejidad | Ampliación del alcance | Factibilidad para PT2 |
|---|---|---|---|---|---|
| A — Sin anclaje | Alta. | Alta. | Mínima. | Ninguna adicional. | Alta como control, insuficiente para la propiedad externa. |
| B — Simulado | Alta con protocolo y estado aislado. | Alta. | Baja a media. | Limitada al modelo simulado. | Alta para el benchmark principal. |
| C — Pasarela | Alta si la pasarela es controlada y versionada. | Alta. | Media. | Añade frontera y fallos de canal. | Media a alta como demostración o tratamiento controlado. |
| D — QR | Sensible a hardware y entorno. | Baja a media. | Media a alta. | Añade dispositivos y factores humanos. | Media como demostración, baja como núcleo repetible. |
| E — Removible | Sensible al procedimiento físico. | Media para archivos, baja para traslado. | Media. | Añade operación y seguridad del medio. | Media como demostración. |
| F — Internet | Sensible a red, proveedor y configuración. | Alta durante operación. | Alta. | Añade red y servicio externo. | Baja a media para el núcleo de PT2. |

### Propiedades, medición y validez de conclusiones

| Alternativa | Disponibilidad | Integridad | Confidencialidad de metadatos | Medición computacional | Medición operacional | Conclusiones permitidas | Conclusiones no sostenibles |
|---|---|---|---|---|---|---|---|
| A — Sin anclaje | Solo local. | Mecanismos locales, sin frescura externa. | No hay exportación. | Clara línea base local. | No aplica. | Costos y límites del caso local. | Detección de rollback completo. |
| B — Simulado | Definida por fallos inyectados. | Verificable dentro del modelo. | Debe registrarse la exposición del sobre. | Aislable y repetible. | Mínima. | Detección y costos bajo el simulador. | Seguridad o rendimiento de red real. |
| C — Pasarela | Puede degradarse por retraso o descarte. | Firma del sobre y asociación aún por especificar. | La pasarela observa metadatos exportados. | Aislable por componentes. | Baja si se automatiza. | Efectos de una pasarela modelada y fallos controlados. | Seguridad de Internet o disponibilidad productiva. |
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

## Fallos y adversario del canal pendientes

Un futuro perfil separado deberá considerar, como mínimo:

- modificación;
- repetición;
- duplicación;
- reordenamiento;
- retraso;
- descarte;
- intercambio entre terminales;
- asociación con un recibo incorrecto.

Este expediente no asigna identificadores de ataque, no modifica `THR-P1` y no
crea un segundo perfil de amenaza. Hasta que ese perfil y sus operaciones sean
aprobados, estas conductas son materias pendientes y no ataques normativos
implementables.

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
- confiar en la disponibilidad de una pasarela que puede descartar mensajes;
- permitir que una pasarela reciba claves privadas o credenciales del POS;
- exportar la base completa o material secreto por conveniencia;
- exponer patrones temporales o identificadores sin declarar su impacto;
- mezclar costos humanos, físicos, de red y computacionales;
- generalizar resultados de una simulación a una red real;
- ampliar PT2 hacia infraestructura productiva, seguridad de red o gestión
  comercial de identidades;
- definir fallos del canal como ataques normativos sin un perfil aprobado;
- congelar el formato del sobre antes de resolver su codificación autenticada.

## Recomendación técnica provisional no vinculante

> Utilizar un anclaje externo simulado, fuera del snapshot restaurable, como
> configuración experimental principal; reservar una pasarela fuera de banda
> como demostración opcional; mantener Internet directo fuera del núcleo
> experimental.

La recomendación no está aprobada. El investigador debe aceptarla, modificarla o
rechazarla. No autoriza implementación, no desbloquea mecanismos, no congela
`RQ-03` ni `RQ-04` y no convierte ninguna alternativa en decisión final.

## Estado de las alternativas

Todas las alternativas A–F permanecen pendientes. Las desventajas descritas
explican por qué una opción podría no ser recomendable para el núcleo
experimental, pero ninguna está formalmente rechazada.

## Preguntas pendientes para el investigador

- ¿Cuál alternativa debe ser la configuración experimental principal?
- ¿Debe existir una demostración opcional y cuál sería su propósito probatorio?
- ¿Qué estado mínimo debe retener el registro externo?
- ¿Qué propiedades de retención y frescura se exigen al almacenamiento externo?
- ¿Qué evento constituye una confirmación efectivamente conservada?
- ¿Cómo se asocia un recibo con ledger, terminal y checkpoint?
- ¿Quién verifica la firma antes de persistir o consultar?
- ¿De dónde obtiene el verificador la clave pública confiable?
- ¿Qué codificación autenticada y reglas de versionado tendrá el sobre?
- ¿Cómo se tratan sobres repetidos, atrasados, reordenados o descartados?
- ¿Qué confidencialidad requieren los metadatos exportados?
- ¿Qué responsabilidades conserva una pasarela y cuáles pertenecen al registro?
- ¿Qué aspectos del canal requieren un perfil de amenaza separado?
- ¿Qué costos futuros requieren métricas normativas independientes?
- ¿Cómo se relacionarán generación, externalización y confirmación sin fijar
  prematuramente la ventana de rollback?
- ¿Qué aspectos de Internet deben permanecer explícitamente fuera de alcance?

## Decisión del investigador

PENDING

## Consecuencias de la decisión seleccionada

PENDING. Este expediente no autoriza una modalidad de externalización, no
desbloquea `MEC-A1` ni `MET-APPEND-READY-E2E`, no congela preguntas de
investigación y no permite implementar ataques o mecanismos nuevos.

## Documentos afectados

- `docs/02-research-questions.md`
- `docs/04-threat-model.md`
- `docs/07-checkpoint-protocol.md`
- `docs/08-anchor-protocol.md`
- `docs/11-measurement-contract.md`
- `docs/13-harness-architecture.md`
- `docs/16-traceability-matrix.csv`
- `docs/decisions/README.md`

Solo la matriz y el registro de decisiones se actualizan en esta tarea. Los
demás documentos requerirán tareas autorizadas después de una decisión del
investigador.

## Identificadores de trazabilidad

- `RQ-03`
- `RQ-04`
- `THR-P1`
- `ADR-004`
