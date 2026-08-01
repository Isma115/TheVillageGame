# Proyecto Godot

Esta carpeta es la raíz importable por Godot. La escena inicial
`scenes/bootstrap.tscn` carga `scenes/game.tscn` en segundo plano y muestra
progreso o errores antes de entregar el control al juego.

El contenido se registra en `data/game_catalog.tres` mediante recursos tipados:

- `AnimalDefinition` para especies y animaciones;
- `HouseDefinition` para edificios y sus huellas de colisión;
- `PathRouteDefinition` para caminos de cualquier número de puntos;
- `ItemDefinition` para recursos de inventario;
- `ToolDefinition` para herramientas equipables y su durabilidad;
- `TreeDefinition` y `ForestDefinition` para especies, distribución y tala;
- `MineralDefinition` y `MineralDepositDefinition` para recursos y vetas;
- `MineDefinition` para composición, obstáculos y balance de la mina;
- `AreaPortalDefinition` para transiciones entre escenarios.
- `HotelDefinition` y `HotelArea` para el interior público de la casa azul,
  con cama de descanso y progreso de área persistente.
- `NpcDefinition` para personajes y su conversación asociada;
- `DialogueDefinition` para árboles de conversación tipados.
- `NpcActionDefinition` para opciones sociales con afinidad positiva, neutral o negativa;
- `MerchantDefinition` y `MerchantOffer` para economía, compras y ventas.
- `PlantingSystem` y `PlantingPlotActor` para semillas, parcelas y
  crecimiento persistente de árboles.
- `DoctorDefinition` y `DoctorService` para consultas médicas cobradas con monedas.

Los recursos contienen datos; las escenas contienen composición; los scripts de
`systems/` contienen comportamiento compartido. Esta separación permite añadir
contenido sin copiar clases ni modificar el bucle principal.

`InteractionSystem` mantiene un índice espacial de objetivos próximos y
`CollisionWorld` hace lo mismo con obstáculos dinámicos. `ForestrySystem` solo
coordina árboles, colisiones y recompensas; el jugador no contiene lógica de
tala. `MiningSystem` aplica el mismo límite para las vetas y
`WorldAreaSystem` cambia de escenario, cámara y mundo de colisión como una sola
operación. Las interacciones están filtradas por área, por lo que dos escenarios
pueden reutilizar las mismas coordenadas sin interferirse.

El panel de depuración de escritorio muestra FPS, tiempo de proceso de CPU,
porcentaje del presupuesto del frame, memoria de vídeo de GPU y llamadas de
dibujo, además de las entidades del mundo. Estas métricas se consultan desde
`Performance` y se entregan al HUD como datos, sin acoplarlas a los sistemas de
jugabilidad.

`SaveGameService` centraliza la persistencia en una única ranura JSON bajo
`user://pradera_save.json`. El menú de pausa se abre con `Esc`, permite
continuar, guardar o salir; tanto Guardar como Salir muestran confirmación
Aceptar/Cancelar. Al salir, Aceptar guarda y cierra, mientras Cancelar cierra
sin guardar. El guardado restaura posición, área, salud, estamina y capacidad
máxima fatigada, inventario, durabilidad de herramientas, árboles talados y
vetas agotadas, además de las respuestas de diálogo ya descubiertas.
Las parcelas guardan su casilla, semilla y tiempo restante; cuando termina el
contador, el árbol se genera con una especie aleatoria del bosque.

Bruno es el mercader de la aldea. Compra madera y vende minerales, hacha y
pico desde `data/merchants/village_merchant.tres`; las monedas se mantienen en
`WalletService`. El pico se adquiere como herramienta, se equipa al comprarlo
y permite interactuar con las vetas. También vende el arco y lotes de flechas;
el arco queda registrado con la capacidad `shoot`. Con un arco utilizable y al
menos una flecha se activa el modo caza en el exterior: el cursor cambia a una
retícula, cada clic consume una flecha y una unidad de durabilidad, y acertar a
un animal lo elimina y añade una unidad de `meat` al inventario.
`ToolService` conserva las herramientas obtenidas, su durabilidad y la
herramienta equipada.

Elena es la médica de la aldea y está definida en `data/npcs/doctor.tres`. Su
consulta usa `DoctorService`, cuesta 5 monedas y solo después del cobro muestra
el estado de salud, HP actual/máximo y estamina máxima en
`scenes/ui/doctor_panel.tscn`. El HP no aparece en el HUD principal; el informe
se cierra con el botón o con `Esc` y devuelve el control al jugador.

`NpcDialogueSystem` instancia los NPC registrados, los incorpora a colisiones e
interacciones y recorre sus grafos de conversación. Aldara aparece frente a la
casa de madera y ofrece 25 nodos con cuatro respuestas cada uno: 100 elecciones
únicas que conducen a rutas cruzadas y desenlaces alternativos. Cada elección
nueva suma 1 de afinidad al NPC del diálogo; la puntuación se muestra junto al
progreso de descubrimientos y se persiste en la partida. Repetir una elección
no suma afinidad. Las opciones sociales aparecen en un bloque separado: se
definen en `NpcDefinition.interaction_actions`, muestran su categoría y cambio,
modifican la afinidad en ambos sentidos y vuelven a estar disponibles tras un
cooldown independiente de 2 minutos. La respuesta del NPC y el nuevo total
aparecen en el panel.

`WildlifeManager` genera fauna de forma gradual. Cada `AnimalDefinition` declara
su `max_population`; los puntos de aparición se eligen en las cuatro esquinas
del área jugable y se rechazan si la cámara los está mostrando o si colisionan
con el mundo o con otro animal. La escala visual se controla por especie con
`render_width` y la resistencia a la caza con `hunting_health`: cada flecha
resta una unidad, sin representar la salud con una barra.

