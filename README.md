# Pradera

Juego top-down nativo construido exclusivamente con Godot 4. La antigua
implementación Electron se ha retirado: el repositorio tiene una sola fuente de
verdad para escenas, comportamiento y contenido.

## Características

- terreno de césped y caminos de teselas con transiciones orgánicas;
- villa de casas pixel-art con colisiones y profundidad por posición;
- NPC junto a la casa de madera con interacción contextual;
- conversación RPG ramificada con 100 respuestas únicas, finales alternativos y
  progreso de opciones descubiertas;
- afinidad individual con cada aldeano: cada opción de diálogo nueva suma 1;
- jugador con movimiento en ocho direcciones, carrera y polvo;
- cámara suave limitada al mapa;
- fauna animada y reproducible con comportamiento configurable;
- aparición gradual fuera de cámara desde las esquinas, con máximos por especie
  (2 ciervos, 4 pájaros, 1 jabalí y 3 conejos);
- bosque procedural determinista con sprites de robles, pinos y abedules;
- hacha inicial con media durabilidad, tala contextual, árboles con salud,
  caída, tocones e inventario de madera;
- los árboles talados tienen un 10% de probabilidad de soltar una manzana;
- HUD con barras de estamina actual, capacidad máxima y vacío; el HP del jugador se conserva internamente para
  futuras interfaces, correr fatiga lentamente la capacidad máxima sin regenerarla
  con el tiempo y no permite
  seguir corriendo cuando la estamina llega a cero; si se mantiene `Shift`, el
  personaje queda muy ralentizado hasta recuperar el 25%;
- entrada de mina pixel-art en las afueras y transición entre escenarios;
- casa azul accesible como hotel público, con interior explorable y cama que
  restaura salud y estamina mediante un fundido a negro de 3 segundos;
- herrería colocada en la aldea, con un yunque visible y preparada para el
  futuro minijuego de trabajo;
- mina explorable con vetas de carbón, hierro, cobre, oro y plata;
- minería contextual con resistencia, agotamiento, botín e inventario;
- mercader NPC: vende madera, ofrece minerales y permite comprar herramientas;
- médica NPC: por 5 monedas muestra el estado de salud, HP actual/máximo y la estamina máxima;
- pico comprable, equipable y con durabilidad propia para minar;
- arco comprable y equipable, con lotes de flechas disponibles en la tienda;
- modo caza con retícula de apuntado, fauna cazable y carne en el inventario;
- semillas comprables: clic derecho sobre césped libre, selección de semilla y
  crecimiento persistente de árboles aleatorios;
- inventario central con cantidades de objetos, monedas y durabilidad de cada herramienta;
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
para usar la interacción contextual, clic derecho para plantar en césped,
`1`–`9` para equipar herramientas, `R` para abrir el inventario y `Esc` para abrir la pausa. En móvil
aparecen joystick, carrera y un botón de acción cuando hay un objetivo cercano.
Durante una conversación se elige con ratón, toque, flechas y confirmación, o
con los atajos `1`–`4`; `Esc` cierra el diálogo.

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
│   ├── dialogues/
│   ├── houses/
│   ├── items/
│   ├── tools/
│   ├── mines/
│   ├── minerals/
│   ├── npcs/
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
conocen rutas concretas de imágenes. `ToolDefinition` describe las capacidades
y la durabilidad de cada herramienta; `ToolService` mantiene la herramienta
equipada del personaje y persiste su estado.

El menú de pausa se controla desde `GameHud` y detiene la simulación mientras
está abierto. `SaveGameService` mantiene una sola ranura en
`user://pradera_save.json`; al iniciar, restaura automáticamente el área y
posición del jugador, el inventario, la durabilidad de las herramientas, los
árboles y las vetas agotadas.
Las parcelas guardan también su casilla, semilla y tiempo de crecimiento
restante, y los árboles maduros plantados se restauran como árboles normales.

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
`max_population` se editan desde el Inspector. `hunting_health` define cuántas
flechas necesita cada especie, sin mostrar barras de salud. `WildlifeManager`
elige una esquina del mapa, descarta posiciones dentro de la cámara y deja que
cada animal vague alrededor de su punto de entrada.

Las casas y caminos siguen el mismo patrón con `HouseDefinition` y
`PathRouteDefinition`. Para añadir lógica de otra familia de entidades, crea su
escena en `game/scenes/actors/` y su sistema en `game/scripts/systems/`, y
conéctalo desde `game/scenes/game.tscn`.

Los NPC usan `NpcDefinition` para su posición, aspecto, colisión y diálogo.
`NpcDialogueSystem` registra sus interacciones y presenta cualquier
`DialogueDefinition` como un grafo de nodos y elecciones; el diálogo de Aldara
está en `game/data/dialogues/aldara.tres`. El sistema conserva las opciones ya
descubiertas y suma un punto de afinidad al NPC correspondiente por cada opción
nueva, sin volver a contar las respuestas repetidas. Cada NPC puede declarar
`NpcActionDefinition` en `interaction_actions`: acciones positivas, neutrales o
negativas que modifican la afinidad en ambos sentidos y tienen un cooldown
independiente de 2 minutos por acción.

El bosque se configura en `game/data/forest.tres`. Cada especie usa un
`TreeDefinition` y puede cambiar textura, tamaño visual, salud, colisión,
alcance y botín sin modificar el sistema forestal. Las mecánicas futuras pueden heredar de
`InteractableActor`, registrarse en `InteractionSystem` y entregar cualquier
`ItemDefinition` mediante `InventoryService`.

El hacha inicial se configura en `game/data/tools/axe.tres`: tiene 100 puntos
de durabilidad máxima, empieza con 50 y consume 1 punto por golpe de tala.
El pico está en `game/data/tools/pickaxe.tres`: se compra al mercader, se
equipa automáticamente al adquirirlo y consume 1 punto por golpe de minería.
El arco está en `game/data/tools/bow.tres` y las flechas en
`game/data/items/arrows.tres`; ambos aparecen en la tienda del mercader.
Con un arco utilizable y flechas disponibles se activa el modo caza en el
exterior: el cursor se convierte en una retícula y cada clic lanza una flecha.
Si la retícula apunta a un animal, este desaparece y entrega una unidad del
objeto general `meat`, definido en `game/data/items/meat.tres`.
El mercader Bruno y sus ofertas están definidos en
`game/data/npcs/merchant.tres` y `game/data/merchants/village_merchant.tres`.
La semilla universal de árbol está en `game/data/items/tree_seed.tres`. Bruno
la vende; al confirmar la plantación se consume una unidad y, al terminar los
60 segundos configurados en `GameCatalog.tree_seed_growth_time`,
`ForestrySystem` elige aleatoriamente una especie del bosque y crea el árbol
en esa casilla.
La médica Elena está definida en `game/data/npcs/doctor.tres`: su consulta
cuesta 5 monedas y abre un informe modal con el estado de salud, la salud
actual/máxima y la estamina máxima. El HP sigue oculto en el HUD principal y
solo se revela mediante esta consulta.

La salud (HP) y la estamina del jugador se configuran en la sección `Jugador` de
`game/data/game_catalog.tres`. El HP ya dispone de daño, curación y persistencia,
pero se mantiene oculto en el HUD por ahora. La estamina actual se recupera
rápido al dejar de correr; su capacidad máxima se recupera más despacio para
conservar la fatiga.

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
