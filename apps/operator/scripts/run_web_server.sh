#!/usr/bin/env bash
# Sirve la app en http://localhost:8080. Abre esa URL en Chrome manualmente.
# Evita el Chrome efímero de `flutter run -d chrome` y el error
# "Permission denied by system" cuando falta permiso de cámara para Cursor/Terminal.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter run -d web-server --web-port=8080
