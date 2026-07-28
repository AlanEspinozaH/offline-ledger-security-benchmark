# mechanism-specifications
MEC-A1 — HMAC por registro

Entrada:
- ledgerId
- sequence
- canonicalRecord
- secretKey

Autenticador:
HMAC-SHA-256(
  domain || version || ledgerId || sequence || canonicalRecord
)

Estado persistido:
- sequence
- record
- tag

Garantías esperadas:
- autenticación individual mientras la clave permanezca secreta.

No garantiza:
- detección de rollback completo sin estado terminal confiable externo.