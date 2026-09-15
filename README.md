# Fotoboot

Photobooth para eventos: app operador (Flutter), API (NestJS + Prisma + Postgres) y galería pública de invitados (Fase E).

## Estructura

| Ruta | Qué es |
|---|---|
| `apps/operator` | App Flutter del operador (cámara, galería, impresión) |
| `apps/api` | API NestJS + Prisma |
| `apps/guest-web` | Galería pública `/e/:slug` (scaffold en Fase E) |
| `docs/` | Requisitos y plan de actividades |

## Requisitos locales

- Flutter 3.44+ (Android / Chrome)
- Node 20+
- Docker (Postgres)

## Levantar en local

### 1. Postgres

```bash
docker compose up -d
```

Postgres queda en el puerto host **55432** (el contenedor sigue en 5432).

### 2. API

```bash
cd apps/api
cp .env.example .env
npm install
npx prisma migrate dev
npm run db:seed
npm run start:dev
```

- Health: http://localhost:3000/health
- Auth: `POST /v1/auth/login` — admin seed: `admin@fotoboot.local` / `admin1234`
- Evento: `GET /v1/events/current` (Bearer)
- Fotos: `POST /v1/photos` (multipart), `GET /v1/photos?eventId=`, `DELETE /v1/photos/:id`

### 3. Operador (Flutter)

```bash
cd apps/operator
flutter pub get
flutter run -d chrome
# o: flutter run   # emulador / dispositivo Android
```

Paquete Dart: `fotoboot_operator` (el nombre `operator` es palabra reservada en Dart).

Si faltan plataformas nativas regeneradas por el tooling:

```bash
cd apps/operator
flutter create --org com.fotoboot --project-name operator --platforms=android,ios,web .
```

## Docs

- [docs/requisitos.md](docs/requisitos.md)
- [docs/actividades.md](docs/actividades.md)
