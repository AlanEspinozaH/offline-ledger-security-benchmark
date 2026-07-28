# AGENTS.md

## Propósito del repositorio

Este repositorio implementa el artefacto experimental de Proyecto de Tesis II. El software debe ajustarse a las especificaciones normativas ubicadas en `docs/spec/`, los esquemas ubicados en `schemas/` y las pruebas de conformidad ubicadas en `src/test/.../conformance/`.

El repositorio no contiene ni pretende reconstruir un sistema POS completo.

## Orden de autoridad

En caso de conflicto, prevalece este orden:

1. Especificaciones aprobadas en `docs/spec/`.
2. JSON Schemas en `schemas/`.
3. Pruebas de conformidad.
4. Planes experimentales.
5. Implementación.
6. Documentación descriptiva.

El código no puede redefinir silenciosamente una especificación.

## Restricciones de alcance

No implementar salvo que una tarea aprobada lo solicite explícitamente:

* interfaz gráfica;
* lógica de ventas o inventario;
* sincronización de transacciones;
* CRDT;
* blockchain;
* autenticación comercial;
* panel web;
* ataques de red;
* compromiso de claves;
* múltiples algoritmos alternativos no especificados.

## Reglas de implementación

* Todos los mecanismos deben recibir exactamente los bytes producidos por `RecordCodec`.
* El orquestador no debe contener ramas especiales por mecanismo.
* La lógica específica pertenece a implementaciones de contratos o políticas.
* Los ataques deben producir un oráculo estructurado.
* Los verificadores deben devolver resultados estructurados conformes a los esquemas.
* El harness debe escribir datos crudos y no conclusiones académicas.
* La generación, carga o derivación de claves no puede ocurrir dentro de regiones `append-hot` o `verify-hot`, salvo que una métrica lo especifique expresamente.
* No incorporar passphrases, claves o secretos en el código fuente.
* No modificar archivos de `docs/spec/` o `schemas/` salvo que la tarea lo autorice.
* Todo comportamiento nuevo debe incluir pruebas.
* Todo campo nuevo de evidencia debe tener un requisito o métrica asociada.

## Trazabilidad

Cada cambio debe indicar los identificadores aplicables, por ejemplo:

* `RQ-*`: pregunta de investigación;
* `REQ-*`: requisito;
* `MEC-*`: mecanismo;
* `THR-*`: perfil de adversario;
* `ATT-*`: ataque;
* `MET-*`: métrica;
* `TST-*`: prueba.

## Criterio de finalización

Una tarea solo se considera terminada cuando:

1. compila;
2. supera pruebas unitarias y de conformidad;
3. cumple los esquemas;
4. no modifica el alcance sin una decisión registrada;
5. actualiza la matriz de trazabilidad cuando corresponda;
6. documenta cualquier desviación conocida.
