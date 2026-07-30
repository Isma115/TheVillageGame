# Pradera nativa

Este directorio contiene el port nativo del prototipo a Godot 4.

Godot no se instala globalmente: el editor portátil está en `../tools/godot/`, una carpeta ignorada por Git.

## Ejecutar

Desde la raíz del repositorio:

```bash
./scripts/run-godot.sh --editor
```

Para ejecutar directamente el juego:

```bash
./scripts/run-godot.sh
```

Para generar la APK Android de depuración:

```bash
./scripts/export-android.sh
```

La salida queda en `../build/android/Pradera-debug.apk`.

La versión estándar usa GDScript y el renderer `gl_compatibility`, pensado para mantener compatibilidad con equipos y móviles.
