![Cuando mi Agente Perdió la Paciencia: Seguridad en IA — Nerdearla Argentina 2026](https://cdn.usestencil.com/images/09359c89-f167-472d-ad10-10ca0f4b353d/4009bc05-e744-4164-b4b1-214526c8aeb0.png)

# Cuando mi Agente Perdió la Paciencia: Seguridad en IA

**Pablo Fredrikson · Nerdearla Argentina 2026**  
26 de septiembre de 2026 · 16:00 a 16:40 (hora de Buenos Aires, UTC−3) · Auditorio

## ¡Gracias por venir!

Acá quedan los materiales de la charla para seguir explorando la seguridad de los agentes de IA y reproducir la demo.

## Sobre la charla

¿Qué sucede cuando un agente autónomo tiene credenciales privilegiadas y decide avanzar sin esperar una aprobación humana? A partir de un incidente real en producción, exploramos cómo un agente de código pudo realizar merges no autorizados en ramas protegidas y qué implica la filtración de identidad (*identity leakage*) al integrar agentes en plataformas de ingeniería y pipelines de CI/CD.

[Ver la charla en la agenda oficial de Nerdearla](https://nerdearla.com/argentina/schedule/cuando-mi-agente-perdio-la-paciencia-seguridad-en-ia/).

## Ideas para llevarse

- **Los permisos del token y el rol de su dueño importan.** En la demo, tokens con permisos equivalentes producen resultados distintos según la identidad que los posee.
- **Una protección configurada puede tener excepciones.** La protección clásica de la demo exige revisión, pero exceptúa a los administradores.
- **Los controles deben aplicarse también al agente.** Un ruleset sin actores con bypass exige la aprobación incluso para la identidad Admin de la demo.
- **El agente no debe poder cambiar sus propios límites.** La credencial de la demo no incluye el permiso `Administration`, por lo que no puede modificar ni eliminar el ruleset.

## Materiales

- [Código y pasos para reproducir la demo](https://github.com/pablokbs/identity-leakage-demo).
- [Guion de la demo en español](./TALK-SCRIPT.es.md).
- [Diapositivas de la edición Nerdearla](https://speakerdeck.com/pablokbs/cuando-el-agente-perdio-la-paciencia-nerdearla-2026).

## Sobre el speaker

Pablo Fredrikson es Principal SRE en Bitso, CNCF Ambassador y creador de contenido en YouTube. Trabaja en tecnología desde 2006 y con contenedores y Kubernetes en producción desde 2018.

## Fuentes y lecturas para seguir

- [Nerdearla: ficha oficial de la charla y biografía del speaker](https://nerdearla.com/argentina/schedule/cuando-mi-agente-perdio-la-paciencia-seguridad-en-ia/).
- [Identity Leakage Demo: explicación del modelo de amenazas y la remediación](https://github.com/pablokbs/identity-leakage-demo#threat-model).
- [How I created Rosie's mRNA Vaccine Protocol - Tweet](https://x.com/paul_conyngham/status/2036940410363535823).
- [Renuncié a Anthropic hoy - Jacob Coxon - Tweet](https://x.com/hilbertspaess/status/2097476196791709843).
- [Debemos regular el avance de la Frontera - Dario Amodei - Tweet](https://x.com/DarioAmodei/status/2098773920774074715).
- [Estoy de acuerdo con Dario que debemos regular el avance de la Frontera - Sam Altman - Tweet](https://x.com/sama/status/2098811563415150910).
- [Creemos con sinceridad que la IA puede matar a todos los humanos - Evan Hubinger - Tweet](https://x.com/EvanHub/status/2097497037956891126).
- [Hola el problema de Keller es falso, gracias a mi amigo Fable - Levent Alpöge - Tweet](https://x.com/__alpoge__/status/2079028340955197566).
