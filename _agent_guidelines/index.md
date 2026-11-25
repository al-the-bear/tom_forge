# Tom Forge — Agent Guidelines

This repository holds the Tom Forge application (`tom_forge_app`) and its
shell test harness (`tom_forge_ui_test`). The platform guidelines — the
layers, the editor component contract, the integrated UX patterns,
configuration compatibility, testing, debug mode and context-menu
contributions — apply to the application too and live with the libraries in
`tom_forge_modules`:

- [Platform guidelines index](../../tom_ai/forge_modules/_agent_guidelines/index.md)
  (`tom_ai/forge_modules/_agent_guidelines/`)

The application's own guards (`tom_forge_app/test/platform_layering_test.dart`,
`editor_component_contract_test.dart`, the licence and vendored-component
audits, the frozen-lock guard) scan the packages of both repositories.
