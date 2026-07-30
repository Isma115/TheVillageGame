# Pradera — base de videojuego Electron

Una escena top-down pequeña y jugable para empezar un videojuego futuro:

- terreno de césped dibujado en Canvas 2D;
- camino de teselas cuadradas de piedras mezcladas con césped, con plaza y ramales;
- pequeña villa de tres casas pixel-art conectadas por el camino;
- colisiones círculo-rectángulo para casas y límites del mapa;
- huellas de casa explícitas, ajustadas al cuerpo y al porche visibles;
- profundidad visual: el personaje aparece delante o detrás de una casa según su posición;
- pantalla de carga que espera a que estén listos todos los recursos visuales;
- monigote controlable con `WASD` o las flechas;
- `Shift` para correr;
- cámara suave que sigue al personaje y respeta los límites del mapa;
- arquitectura separada en entrada, mundo, jugador, cámara y bucle principal;
- Electron aislado con `contextIsolation` y un preload mínimo.

## Arranque

```bash
npm install
npm start
```

## Port nativo Godot

El port nativo está en `godot/`. El editor portátil de Godot se guarda localmente en `tools/godot/`, está excluido por Git y no se instala en el sistema ni se añade al `PATH`.

```bash
./scripts/run-godot.sh --editor
```

Para ejecutar directamente el port:

```bash
./scripts/run-godot.sh
```

Para generar la APK Android de depuración:

```bash
./scripts/export-android.sh
```

El archivo se crea en `build/android/Pradera-debug.apk`.

## Estructura

```text
src/
├── main/
│   ├── main.js       # proceso principal y BrowserWindow
│   └── preload.js    # puente seguro hacia el renderer
└── renderer/
    ├── game/
    │   ├── camera.js # seguimiento y límites de cámara
    │   ├── collision.js # obstáculos y movimiento con deslizamiento
    │   ├── config.js # constantes de juego
    │   ├── input.js  # teclado y estado de controles
    │   ├── math.js   # utilidades matemáticas
    │   ├── player.js # movimiento y dibujo del personaje
    │   └── world.js  # mapa y césped
    ├── assets/
    │   ├── grass-texture.png
    │   ├── stone-grass-texture.png
    │   └── houses/         # tres casas pixel-art con transparencia
    ├── game.js       # composición, update loop y render loop
    ├── index.html
    ├── main.js       # punto de entrada del renderer
    └── styles.css
```

La capa de juego no depende de Electron directamente. En el futuro se pueden añadir escenas, más entidades y sprites manteniendo el proceso principal intacto.
# TheVillageGame
# TheVillageGame
