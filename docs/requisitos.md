# Fotoboot — requisitos generales

Aplicación de photobooth para eventos: un operador toma fotos en tablet/móvil, las revisa, las imprime y comparte un link público con los invitados.

Colores de marca: **rojo y blanco**. UI grande, pensada para usarse de pie, con prisa y con una mano.

## 1. Visión

En un evento hay dos mundos:

- **Operador (staff):** inicia sesión, toma fotos, las ve en galería, previsualiza el recorte de impresión y manda a térmica o a Epson L8050.
- **Invitado:** abre un link (`tudominio.com/e/boda-ana`) y solo ve / descarga. No instala app.

El booth debe poder **imprimir aunque falle el WiFi del salón**. El link público se actualiza cuando vuelva la red.

## 2. Alcance

### 2.1 MVP (primer evento usable)

- Un admin, un evento activo a la vez.
- Login del operador.
- Cámara con countdown 3-2-1.
- Galería masonry + vista detalle.
- Borrar foto.
- Selección múltiple e impresión (1 o N) desde Galería/Detalle, con plantilla activa del papel.
- Preview real de impresión (térmica 80 mm con seeds ticket QR / ticket foto; foto 10×15 más adelante).
- Gestión = biblioteca de plantillas; Avanzado = conexión, transporte y test print.
- Dos perfiles de impresora: **térmica ESC/POS** (pruebas principales) y **Epson L8050**.
- Link público de solo lectura `/e/:slug`.
- Subida de fotos al VPS (original + thumbnail).
- Cola local si no hay red.

### 2.2 Fuera del primer corte

- Varios eventos concurrentes con varios operadores.
- Frames, stickers, GIFs, boomerang.
- Emails masivos a invitados.
- Packs de copias / pagos.
- App nativa para invitados.
- Toggle lista / iconos / masonry (el MVP arranca solo con masonry + detalle).
- App Flutter-only sin backend.

## 3. Actores

| Actor | Dónde | Qué hace |
|---|---|---|
| Admin / operador | App Flutter | Login, cámara, galería, borrar, print, test de impresora, copiar/mostrar QR del evento |
| Invitado | Web pública | Ver y descargar fotos del evento |
| Sistema | VPS | Auth, metadatos, archivos, slug público |
| Impresora | Red local / USB / Bluetooth | Recibe el raster generado en el dispositivo operador |

El VPS **no imprime**. Solo registra jobs. El dispositivo del operador es el que habla con la impresora.

## 4. Superficies

| Superficie | Stack | Responsabilidad |
|---|---|---|
| App operador | Flutter (iOS / Android / tablet) | Cámara, galería, preview, print local, gestión de impresora |
| API | NestJS + Prisma + Postgres | Auth, eventos, fotos, jobs, slugs |
| Archivos | Disco del VPS o R2/S3 | Original + thumbnail. La DB solo guarda rutas |
| Web invitados | Web servida por el VPS (Next o HTML + API) | Galería pública de un evento |
| Correo | Resend (después del MVP) | Avisos, “galería lista”, QR |

## 5. Requisitos funcionales

### 5.1 Auth (operador)

- Login con email + password.
- Sesión persistente en el dispositivo (JWT access + refresh).
- Logout.
- Sin registro público. El primer admin se crea por seed o variable de entorno.

### 5.2 Eventos y link público

- Crear / editar evento: nombre, slug, fecha, activo sí/no.
- Slug único, URL canónica: `https://<dominio>/e/<slug>`.
- El operador puede copiar el link y mostrar un QR a pantalla completa.
- Si las fotos no son públicas por defecto, el link lleva un token (`/e/<slug>?k=<token>`).
- El invitado **no** puede borrar, imprimir ni subir.

### 5.3 Captura

- Pantalla de cámara a pantalla completa (preview).
- Countdown 3-2-1 visible y opcionalmente audible.
- Al disparar: guardar JPEG local, generar id, encolar subida, mostrar la foto en galería de inmediato.
- Frente / flash según hardware. Sin filtros en el MVP.

### 5.4 Galería (operador)

- Vista masonry (principal).
- Vista detalle: foto grande, fecha, estado de sync, estado de impresión.
- Desde detalle: imprimir, eliminar, compartir (copia el archivo o el link de esa foto si existe).
- Selección múltiple en masonry → “Imprimir N” o “Eliminar N”.
- Indicador por foto: local-only / subida / error de sync / ya impresa.

