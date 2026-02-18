# Imprimir ticket ESC/POS con PrintNode

Con **PrintNode** el ticket se envía desde el servidor a la impresora. Funciona desde **tutarjetaroja.com** sin instalar QZ Tray ni certificados en el PC: solo hace falta el cliente PrintNode en el equipo donde está la impresora.

## 1. Cuenta y cliente PrintNode

1. Regístrate en [PrintNode](https://www.printnode.com) y obtén tu **API Key** en [API Keys](https://app.printnode.com/apikeys).
2. Instala el **cliente PrintNode** en el PC donde está la impresora térmica USB: [Descargar](https://www.printnode.com/download).
3. Inicia sesión en el cliente con la misma cuenta; la impresora aparecerá en tu cuenta.

## 2. Configurar la API Key en Rails (credentials)

Añade la API key en las credentials del entorno que uses (por ejemplo production):

```bash
EDITOR="code --wait" rails credentials:edit --environment production
```

Añade (sustituye por tu API key):

```yaml
printnode_api_key: BvAGSbuO3UMy-x1Gf7Pb_oytNQz-JvpDkwX1xiUT6Vc
```

Opcional: si tienes varias impresoras y quieres fijar una por defecto, añade el ID de impresora (lo ves en la web de PrintNode o con `GET https://api.printnode.com/printers`):

```yaml
printnode_api_key: tu_api_key
printnode_printer_id: 123456
```

Sin `printnode_printer_id`, se usa la primera impresora de tu cuenta.

### Si falla la verificación SSL (certificate verify failed)

Ese error suele aparecer con proxy corporativo o CA del sistema desactualizados. Opciones:

1. **Arreglar el sistema** (recomendado): actualizar los certificados CA (p. ej. en macOS/Linux instalar/actualizar `ca-certificates`).
2. **Desactivar verificación solo para PrintNode** (solo en entornos controlados): en credentials añade:
   ```yaml
   printnode_verify_ssl: false
   ```
   O en el servidor: `PRINTNODE_VERIFY_SSL=0`. Así la petición a la API de PrintNode no verifica el certificado SSL.

## 3. Uso en la app

En el modal del ticket (Generar Ticket) verás el botón **"Imprimir con PrintNode"**. Al pulsarlo, el servidor genera el ticket ESC/POS y lo envía a PrintNode; el cliente PrintNode lo recibe y lo manda a la impresora.

Funciona desde cualquier sitio (localhost o tutarjetaroja.com) siempre que la API key esté configurada y el cliente PrintNode esté abierto en el PC de la impresora.