La mina jugable se encuentra en `data/mines/village_mine.tres`. Sus minerales
están en `data/minerals/`, los objetos de inventario en `data/items/` y sus dos
portales en `data/portals/`. Añadir o equilibrar contenido no requiere modificar
el jugador ni el bucle principal. `GameCatalog.mines` admite varias
`MineDefinition`: cada una instancia `scenes/world/mine_area.tscn` con runtime,
colisiones y vetas propios.

La casa azul de la aldea es el hotel público. Sus portales están en
`data/portals/hotel_entrance.tres` y `data/portals/hotel_exit.tres`, mientras que
la habitación se configura en `data/hotel.tres`. La cama restaura la salud, la
estamina y su capacidad máxima sin cobrar monedas; el área y la posición del
jugador se guardan junto con el resto de la partida. Al dormir, la pantalla se
funde a negro, permanece así durante 3 segundos y vuelve a mostrar el juego.

La herrería está registrada como una nueva `HouseDefinition` en
`data/houses/blacksmith.tres`, tiene su camino desde la plaza en
`data/routes/blacksmith_house.tres` y usa `assets/houses/house-blacksmith.png`.
El sprite incluye un yunque visible. Al acercarse a la herrería se puede abrir
un minijuego de precisión: la marca blanca recorre una barra vertical con zonas
rojas, naranjas y verdes; cinco aciertos en verde entregan una moneda y la
secuencia vuelve a empezar.

El sistema de plantación conserva las parcelas en crecimiento y los cultivos
madurados en la partida guardada. Además de la semilla de árbol, el mercader
vende semillas de tomate, trigo y zanahoria; cada una usa su propio tiempo de
crecimiento, sprite de tierra sembrada y sprite de planta madura.

`HarvestableActor` contiene el ciclo común de salud y agotamiento de árboles y
vetas. `ToolService` mantiene la herramienta equipada, empieza el hacha con
media durabilidad, permite cambiarla con `1`–`9` y descuenta un uso por golpe de
tala o minería. `WorldAreaRuntime`,
`MineAreaRuntime`, `MiningSiteRuntime` e
`InteractionEntry`, bajo `scripts/runtime/`, mantienen estado tipado y evitan
contratos basados en claves de diccionario.

Cada árbol entrega su cantidad normal de madera al caer y tiene una probabilidad
configurada del 10% de añadir una `Manzana` al inventario. El objeto está en
`data/items/apple.tres` y se guarda junto con el resto del inventario.

La definición jugable del hacha está en `data/tools/axe.tres`; el catálogo la
marca como herramienta predeterminada del personaje.
La salud (HP) y la estamina se configuran en la sección `Jugador` de
`data/game_catalog.tres`. `PlayerActor` conserva HP, daño, curación y
persistencia sin mostrarlo todavía en el HUD. La estamina usa tres valores:
`stamina` (actual, se consume al correr y se recupera en reposo), `maximum_stamina`
(máxima actual, se reduce al correr con `stamina_capacity_drain_rate` hasta
`player_min_stamina_capacity` y solo se restaura al dormir) y `stamina_cap`
(capacidad oculta entrenada: cada `stamina_training_interval` segundos de carrera
crece de 1 en 1 hasta `player_max_stamina_cap`, 200 por defecto, y no se pierde al
dormir). Al dormir, la máxima se restaura hasta la capacidad entrenada. Cuando la
estamina llega a cero manteniendo la carrera, `PlayerActor` usa la velocidad
configurada en `player_exhausted_speed` hasta recuperar el 25% de la capacidad;
entonces vuelve a permitir la carrera.

El jugador se presenta con el atlas `assets/player/player-directional.png`.
Sus filas representan frontal, izquierda, derecha y espalda, con ocho frames
por fila; el actor conserva el movimiento en ocho direcciones y selecciona la
fila cardinal dominante para las diagonales. El tamaño del render y el anclaje
de los pies son propiedades de `scenes/actors/player.tscn`, independientes de
la lógica de movimiento.

El bosque utiliza sprites de roble, pino y abedul configurados desde sus
`TreeDefinition`. Las texturas de ejecución están normalizadas a `250x250`;
las fuentes grandes se conservan en `../art-source/` y se regeneran con
`python3 scripts/resize-generated-sprites.py` desde la raíz del repositorio.

Desde la raíz del repositorio:

```bash
./run-godot.sh --editor
./run-godot.sh
./scripts/export-android.sh
```

Controles: `WASD` o flechas para moverse, `Shift` para correr, `1`–`9` para
equipar herramientas, `R` para abrir el inventario, `E` o `Espacio`
para la acción contextual y `Esc` para abrir la pausa. La misma acción entra o
sale de la mina, entra al hotel, duerme, tala árboles y pica vetas. En móvil, el botón contextual se
actualiza con el objetivo más cercano. En los diálogos, las respuestas se
seleccionan con foco y confirmación o con `1`–`4`; `Esc` cierra la conversación.
Con un arco utilizable y flechas, el clic izquierdo activa el disparo en la
aldea y la retícula sustituye al cursor del sistema.
El inventario se abre con `R` y muestra las cantidades de objetos, las monedas
y la durabilidad actual de cada herramienta.
En el exterior, el clic derecho sobre una casilla de césped libre abre el
selector de semillas. La semilla de árbol se compra al mercader, dura 60
segundos por defecto y sirve para cualquier especie.