### 5.5 Impresión

- Imprimir **1** (Detalle) o **N** (Galería, selección múltiple). No hay panel de impresión en Gestión.
- El job usa la **plantilla activa** de la familia del papel actual (`thermal` / foto `10×15`), no un layout inventado al vuelo.
- Mismo contrato: `print(photoIds[], printerProfile)` + plantilla activa del dispositivo.
- Antes de imprimir, preview del recorte real según la plantilla (slot center-crop; no el JPG crudo).
- Confirmación: papel/perfil, copias, plantilla activa.
- Historial local + registro en API cuando haya red (`PrintJob`).
- Reintento si falla el envío a la impresora.
- Si no hay conexión de impresora: aviso tipo **“No hay conexión… Revísala en Avanzado”** (enlace a Avanzado).
- Si el último test print falló: warning en Galería/Detalle con enlace a **Avanzado** (no a un hub de transportes en Gestión).

**Plantillas (Corte A — alcance de producto):**

- Biblioteca local de plantillas genéricas en JSON (sin editor canvas ni Canva completo; Corte A/B ligero no lo exige).
- **Seeds térmicos 80 mm (T2) — dos arquetipos:**
  1. **Ticket QR:** logo + CTA + QR del evento + URL. **Sin `photoSlot`.** Sirve para compartir el link sin imprimir foto.
  2. **Ticket foto:** `photoSlot` (fit **cover**) + texto (evento/marca) + timestamp con placeholders `{{fecha}}` / `{{hora}}` + icono/logo abajo.
- Foto **10×15:** variante a color tipo arquetipo 2 (photoSlot + texto/marca) **más adelante** — no forma parte del seed mínimo hecho de Corte A.
- `isActive` **por familia** (una activa para térmica, otra para foto cuando exista), no un único global.
- Al imprimir desde Galería/Detalle (ticket foto / 10×15), se usa la plantilla activa con `photoSlot`. El ticket QR se puede disparar desde el flujo de evento/compartir sin foto.

**Fuera de este corte (Corte B — pendiente):** editor canvas, import de fondo (p. ej. Canva u otro asset), capas (`photoSlot` / `image` / `text` / `QR` / `shape`), drag de slots; rotación fuera del MVP. Edición ligera sí; Canva completo no es requisito de Corte A. Los docs no asumen que el editor exista hasta que haya PR de implementación. **No** adoptamos zip LumaBooth.

### 5.6 Gestión (plantillas) y Avanzado (impresora)

La UX de “Gestión de impresora” se parte en dos superficies. **Gestión no es el panel de transportes.**

