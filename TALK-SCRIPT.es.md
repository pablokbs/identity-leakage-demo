# Guion de la charla — Demo de Identity Leakage

Ejecutar con:

```bash
make DEMO_LANG=es DEMO_PRESENT=1 setup
make DEMO_LANG=es DEMO_PRESENT=1 attack-admin
make DEMO_LANG=es DEMO_PRESENT=1 attack-writer
make DEMO_LANG=es DEMO_PRESENT=1 remediate
make DEMO_LANG=es DEMO_PRESENT=1 reattack
```

## Setup

> El repositorio y los dos colaboradores ya existen. Es intencional: aceptar invitaciones es una preparación que se hace una sola vez, no parte de una demo de seguridad en vivo.
>
> Main tiene branch protection clásica y exige una aprobación. Los administradores no están incluidos explícitamente, así que quedan exceptuados. El primer PR no tiene ninguna aprobación.

Usar los links impresos para mostrar colaboradores, configuración de la rama y el PR sin aprobar.

## Ataque Admin

> El agente tiene un token limitado: puede modificar contenido y pull requests, pero no puede administrar la configuración del repositorio. La identidad dueña del token tiene rol Admin.
>
> Miren esto: el script no elimina ni modifica la branch protection. Solamente le pide a GitHub que mergee el PR sin aprobación.

Después del merge, mostrar ambos links:

- el PR fue mergeado sin aprobación;
- la protección clásica sigue configurada.

> El control nunca fue eliminado. GitHub exceptuó a la identidad Admin. Limitar el token no hizo desaparecer la identidad que estaba detrás.

El script crea otro PR equivalente para compararlo con Writer.

## Comparación con Writer

> Misma operación y un token limitado equivalente. La diferencia importante es quién es dueño del token: esta identidad tiene rol Writer, no Admin.

Mostrar que el mismo comando `gh pr merge --admin` ahora es rechazado y que el PR continúa abierto.

> La protección clásica sí se aplica a Writer, por eso GitHub bloquea el merge. La identidad cambió el resultado efectivo de autorización.

## Remediación

> El fix tiene dos partes. Primero reemplazamos la protección clásica por un ruleset sin bypass actors. Segundo, mantenemos el permiso de Administration fuera de la credencial que tiene el agente.

Mostrar el JSON resumido, especialmente:

```json
"bypass_actors": []
```

Después abrir los links de configuración del ruleset y reglas efectivas.

## Reataque Admin

> Misma identidad Admin. Mismo token limitado. Mismo PR sin aprobación que Writer no pudo mergear. El cambio relevante es la política aplicada sobre main.

Mostrar el HTTP 405 y que el PR continúa abierto.

> El ruleset eliminó la excepción implícita de Admin. El agente no puede saltearlo y su token no tiene permiso de Administration para modificarlo o eliminarlo.

## Cierre

> Un token no es una identidad aislada. GitHub evalúa tanto los permisos del token como el rol que tiene su dueño en el repositorio.
>
> La protección clásica dejó un agujero con forma de Admin. El ruleset sin bypass cierra ese agujero, y mínimo privilegio evita que el agente mueva la pared.

Después de la charla, ejecutar `make DEMO_LANG=es reset`. El repositorio y los colaboradores quedan listos para la próxima presentación.
