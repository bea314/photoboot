# Fotoboot — plan de actividades

Trabajo de este repositorio para llegar al MVP descrito en [`requisitos.md`](./requisitos.md).

Orden: de abajo hacia arriba. Cada actividad tiene dependencias, entregable y “listo cuando”.
La impresora de **prueba diaria es la térmica**. La L8050 se integra cuando el pipeline de print ya existe.

## 0. Cómo usar este archivo

- Una actividad = un PR o un bloque de trabajo que se puede revisar solo.
- No saltar fases: sin API de fotos no tiene sentido el link público; sin raster no tiene sentido la L8050.
- Stack cerrado: Flutter (operador) + NestJS + Prisma + Postgres + web de invitados en el VPS.

Leyenda de estado para ir tachando:

- [ ] pendiente
- [~] en curso
- [x] hecha

---

## Fase A — Cimientos del repo

### A1. Estructura monorepo

- [x] Crear carpetas `apps/operator`, `apps/api`, `apps/guest-web`, `docs`.
- [x] `.gitignore` (Flutter, Node, `.env`, `/data`).
- [x] README corto: qué es cada app y cómo levantar en local.

**Depende de:** nada.
**Listo cuando:** `flutter create` en `apps/operator` y Nest arrancan en sus carpetas.

### A2. App Flutter vacía + tema

- [x] Proyecto Flutter (Android primero).
- [x] Tema rojo/blanco: colores, tipografía, botones grandes.
- [x] Navegación esqueleto: Login, Cámara, Galería, Detalle, Gestión, Evento/QR.

**Depende de:** A1.
**Listo cuando:** se navega entre pantallas placeholder sin backend.

### A3. API NestJS + Prisma + Postgres

- [x] NestJS con Prisma.
- [x] Docker Compose: Postgres (y opcionalmente la API).
- [x] `.env.example`: `DATABASE_URL`, `JWT_SECRET`, `FILES_ROOT`, `PUBLIC_BASE_URL`.
- [x] Modelos: `User`, `Event`, `Photo`, `PrintJob`, `PrintJobItem`.
- [x] Seed: un admin + un evento `demo`.
- [x] Healthcheck `GET /health`.

**Depende de:** A1.
**Listo cuando:** `prisma migrate` + seed y `/health` responden en local.

---

## Fase B — Auth y evento

### B1. Auth en API

- [x] `POST /v1/auth/login`
- [x] `POST /v1/auth/refresh`
- [x] `POST /v1/auth/logout`
- [x] Guard JWT en rutas `/v1/*` excepto `/auth/*` y `/public/*`.

**Depende de:** A3.
**Listo cuando:** Postman/Insomnia obtiene tokens y una ruta protegida rechaza sin Bearer.

### B2. Login en Flutter

- [x] Formulario email/password (UI rojo/blanco).
- [x] Secure storage de tokens.
- [x] Refresh automático.
- [x] Logout.

**Depende de:** A2, B1.
**Listo cuando:** login real contra la API local; al matar la app, la sesión sigue.

### B3. Evento actual + slug

- [x] API: `GET /v1/events/current`, `PATCH /v1/events/:id`.
- [x] Flutter: pantalla Evento (nombre, slug, copiar link, QR a pantalla completa).
- [x] URL pública: `{PUBLIC_BASE_URL}/e/{slug}`.

**Depende de:** B1, B2.
**Listo cuando:** el operador ve y copia `http://localhost:…/e/demo`.

---

## Fase C — Fotos (local + servidor)

### C1. Cámara y almacenamiento local

- [ ] Permisos de cámara.
- [ ] Preview a pantalla completa + countdown 3-2-1.
- [ ] Disparo → JPEG en disco de la app + `clientPhotoId`.
- [ ] Persistencia local (Hive/SQLite/Isar): cola de fotos y estados (`pending_upload`, `synced`, `error`).

**Depende de:** A2.
**Listo cuando:** se toman 5 fotos sin API y sobreviven un restart.

### C2. Upload e idempotencia

- [ ] API `POST /v1/photos` multipart (`file`, `eventId`, `clientPhotoId`, `takenAt`).
- [ ] Guardar original en `{FILES_ROOT}/events/{eventId}/originals/`.
- [ ] Generar thumbnail y guardar en `…/thumbs/`.
- [ ] `clientPhotoId` único por evento: reintento no duplica.
- [ ] `GET /v1/photos?eventId=`, `GET /v1/photos/:id`, `DELETE /v1/photos/:id` (soft-delete + borrar archivos).

**Depende de:** A3, B1.
**Listo cuando:** curl sube un JPG, lista thumbs y el segundo POST con el mismo `clientPhotoId` no crea otra fila.

### C3. Sync en Flutter

- [ ] Cola en background: si hay red, `POST /photos`; si no, reintenta.
- [ ] Reconciliar con `GET /photos` (borrados remotos, fotos de otra sesión).
- [ ] Badge por foto: local-only / synced / error.

**Depende de:** C1, C2, B2.
**Listo cuando:** avión → 3 fotos → se imprimiría igual → se quita avión → las 3 aparecen en API.

### C4. Galería operador

- [ ] Masonry con thumbs locales o de red.
- [ ] Selección múltiple.
- [ ] Detalle: foto grande, fecha, estado sync/impresa.
- [ ] Eliminar en detalle y en lote (confirmación).

