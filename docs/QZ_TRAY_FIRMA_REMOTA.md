# Impresión ESC/POS desde tutarjetaroja.com (QZ Tray con firma)

Para que el botón **"Generar ticket ESC/POS"** funcione cuando la web se abre desde **tutarjetaroja.com** (y no solo en localhost), hay que configurar la **firma con certificado** y registrar el certificado en QZ Tray.

La app lee **certificado y clave desde Rails credentials** (recomendado). Opcionalmente puedes usar variables de entorno con rutas a archivos (ver al final).

---

## 1. Generar certificado y clave privada (una vez)

En tu máquina:

```bash
mkdir -p config/qz_tray
cd config/qz_tray

openssl req -x509 -newkey rsa:2048 -keyout private-key.pem -out digital-certificate.pem -days 3650 -nodes -subj "/CN=tutarjetaroja.com"
```

Obtendrás:
- `private-key.pem` — clave privada (no subir a git).
- `digital-certificate.pem` — certificado público (este lo usas en credentials y en QZ Tray).

La carpeta `config/qz_tray/` ya está en `.gitignore`.

---

## 2. Añadir a Rails credentials

Abre las credentials del entorno que uses (producción, desarrollo, etc.):

```bash
# Producción (o el que uses en tutarjetaroja.com)
EDITOR="code --wait" rails credentials:edit --environment production
```

Añade esta estructura (pegando el contenido **completo** de cada archivo PEM, con las líneas `-----BEGIN ...-----` y `-----END ...-----`):

```yaml
qz_tray:
  cert: |
    -----BEGIN CERTIFICATE-----
    (todo el contenido de digital-certificate.pem, línea por línea)
    -----END CERTIFICATE-----
  private_key: |
    -----BEGIN PRIVATE KEY-----
    (todo el contenido de private-key.pem, línea por línea)
    -----END PRIVATE KEY-----
```

**Cómo pegar el certificado:**  
Abre `digital-certificate.pem`, copia todo (incluidas la primera y la última línea) y pégalo bajo `cert: |` con la misma indentación.  
Haz lo mismo con `private-key.pem` bajo `private_key: |`.

Guarda y cierra el editor. Las credentials quedan cifradas con tu `master.key` (o `config/credentials/production.key` en producción).

---

## 3. Registrar el certificado en QZ Tray (en cada PC que imprime)

En cada equipo donde esté instalado QZ Tray y la impresora térmica:

1. Abre **QZ Tray** (icono en la bandeja).
2. Clic derecho → **Advanced** → **Site Manager**.
3. Arrastra el archivo **`digital-certificate.pem`** (o `digital-certificate.txt` con el mismo contenido) al cuadro de Site Manager y acepta.
4. Cierra el Site Manager.

Con eso, las conexiones desde **tutarjetaroja.com** que usen ese certificado y la firma generada por el servidor serán aceptadas sin popup.

## 4. Comportamiento

- Si en **credentials** existe `qz_tray` con `cert` y `private_key`, la app sirve el certificado y firma las peticiones; la impresión funciona desde tutarjetaroja.com.
- Si no hay credentials de QZ Tray, los endpoints de certificado/firma responden 503; la impresión solo funcionará desde **localhost**.

## 5. Resumen de rutas

| Ruta | Uso |
|------|-----|
| `GET /admin/address_images/qz_certificate` | Devuelve el certificado público (PEM). |
| `POST /admin/address_images/qz_sign` | Recibe `{ "request": "<toSign>" }`, devuelve `{ "signature": "<base64>" }`. |

Solo usuarios autenticados en el admin pueden acceder a estas rutas.

---

## Opcional: usar archivos y ENV en lugar de credentials

Si prefieres no guardar el PEM en credentials, puedes usar archivos y variables de entorno:

```bash
export QZ_TRAY_CERT_PATH="/ruta/completa/digital-certificate.pem"
export QZ_TRAY_KEY_PATH="/ruta/completa/private-key.pem"
```

La app usa **primero** credentials; si no hay `qz_tray` en credentials, usa estas rutas.
