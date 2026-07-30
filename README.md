# Pradera

Juego top-down nativo construido exclusivamente con Godot 4. La antigua
implementación Electron se ha retirado: el repositorio tiene una sola fuente de
verdad para escenas, comportamiento y contenido.

## Características

- terreno de césped y caminos de teselas con transiciones orgánicas;
- villa de casas pixel-art con colisiones y profundidad por posición;
- jugador con movimiento en ocho direcciones, carrera y polvo;
- cámara suave limitada al mapa;
- fauna animada y reproducible con comportamiento configurable;
- aparición gradual fuera de cámara desde las esquinas, con máximos por especie
  (2 ciervos, 4 pájaros, 1 jabalí y 3 conejos);
- bosque procedural determinista con sprites de robles, pinos y abedules;
- tala contextual, árboles con salud, caída, tocones e inventario de madera;
- entrada de mina pixel-art en las afueras y transición entre escenarios;
- mina explorable con vetas de carbón, hierro, cobre, oro y plata;
- minería contextual con resistencia, agotamiento, botín e inventario;
- controles de teclado y controles táctiles multitáctiles;
- selector de tesela bajo el puntero;
- pantalla de carga con progreso real y gestión de errores;
- panel de depuración con FPS, CPU, GPU, memoria, entidades, objetos y partículas;
- menú de pausa con `Esc`, guardado de una única partida y confirmación Aceptar/Cancelar, también al salir;
- exportación Android mediante el motor portátil del proyecto.

## Ejecutar

El motor local se espera en
`godot-engine/Godot.app/Contents/MacOS/Godot` y está excluido de Git.

```bash
./run-godot.sh --editor
```

Para abrir directamente el juego:

```bash
./run-godot.sh
```

Controles: `WASD` o flechas para moverse, `Shift` para correr, `E` o `Espacio`
para usar la interacción contextual y `Esc` para abrir la pausa. En móvil
aparecen joystick, carrera y un botón de acción cuando hay un objetivo cercano.

Para comprobar únicamente que toda la escena se inicializa, sin abrir ventana
ni mantener el juego ejecutándose:

```bash
./run-godot.sh --headless -- --smoke-test
```

Para exportar una APK Android de depuración:

```bash
./scripts/export-android.sh
```

La salida queda en `build/android/Pradera-debug.apk`.

## Arquitectura

```text
game/
├── assets/              # recursos usados en tiempo de ejecución
│   ├── animals/
│   ├── houses/
│   ├── mining/
│   ├── player/
│   ├── terrain/
│   └── trees/
├── data/                # contenido editable, sin lógica duplicada
│   ├── animals/
│   ├── houses/
│   ├── items/
│   ├── mines/
│   ├── minerals/
│   ├── portals/
│   ├── routes/
│   └── game_catalog.tres
├── scenes/
│   ├── actors/          # escenas reutilizables de entidades
│   ├── ui/              # HUD y controles
│   ├── world/           # escenarios cargables
│   ├── bootstrap.tscn   # carga asíncrona y errores
│   └── game.tscn        # composición del juego
└── scripts/
    ├── actors/          # presentación y estado de entidades
    ├── core/            # arranque, entrada y orquestación
    ├── data/            # tipos Resource y validación
    ├── interactions/    # contrato común de objetos interactuables
    ├── runtime/         # contextos tipados de áreas y sistemas
    ├── systems/         # áreas, colisiones, fauna, tala y minería
    ├── ui/              # interfaz desacoplada
    └── world/           # terreno, caminos e interacción
```

`game/data/game_catalog.tres` es el punto de composición del contenido. Los
sistemas reciben sus dependencias desde `game.tscn`; no leen tablas globales ni
conocen rutas concretas de imágenes.

El menú de pausa se controla desde `GameHud` y detiene la simulación mientras
está abierto. `SaveGameService` mantiene una sola ranura en
`user://pradera_save.json`; al iniciar, restaura automáticamente el área y
posición del jugador, el inventario, los árboles y las vetas agotadas.

El jugador usa `game/assets/player/player-directional.png`, un atlas 8x4 con
ocho fotogramas por dirección (frontal, izquierda, derecha y espalda). El
movimiento sigue admitiendo diagonales; en ellas se muestra la dirección
cardinal dominante. El tamaño visual y el anclaje a los pies se configuran en
`scenes/actors/player.tscn`, dejando el actor listo para sustituir el atlas o
añadir más estados sin cambiar el movimiento ni las colisiones. Su ancho de
render actual es de 62,4 px y no dibuja una sombra propia.

## Ampliar el juego

Para añadir una especie, crea un recurso `AnimalDefinition` en
`game/data/animals/`, asigna su spritesheet y añádelo al catálogo. Las
velocidades, animaciones, colisión, área de paseo, pesos, tiempos de conducta y
`max_population` se editan desde el Inspector. `WildlifeManager` elige una
esquina del mapa, descarta posiciones dentro de la cámara y deja que cada
animal vague alrededor de su punto de entrada.

Las casas y caminos siguen el mismo patrón con `HouseDefinition` y
`PathRouteDefinition`. Para añadir lógica de otra familia de entidades, crea su
escena en `game/scenes/actors/` y su sistema en `game/scripts/systems/`, y
conéctalo desde `game/scenes/game.tscn`.

El bosque se configura en `game/data/forest.tres`. Cada especie usa un
`TreeDefinition` y puede cambiar textura, tamaño visual, salud, colisión,
alcance y botín sin modificar el sistema forestal. Las mecánicas futuras pueden heredar de
`InteractableActor`, registrarse en `InteractionSystem` y entregar cualquier
`ItemDefinition` mediante `InventoryService`.

La mina usa tres niveles de datos: `MineralDefinition` define resistencia,
aspecto y botín; `MineralDepositDefinition` coloca una veta; `MineDefinition`
compone el escenario completo. Los cambios de escenario pasan por
`WorldAreaSystem` y `AreaPortalDefinition`, que también actualizan cámara,
colisiones e interacciones. El catálogo acepta una colección `mines`: para
añadir otra mina basta registrar su `MineDefinition` y sus portales. La escena,
su `CollisionWorld`, las vetas y el runtime se componen automáticamente.

Árboles y vetas heredan de `HarvestableActor`, que concentra salud, foco,
agotamiento y activación. Una mecánica recolectable futura solo necesita aportar
su aspecto, texto, botín y reacción específica al impacto. Los contextos de
ejecución en `scripts/runtime/` sustituyen diccionarios de configuración por
objetos tipados.

Las fuentes gráficas editables se guardan fuera del proyecto importable en
`art-source/`. Los sprites independientes de casas, mina y árboles se
normalizan a lienzos transparentes de `250x250` para ejecución:

```bash
python3 scripts/resize-generated-sprites.py
```

Los atlas de animales y las texturas repetibles se excluyen porque dependen de
su cuadrícula de animación o de su tamaño de tesela.
