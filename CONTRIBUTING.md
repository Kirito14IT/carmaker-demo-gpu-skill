# Contributing

English · [中文说明](README_zh-CN.md)

Contributions are welcome when they improve reproducibility, safety, or documentation clarity for CarMaker GPU demo startup on Ubuntu remote-desktop systems.

## Guidelines

- Do not commit credentials, `.env` files, private logs, core dumps, or license files from commercial software.
- Keep examples generic enough for public use.
- Prefer read-only diagnostic scripts unless a change is explicitly documented as mutating.
- Test shell scripts with `shellcheck` when available, or at minimum run them in a safe read-only mode.

## Suggested changes

- Add verified driver/MovieNX compatibility notes.
- Improve troubleshooting branches for different Ubuntu desktop or remote desktop setups.
- Add safer diagnostics for active GPUSensor sessions.