Modelo mental de sector (referencia, no formato a copiar): en flujos tipo booth las plantillas viven en el **setup del evento** (elegir layout, ajuste ligero, cambiar papel/layout sin rediseñar, probar con la cámara), no en una pantalla de debug de impresora. Ver [Import & Edit LumaBooth Templates](https://photoboothlayouts.com/how-to-import-edit-lumabooth-templates-on-mac/) como inspiración de ese flujo. **No** adoptamos el formato zip LumaBooth/DSLRBooth; nuestras plantillas son JSON local genérico (Corte A) y edición propia más adelante (Corte B).

#### Gestión — hub de plantillas (tab **Plantillas**)

- Biblioteca de plantillas del dispositivo (seed + las que se añadan después).
- Lista/grid con preview; badge **Activa** en la plantilla en uso por familia.
- Acción **“Usar en este evento”** para marcar activa la plantilla elegida (por familia térmica vs foto).
- Empty / guía: **“Elige una plantilla para imprimir”** cuando aún no hay activa o hay que cambiar.
- Desde aquí se elige *qué* se imprime encima del papel; no se empareja hardware.
- Cambiar papel/familia o plantilla activa **sin** rediseñar layout a mano (Corte A: elegir otra del seed/biblioteca).

#### Avanzado — conexión, transporte y test print

- Perfil de papel/impresora: `thermal` / `epson_l8050` (y anchos 58/80 mm, márgenes, borderless Epson).
- Descubrimiento / pairing (Bluetooth, IP, USB según plataforma).
- Estado: desconectada / conectada / sin papel / error / desconocido.
- **Test print** obligatorio: página o ticket de prueba con marca (rojo/blanco), fecha y “Fotoboot OK”.
- Guardar la última impresora / transporte usado en el dispositivo.
- Fallo de test → warning consumible desde Galería (link de vuelta a Avanzado).

### 5.7 Invitados (web)

- Abrir `/e/:slug` y ver masonry de fotos ya sincronizadas.
- Tap → detalle + descargar.
- Vacío: “Aún no hay fotos” si el evento existe pero no hay uploads.
- 404 si el slug no existe o el token es inválido.

### 5.8 Borrado

- Soft-delete en API (`deletedAt`) + borrar archivos del disco en background.
- En el dispositivo, quitar de la galería al confirmar.
- Las fotos ya impresas se pueden borrar igual; el job histórico permanece.

## 6. Requisitos no funcionales

- La captura e impresión **no dependen** de que el VPS esté reachable.
- Subida en background con reintento (cola persistente en el dispositivo).
- Cada foto: original (impresión / descarga) + thumbnail (galería).
- JWT en todas las rutas de operador. Rutas `/public/*` sin auth de usuario, solo slug/token.
- Fotos de evento no listables por enumeración de ids.
- UI operable a ~1 m de distancia: botones grandes, contraste rojo/blanco.
- Pensado primero para tablet Android; iOS y web operador no son bloqueantes del MVP.

## 7. Impresoras

### 7.1 Térmica (impresora de prueba principal)

- Protocolo: **ESC/POS**.
- Transporte: Bluetooth SPP, USB o TCP `IP:9100`.
- Ancho: 80 mm por defecto (58 mm configurable).
- El Flutter rasteriza la foto (escala, dither/threshold) y manda el bitmap ESC/POS.
- Test print: ticket con logo/texto + bloque de prueba + una foto de sample recortada.
- Errores típicos a mostrar: no emparejada, papel, tapa, timeout.

### 7.2 Epson L8050 (foto)

- EcoTank 6 colores, WiFi / WiFi Direct / USB / Ethernet.
- Tamaño de booth por defecto: **10×15 cm (4×6")**, recorte center-crop. A4/A3+ queda fuera del MVP.
- El Flutter genera un JPEG/PDF a resolución de impresión (objetivo ≥ 300 ppp en 10×15).
- Envío:
  1. Preferido: SDK / servicio de impresión Epson o cola del SO sin diálogo (kiosco).
  2. Fallback: diálogo nativo de impresión (AirPrint / Mopria) — usable, peor para booth.
- Preview: marco 10×15 con zonas que se van a cortar.
- Test print: bloque de color rojo/blanco + una foto de sample a 10×15 + texto “Fotoboot / L8050 / fecha”.

### 7.3 Regla de arquitectura de print

```
[Flutter]  --raster + protocolo-->  [Impresora local]
[Flutter]  --POST /print-jobs---->  [API]   (auditoría, no el bytes del print)
```

Nunca se manda el trabajo de impresión a través del VPS. El servidor no tiene USB ni Bluetooth del salón.

## 8. Cómo se comunica cada pieza

### 8.1 Mapa

```
┌─────────────┐  JWT + REST/multipart   ┌──────────────────┐
│  Flutter    │ ───────────────────────► │  API NestJS      │
│  operador   │ ◄─────────────────────── │  Prisma/Postgres │
└──────┬──────┘      JSON                 └────────┬─────────┘
       │                                           │
       │ ESC/POS o cola Epson                      │ filesystem / R2
       ▼                                           ▼
┌─────────────┐                           ┌──────────────────┐
│ Térmica o   │                           │  originales +    │
│ L8050       │                           │  thumbnails      │
└─────────────┘                           └────────┬─────────┘
                                                   │
┌─────────────┐  GET público /e/:slug     ┌────────▼─────────┐
│  Invitado   │ ◄──────────────────────── │  Web invitados   │
│  (navegador)│                           └──────────────────┘
└─────────────┘
```

### 8.2 Contratos de API (operador)

Base: `https://<api>/v1`. Header: `Authorization: Bearer <access>`.

| Método | Ruta | Quién llama | Qué viaja | Respuesta |
|---|---|---|---|---|
| POST | `/auth/login` | Flutter | `{ email, password }` | `{ accessToken, refreshToken, user }` |
| POST | `/auth/refresh` | Flutter | `{ refreshToken }` | nuevos tokens |
| POST | `/auth/logout` | Flutter | refresh | 204 |
| GET | `/events/current` | Flutter | — | evento activo + slug + token público |
| PATCH | `/events/:id` | Flutter | nombre, slug, activo | evento |
| GET | `/photos?eventId=` | Flutter | — | lista (id, thumbUrl, printed, syncedAt) |
| POST | `/photos` | Flutter | `multipart`: `file`, `eventId`, `clientPhotoId`, `takenAt` | foto creada + urls |
| GET | `/photos/:id` | Flutter | — | metadata + `originalUrl` firmada o autenticada |
| DELETE | `/photos/:id` | Flutter | — | 204 (soft-delete) |
| POST | `/print-jobs` | Flutter | `{ photoIds, printerProfile, copies, localStatus, error? }` | job id |
| PATCH | `/print-jobs/:id` | Flutter | `{ localStatus: printed\|failed }` | job |
| GET | `/printer/profiles` | Flutter | — | perfiles (térmica / L8050) y defaults de recorte |

La foto se identifica primero con `clientPhotoId` (UUID generado en el dispositivo). Si se reintenta el POST, la API es **idempotente** y no duplica.

### 8.3 Contratos públicos (invitado)

Sin JWT. Solo slug y, si aplica, `k`.

| Método | Ruta | Qué viaja | Respuesta |
|---|---|---|---|
| GET | `/public/events/:slug` | `?k=` | `{ name, photos: [{ id, thumbUrl, takenAt }] }` |
| GET | `/public/photos/:id` | `?k=` | url de descarga temporal del original |

La web de invitados consume solo estas rutas. No ve `/print-jobs` ni `/auth`.

### 8.4 Flujo: login

1. Operador escribe email/password.
2. Flutter `POST /auth/login`.
3. Guarda tokens en secure storage.
4. `GET /events/current`. Si no hay evento, pantalla “crear evento”.
5. Entra a cámara o galería.

Si el access expira: `POST /auth/refresh`. Si el refresh falla: volver a login.

### 8.5 Flujo: tomar foto

```
Cámara  →  JPEG local (clientPhotoId)
        →  insertar en galería local (estado: pending_upload)
        →  cola de sync
              ├─ hay red: POST /photos (multipart original)
              │           API escribe disco + genera thumbnail + fila Prisma
              │           Flutter marca synced, guarda serverId y urls
              └─ no hay red: queda en cola; se reintenta
Impresión: se puede disparar en cualquier momento con el JPEG local.
Invitados: solo ven la foto cuando el POST ya respondió 201.
```

### 8.6 Flujo: galería operador

1. Arranque: leer SQLite/Hive local (fuente de verdad en el booth).
2. En paralelo, `GET /photos?eventId=` para reconciliar (fotos de otra sesión, borrados).
3. Masonry pinta thumbnails locales si existen; si no, `thumbUrl`.
4. Detalle pide original local o `GET /photos/:id`.

Conflicto: si el servidor marcó `deletedAt` y el local no, el local se oculta.

### 8.7 Flujo: imprimir

1. Operador elige 1 (Detalle) o N (Galería) fotos. El layout es la **plantilla activa** de la familia del papel (térmica / 10×15).
2. Flutter abre preview: aplica el layout de esa plantilla (ticket foto: `photoSlot` cover; ticket QR no usa foto).
3. Confirma copias (y ve qué plantilla está Activa).
4. Por cada foto (si la plantilla tiene `photoSlot`):
   1. Raster local (bitmap ESC/POS **o** JPEG 10×15 @ ~300 ppp cuando exista esa familia).
   2. Envío al transporte configurado en **Avanzado** (Bluetooth / TCP / USB / cola Epson).
   3. Resultado `printed` o `failed`.
5. `POST /print-jobs` con el resultado (o se encola si no hay red).
6. La foto se marca “impresa” en la galería (jobs de ticket QR sin foto no marcan `printedAt` de una Photo).

Si no hay conexión: **“No hay conexión… Revísala en Avanzado”**. El preview y el raster **siempre** se calculan en Flutter. La API no genera el layout de impresión en el MVP.

### 8.8 Flujo: test print

1. **Avanzado** → “Imprimir prueba” (no el hub de plantillas en Gestión).
2. No usa una foto del evento. Usa un asset de test + texto de estado (perfil, IP/MAC, fecha).
3. Mismo pipeline de raster/envío que una foto real.
4. Si el test falla, warning en Galería/Detalle con enlace a **Avanzado**.
5. Opcional: `POST /print-jobs` con `type: test` para histórico.

### 8.9 Flujo: link del evento

1. Al crear evento, la API genera `slug` (y `publicToken` si el evento no es abierto).
2. Flutter muestra `https://<dominio>/e/<slug>` y QR.
3. El invitado abre la web. La web pide `GET /public/events/:slug`.
4. Masonry con thumbs. Detalle descarga original con URL de corta vida.

Compartir “una foto” en detalle (operador) puede copiar el link del evento, no un permalink secreto por foto (fuera de MVP).

### 8.10 Flujo: borrar

1. Confirmación en Flutter.
2. Borrado local inmediato.
3. `DELETE /photos/:id` cuando haya red (si aún no tenía `serverId`, solo se descarta la cola de upload).
4. API: `deletedAt = now()`. Worker o el mismo request quita original + thumb del disco.
5. La web pública deja de listarla.

### 8.11 Flujo: archivos en el VPS

```
POST /photos
  → valida JWT + eventId + clientPhotoId
  → guarda /data/events/<eventId>/originals/<photoId>.jpg
  → genera /data/events/<eventId>/thumbs/<photoId>.jpg
  → INSERT Photo { id, eventId, clientPhotoId, originalPath, thumbPath, takenAt }
  → responde urls relativas o firmadas
```

Postgres no guarda el binario. Prisma solo metadatos.

### 8.12 Correo (post-MVP)

- Resend desde la API, nunca desde Flutter.
- Casos: “galería publicada” al admin, o un PDF/QR. No bloquea captura ni print.

## 9. Modelo de datos (Prisma, mínimo)

```text
User        id, email, passwordHash, createdAt
Event       id, name, slug, publicToken?, startsAt, isActive, createdAt
Photo       id, eventId, clientPhotoId, originalPath, thumbPath,
            takenAt, printedAt?, deletedAt?, createdAt
PrintJob    id, eventId, printerProfile, type (photo|test),
            copies, status (queued|printed|failed), error?, createdAt
PrintJobItem id, printJobId, photoId?
```

Índices: `Event.slug` único, `Photo.clientPhotoId` único por evento, `Photo.deletedAt` para listados.

## 10. Organización de este repositorio

Monorepo:

```text
fotoboot/
  apps/operator/     # Flutter
  apps/api/          # NestJS + Prisma
  apps/guest-web/    # galería pública
  docs/              # este archivo y el plan de actividades
```

Un solo VPS sirve API + web de invitados + archivos. Flutter se instala en el dispositivo del booth.

## 11. UI

- Fondo blanco, acento rojo, texto negro/rojo.
- Cámara y “disparar” como acción dominante.
- Gestión (plantillas) y Avanzado (impresora) accesibles, no escondidos.
- Estados vacíos claros: sin evento, sin fotos, sin plantilla activa (“Elige una plantilla para imprimir”), impresora desconectada.
- El preview de impresión se ve **antes** de mandar papel.

## 12. Criterios de aceptación del MVP

1. Login correcto entra al evento; login incorrecto no.
2. Una foto tomada aparece en masonry sin esperar al servidor.
3. Con red, la misma foto aparece en `/e/:slug` en menos de unos segundos.
4. Sin red, se puede tomar e imprimir; al volver la red, sube sola.
5. Test print funciona en la térmica de prueba.
6. Preview 80 mm y preview 10×15 muestran recortes distintos.
7. Seleccionar 3 fotos e imprimirlas crea 3 envíos (o un job con 3 ítems) y queda registro.
8. Borrar en detalle quita la foto de operador y, tras sync, de la web pública.
9. Un invitado no puede pegar `/v1/photos` y listar sin token de admin.

El desglose de trabajo está en [`actividades.md`](./actividades.md).
