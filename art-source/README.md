# Fuentes gráficas

Archivos de trabajo que no forman parte del proyecto importable por Godot.

`animals/` conserva las hojas procesadas y `animals/raw/` las versiones con
croma. Son atlas de animación y mantienen sus proporciones originales.

`player/` conserva el atlas direccional del jugador y `player/raw/` la fuente
con croma. También es un atlas de animación, por lo que mantiene su cuadrícula
8x4 y su tamaño no se pasa por el normalizador de lienzos cuadrados.

`houses/`, `mining/` y `trees/` conservan los sprites independientes a máxima
resolución. Sus versiones de ejecución se generan a `250x250` píxeles mediante
`scripts/resize-generated-sprites.py` y se guardan bajo `game/assets/`.
