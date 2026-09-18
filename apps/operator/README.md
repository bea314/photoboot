# Operator (Flutter)

App del operador de Fotoboot. Paquete Dart: `fotoboot_operator` (Android applicationId: `com.fotoboot.operator`).

```bash
flutter pub get
flutter run -d chrome
```

Abre **http://localhost:8080** en Chrome. El puerto fijo está en `web_dev_config.yaml` (Flutter 3.38+ lo aplica solo).

## Cámara en web

Chrome guarda el permiso **por origen** (protocolo + host + puerto). Con el puerto 8080 fijo, no tienes que volver a permitir en cada ejecución.

1. Pulsa **Activar cámara** → **Permitir** cuando Chrome lo pregunte.
2. Si sigue bloqueada: candado (🔒) en la barra → **Cámara** → **Permitir** (o **Restablecer permisos**).

**Nota:** `http://localhost` es contexto seguro para la cámara. No abras la app por IP (`192.168.x.x`); Chrome la bloqueará.

Si el tooling pide regenerar plataformas:

```bash
flutter create --org com.fotoboot --project-name operator --platforms=android,ios,web .
```
