# threat-model
ID: THR-P1
Nombre: escritura arbitraria sin secretos

Puede:
- modificar SQLite;
- insertar o eliminar filas;
- recalcular SHA-256;
- restaurar archivos locales.

No puede:
- obtener la clave HMAC;
- obtener la clave privada Ed25519;
- modificar el estado del anclaje externo.