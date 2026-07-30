# Fuentes gráficas

Archivos de trabajo que no forman parte del proyecto importable por Godot.

`animals/` conserva las hojas procesadas y `animals/raw/` las versiones con
croma. Son atlas de animación y mantienen sus proporciones originales.

`houses/`, `mining/` y `trees/` conservan los sprites independientes a máxima
resolución. Sus versiones de ejecución se generan a `250x250` píxeles mediante
`scripts/resize-generated-sprites.py` y se guardan bajo `game/assets/`.
