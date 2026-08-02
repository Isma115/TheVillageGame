# Guía del proyecto Pradera

## Resumen

Pradera es un juego 2D hecho con Godot 4.7. El proyecto jugable está dentro
de `game/` y arranca en `res://scenes/bootstrap.tscn`, que carga la escena
principal `res://scenes/game.tscn`.

El mundo exterior usa una cuadrícula de bloques de 48 píxeles. El catálogo
actual tiene 85 columnas por 85 filas y empieza en la celda `(-25, -25)`. El
lago forma parte de esa cuadrícula: cada bloque de agua se consulta y se
interactúa de forma individual.

## Estructura importante

- `game/scripts/core/game_controller.gd`: arranque, áreas, guardado, HUD y
  coordinación de interacciones.
- `game/scripts/data/`: recursos y validaciones del catálogo.
- `game/scripts/world/`: terreno, agua, caminos, decoraciones y resaltado.
- `game/scripts/actors/`: jugador, casas, árboles, NPC, animales, piedras,
  vetas y portales.
- `game/scripts/systems/`: interacción, colisiones, plantación, tala, minería,
  caza, inventario, herramientas, necesidades y áreas.
- `game/scripts/ui/` y `game/scenes/ui/`: HUD, inventario, opciones, controles,
  menús contextuales y minijuegos.
- `game/data/`: definiciones `.tres` de casas, NPC, objetos, cultivos, rutas,
  minas, portales y recetas.
- `game/assets/`: sprites y sonidos. Los PNG se importan automáticamente por
  Godot; no se deben editar los archivos generados dentro de `.godot/`.

## Flujo de inicialización

`GameController._ready()` valida el catálogo, crea el mundo y las colisiones,
inicializa inventario y servicios, conecta el HUD, registra casas y portales,
crea los runtimes del hotel y la mina y finalmente activa los sistemas de
gameplay.

Los actores interactuables se registran en `InteractionSystem`. Los obstáculos
de movimiento se registran en `CollisionWorld`. Los objetos que afectan a la
generación del bosque deben reservar su espacio en `GameWorld` antes de
inicializar `ForestrySystem`.

## Áreas y edificios

Hay cuatro estados de área disponibles en runtime: aldea, hotel, mina y el
interior de la casa reparada. Todas las casas se pueden interactuar; solo el
hotel está abierto y las demás muestran `Cerrada`.

La casa especial remota usa:

- Actor: `game/scripts/actors/ruined_house.gd`
- Escena: `game/scenes/actors/ruined_house.tscn`
- Sprites: `game/assets/houses/house-ruined.png` y
  `game/assets/houses/house-repaired.png`

Repararla cuesta 750 monedas. Al repararse cambia de sprite y permite entrar
en un interior que reutiliza la cocina y la cama del hotel. El estado se guarda
con la clave `ruined_house_repaired`; incluso reparada no tiene otros accesos
antes de entrar mediante su propia interacción.

## Sistemas de juego

- Necesidades: salud, estamina, sed y temperatura variable entre 25 y 30 °C.
  La temperatura modifica ligeramente el ritmo de sed.
- Plantación: click derecho sobre una celda válida; el menú contextual se
  reemplaza al cambiar de celda y desaparece con click izquierdo.
- Agua: cada bloque del lago ofrece `Beber` con el mismo menú contextual que una
  parcela. No se necesitan objetos adicionales.
- Casas y estaciones: hotel, herrería, cocina, médico, mercader y minero.
- Herrería: reparar herramientas según desgaste; las herramientas rotas
  permanecen en el inventario pero no se pueden usar.
- Minijuegos: yunque, corte de madera, extracción de semillas y cocina. La
  receta disponible actualmente es la ensalada normal o perfecta.
- Audio: `game/scripts/core/sound_service.gd` centraliza los efectos. La tala
  usa `game/assets/sounds/tree_chop.wav` para cada golpe y
  `game/assets/sounds/tree_fall.wav` al iniciar la caída del árbol.
- Mundo: árboles talables con click izquierdo, piedras recogibles, vetas de la
  mina, animales, NPC y lago irregular de bloques.
- Caza: se activa con Tabulador. La rueda del ratón alterna entre arco y piedra;
  las piedras hacen menos daño y permiten cazar sin arco.
- Controles: el menú de opciones incluye la pantalla de controles.

## Rendimiento visual

El terreno estático se dibuja desde `GameWorld` usando únicamente el rango de
celdas que cubre la cámara. Ese rango se recalcula al cruzar límites de bloque,
por lo que el desplazamiento suave de la cámara no fuerza un redibujado por
frame. La animación del agua está separada en
`game/scripts/world/water_animation_layer.gd` y solo redibuja las celdas de
agua visibles cuando cambia el reflejo; no reconstruye las 7.225 celdas del
mapa.

Los NPC y animales usan sprites estáticos rasterizados para evitar el
redibujado procedimental por frame:

- NPC: `game/assets/npcs/`, canvas de 50x75 píxeles como máximo.
- Animales: `game/assets/animals/static/`, canvas de 75x75 píxeles como máximo.

Las hojas de animación antiguas de animales se conservan como fallback en
`game/assets/animals/`.

## Convenciones de interacción

La detección cercana se centraliza en `InteractionSystem`. Cada actor define
`interaction_anchor()`, `interaction_distance()`, `interaction_priority()` e
`interaction_label()`. `GameController` decide el efecto cuando recibe
`interaction_requested`.

Los contextos de terreno usan click derecho. El click derecho cambia el
objetivo y reemplaza el menú anterior; el click izquierdo cierra los botones.
Talar árboles usa click izquierdo y el texto visible debe reflejar ese control.

## Extraccion de semillas

En el minijuego de cocina cada corte es un unico gesto: mantener pulsado el
control de accion, arrastrar y soltar. El recorrido se evalua al soltar, por
lo que mantener el boton pulsado no genera cortes adicionales. La barra mide
la cobertura acumulada de la zona exterior del vegetal y se completa al 60 %;
el circulo central permanece protegido y tocarlo hace fallar el intento.
Las franjas exteriores ya cubiertas no aceptan un segundo corte y no vuelven
	aumentar el progreso.

## Guardado

`GameController._snapshot_game()` compone el estado del jugador, inventario,
herramientas, monedas, temperatura, piedras, árboles, plantaciones, vetas,
diálogos y acciones sociales. Todo estado persistente nuevo debe añadirse al
snapshot y restaurarse en `_load_saved_game()`.

Las restauraciones deben tratar cada valor como `Variant` y comprobar
`is Dictionary` antes de convertirlo. Una partida antigua puede no contener
registros añadidos por versiones posteriores.

## Validación

Desde la raíz `C:\Users\SERVIDOR\Desktop\TheVillageGame` ejecutar:

```powershell
& .\godot-engine\Godot_console.exe --headless --log-file .\smoke-test.log --path .\game -- --smoke-test
```

La prueba correcta termina con una línea `PRADERA_SMOKE_TEST_OK` y sin errores
de script, parseo, llamadas inválidas o nodos ausentes. Después conviene
ejecutar `git diff --check`.

## Pautas para cambios futuros

1. Preferir cambios data-driven en `.tres` cuando el contenido ya tenga una
   definición de datos.
2. Reutilizar `InteractionSystem`, `CollisionWorld` y `GameWorld` en vez de
   crear detecciones o colisiones paralelas.
3. Registrar nuevas interacciones y obstáculos al crear el actor.
4. Mantener los recursos visuales dentro de `game/assets/` y usar nombres
   nuevos para estados o variantes.
5. Preservar cambios previos del usuario que no pertenezcan a la tarea actual.
