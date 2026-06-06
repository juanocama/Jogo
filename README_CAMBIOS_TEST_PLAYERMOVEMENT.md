# Cambios realizados

Este proyecto está ajustado para usar el personaje original creado en el proyecto con `res://playerMovement.gd` dentro del escenario de prueba.

## Escena principal

```text
res://scenes/battle_test.tscn
```

## Personaje activo

El personaje está integrado directamente en `battle_test.tscn` como nodo:

```text
Player CharacterBody2D
├── Sprite2D
├── Camera2D
├── CollisionShape2D
└── AnimationPlayer
```

Usa el script:

```text
res://playerMovement.gd
```

Por ahora NO tiene vida, daño ni sistema de combate. Solo se mueve, salta, anima y dirige la cámara.

## Escenas eliminadas

Se eliminaron estas escenas generadas porque no se usarán:

```text
res://scenes/nino_01.tscn
res://scenes/nino_02.tscn
```

## Robots activos en el escenario de prueba

```text
res://scenes/robot_01_boss.tscn
res://scenes/robot_02_boss.tscn
```

El robot 01 está configurado como volador. El robot 02 queda como jefe terrestre.

## Controles

```text
Mover: flechas izquierda/derecha
Saltar: espacio / ui_accept
```

## Archivos principales

```text
res://playerMovement.gd
res://scenes/battle_test.tscn
res://code/boss_robot.gd
res://code/boss_projectile.gd
res://scenes/robot_01_boss.tscn
res://scenes/robot_02_boss.tscn
```
