# Tom Forge

Tom Forge, the application: `tom_forge_app` composes the Forge platform into
one desktop tool, one quest application per open quest included, and
`tom_forge_ui_test` is the harness that runs the composed shell in tests.

The libraries it is built from — the editor components, the panel shell, the
modules and their testing packages — live in the repository
[tom_forge_modules](https://github.com/al-the-bear/tom_forge_modules), cloned
at `tom_ai/forge_modules` beside this repository's `tom_forge`. The packages,
their layers and the contracts between them are described there, in
`_agent_guidelines/platform_architecture.md`.

| Package | What it is |
| ------- | ---------- |
| [tom_forge_app](tom_forge_app) | The Tom Forge desktop application |
| [tom_forge_ui_test](tom_forge_ui_test) | Test harness for the composed Forge shell |

## License

Every package in this repository is licensed BSD-3-Clause — see [LICENSE](LICENSE), which each package carries byte-identically.
