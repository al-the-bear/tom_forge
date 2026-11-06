# Tom Forge

Composable visual development tools for the Tom framework: editor components
that work on their own, a panel shell that hosts them, modules that bring
editors, views and actions into the shell, and applications that lay them out.
Tom Forge's own app (`tom_forge_app`) composes them, one quest application per
open quest included; other apps compose them through `composeForgeSuite` and
its extension points.

The packages, their layers and the contracts between them:
`_copilot_guidelines/platform_architecture.md` (development guidelines).

## License

Every package in this repository is licensed BSD-3-Clause — see [LICENSE](LICENSE), which each package carries byte-identically.