**Depende de:** C3.
**Listo cuando:** masonry + detalle + borrar funcionan online y offline.

---

## Fase D — Impresión (primero térmica)

### D1. Perfiles y preview

- [ ] Perfiles en app (y defaults en API si se quiere): `thermal_80`, `epson_l8050_4x6`.
- [ ] Preview: marco 80 mm vs marco 10×15, center-crop visible.
- [ ] Pantalla Gestión → Impresora: perfil activo, último dispositivo, estado.

**Depende de:** A2, C4.
**Listo cuando:** la misma foto se ve recortada distinto en cada perfil, sin imprimir aún.

### D2. Raster + ESC/POS (térmica de prueba)

- [ ] Descubrir/emparejar térmica (Bluetooth y/o TCP `IP:9100`).
- [ ] Raster: escala al ancho, dither, bitmap ESC/POS.
- [ ] Imprimir 1 foto desde detalle.
- [ ] Imprimir N desde masonry.
- [ ] Errores legibles: desconectada, timeout, papel.

**Depende de:** D1.
**Listo cuando:** la térmica de prueba saca una foto reconocible y un lote de 3.

### D3. Test print térmica

- [ ] Ticket de prueba: marca Fotoboot, perfil, fecha, bloque de contraste, sample.
- [ ] Si el test falla, advertencia en rojo en galería.

**Depende de:** D2.
**Listo cuando:** “Imprimir prueba” es el primer check al montar el booth.

### D4. PrintJob en API

- [ ] `POST /v1/print-jobs` y `PATCH /v1/print-jobs/:id`.
- [ ] Flutter reporta `printed` / `failed` (encolado si no hay red).
- [ ] Marcar `Photo.printedAt` cuando al menos una copia salió bien.
- [ ] Jobs `type: test` no exigen `photoId`.

**Depende de:** C2, D2.
**Listo cuando:** después de imprimir, la API tiene el histórico y la galería muestra “impresa”.

### D5. Epson L8050

- [ ] Generar JPEG/PDF 10×15 a ≥ 300 ppp (el mismo recorte del preview).
- [ ] Envío por cola del SO / SDK Epson / WiFi Direct (sin diálogo si se puede).
- [ ] Fallback: diálogo nativo (AirPrint/Mopria).
- [ ] Test print L8050 (bloque rojo/blanco + sample 10×15).
- [ ] Misma cola de `PrintJob` con `printerProfile: epson_l8050`.

**Depende de:** D1, D3, D4.
**Listo cuando:** una foto sale en 10×15 en la L8050 y el test print también.

---

## Fase E — Web de invitados

### E1. API pública

- [ ] `GET /v1/public/events/:slug` (`?k=` si hay token).
- [ ] `GET /v1/public/photos/:id` → URL de descarga temporal del original.
- [ ] No listar fotos con `deletedAt`.
- [ ] 404 si slug/token no valen.

**Depende de:** C2, B3.
**Listo cuando:** sin JWT se ven las fotos del `demo` y no las de otro evento.

### E2. `apps/guest-web`

- [ ] Ruta `/e/:slug`.
- [ ] Masonry + detalle + descargar.
- [ ] Vacío y 404.
- [ ] Mismos colores rojo/blanco (versión web, no tiene que clonar la app).

**Depende de:** E1, A1.
**Listo cuando:** un móvil ajeno abre el link y descarga una foto.

### E3. Servir API + web + archivos en un VPS

- [ ] Nginx (o similar): API, estáticos de guest-web, `/data` de fotos.
- [ ] HTTPS y `PUBLIC_BASE_URL` real.
- [ ] Backup de Postgres + carpeta de originales.

**Depende de:** E2, A3.
**Listo cuando:** el QR de la app apunta a un dominio real y carga la galería.

---

## Fase F — Cierre MVP

### F1. Pulido UI operador

- [ ] Estados vacíos (sin evento, sin fotos, impresora off).
- [ ] Contraste y tamaños de tap.
- [ ] QR a pantalla completa usable desde 2–3 m.

**Depende de:** B3, C4, D3.

### F2. Prueba de evento seco

- [ ] Checklist: login → evento → test térmica → 20 fotos → print 1 y print 5 → borrar 1 → ver link en otro teléfono → avión 5 min y recuperar sync.
- [ ] Anotar fallos y cerrarlos.

**Depende de:** D4, E2.
**Listo cuando:** el checklist pasa en un ensayo, no en el evento real.

### F3. (Opcional, post-MVP) Resend

- [ ] Correo al admin con link/QR al publicar.
- **No bloquea** el primer evento.

---

## Orden recomendado (esta semana → primer ensayo)

```text
A1 → A2 + A3
     → B1 → B2 → B3
     → C1 → C2 → C3 → C4
     → D1 → D2 → D3 → D4     ← térmica aquí
     → E1 → E2
     → F1 → F2
     → D5                     ← L8050 cuando el print ya esté sólido
     → E3                     ← VPS cuando local ya funcione
```

## Criterio para no desviarse

Si una actividad no ayuda a: **tomar, ver, imprimir en térmica o compartir el link**, va después del MVP.

Detalle de contratos y flujos: [`requisitos.md`](./requisitos.md).
