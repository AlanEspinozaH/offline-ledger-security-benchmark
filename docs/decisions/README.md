# Registro de decisiones

Este directorio conserva decisiones normativas, metodológicas y
arquitectónicas relevantes para el artefacto experimental de PT2.

Codex y otros agentes pueden identificar ambigüedades y proponer alternativas,
pero únicamente el investigador puede aprobar una decisión.

## Estados

- `DRAFT`
- `PROVISIONAL`
- `APPROVED`
- `SUPERSEDED`
- `REJECTED`

## Convención

Cada decisión utiliza un identificador `ADR-NNN`. Todo ADR debe declarar en su
front matter, como mínimo:

- `decision_id`;
- `title`;
- `version`;
- `status`;
- `date`;
- `decided_by`.

La versión sigue versionado semántico. Toda modificación sustantiva del
expediente debe producir una nueva versión antes de solicitar aprobación. La
aprobación, cuando exista, se refiere a una versión concreta.

Además, cada expediente debe registrar:

- contexto;
- problema exacto que requiere decisión;
- criterios de evaluación;
- alternativas concretas;
- ventajas, desventajas y consecuencias de cada alternativa;
- riesgos;
- recomendación técnica no vinculante;
- decisión del investigador;
- consecuencias de la decisión seleccionada;
- documentos e identificadores afectados.

Mientras la decisión del investigador sea `PENDING`, sus consecuencias
seleccionadas también permanecen `PENDING` y el expediente no desbloquea una
implementación.
