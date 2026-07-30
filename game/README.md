# Proyecto Godot

Esta carpeta es la raíz importable por Godot. La escena inicial
`scenes/bootstrap.tscn` carga `scenes/game.tscn` en segundo plano y muestra
progreso o errores antes de entregar el control al juego.

El contenido se registra en `data/game_catalog.tres` mediante recursos tipados:

- `AnimalDefinition` para especies y animaciones;
- `HouseDefinition` para edificios y sus huellas de colisión;
- `PathRouteDefinition` para caminos de cualquier número de puntos;
- `ItemDefinition` para recursos de inventario;
- `TreeDefinition` y `ForestDefinition` para especies, distribución y tala;
- `MineralDefinition` y `MineralDepositDefinition` para recursos y vetas;
- `MineDefinition` para composición, obstáculos y balance de la mina;
- `AreaPortalDefinition` para transiciones entre escenarios.

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

La mina jugable se encuentra en `data/mines/village_mine.tres`. Sus minerales
están en `data/minerals/`, los objetos de inventario en `data/items/` y sus dos
portales en `data/portals/`. Añadir o equilibrar contenido no requiere modificar
el jugador ni el bucle principal. `GameCatalog.mines` admite varias
`MineDefinition`: cada una instancia `scenes/world/mine_area.tscn` con runtime,
colisiones y vetas propios.

`HarvestableActor` contiene el ciclo común de salud y agotamiento de árboles y
vetas. `WorldAreaRuntime`, `MineAreaRuntime`, `MiningSiteRuntime` e
`InteractionEntry`, bajo `scripts/runtime/`, mantienen estado tipado y evitan
contratos basados en claves de diccionario.

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

Controles: `WASD` o flechas para moverse, `Shift` para correr y `E` o
`Espacio` para la acción contextual. La misma acción entra o sale de la mina,
tala árboles y pica vetas. En móvil, el botón contextual se actualiza con el
objetivo más cercano.
