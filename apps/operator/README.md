# Operator (Flutter)

App del operador de Fotoboot. Paquete Dart: `fotoboot_operator` (Android applicationId: `com.fotoboot.operator`).

```bash
flutter pub get
flutter run -d chrome
```

Abre **http://localhost:8080** en Chrome. El puerto fijo está en `web_dev_config.yaml` (Flutter 3.38+ lo aplica solo).

## Cámara en web

Puerto fijo **8080** en `web_dev_config.yaml` (Chrome recuerda permisos por origen).

### Permisos en macOS (importante con `flutter run -d chrome`)

Flutter **lanza Chrome desde Cursor/Terminal**. macOS exige cámara para **la app que abre Chrome**, no solo para Chrome:

**Ajustes del Sistema → Privacidad y seguridad → Cámara** → activa:

- **Google Chrome**
- **Cursor** (o **Terminal** / **iTerm**, según desde dónde corras `flutter run`)

Si ves en consola `Permission denied by system`, casi siempre falta **Cursor** o **Terminal** en esa lista. Cierra Chrome (Cmd+Q), vuelve a `flutter run -d chrome`, pulsa **Activar cámara** → **Permitir**.

### Uso en la app

1. Pulsa **Activar cámara** → **Permitir** en la pestaña.
2. Si falla: candado (🔒) → **Cámara** → **Permitir**.

### Alternativa si sigue fallando

Abre Chrome tú (ventana normal, no la de Flutter) y usa el servidor web:

```bash
flutter run -d web-server
```

Luego entra a **http://localhost:8080** en Chrome. Solo hace falta permiso de cámara para Chrome.

**Nota:** `http://localhost` es contexto seguro. No uses IP (`192.168.x.x`).

Si el tooling pide regenerar plataformas:

```bash
flutter create --org com.fotoboot --project-name operator --platforms=android,ios,web .
```
