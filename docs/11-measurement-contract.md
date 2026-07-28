# measurement-contract
ID: MET-APPEND-HOT
Unidad: nanosegundos

Inicio:
Después de abrir la conexión y cargar las claves.

Fin:
Después del commit de la transacción.

Incluye:
- canonicalización;
- autenticación;
- INSERT;
- COMMIT.

Excluye:
- generación de claves;
- derivación Argon2;
- creación de esquema;
- exportación de resultados.