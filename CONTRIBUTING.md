# Contributing to PSGraphKit

Contributions are welcome. This guide covers the conventions the project follows.

## Getting set up

- PowerShell 7.4+ and the `Microsoft.Graph.Authentication`, `Pester` (5.x), and
  `PSScriptAnalyzer` modules.
- Clone the repo and import the module from source:

  ```powershell
  Import-Module ./src/PSGraphKit/PSGraphKit.psd1 -Force
  ```

## Before opening a pull request

Run the two gates locally — CI runs the same:

```powershell
Invoke-Pester -Path ./tests
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

Both must be clean (0 failures, 0 analyzer findings).

## Conventions

- **Endpoints are never invented.** Every Graph endpoint, property, and scope must be verified
  against Microsoft Learn documentation. Cite the source in the design notes.
- **All Graph traffic goes through `Invoke-GkGraphRequest`** — never call `Invoke-MgGraphRequest`
  directly from a public function.
- **Scopes** for each public function are declared in the capability-group scope map
  (`src/PSGraphKit/Private/_GkModuleData.ps1`).
- **Output** is typed `PSCustomObject`s with a `PSGraphKit.*` PSTypeName and a curated view in
  `Formats/PSGraphKit.Format.ps1xml`. Dates are `[datetime]`. Every reporting cmdlet supports
  `-AsReport`.
- **Write cmdlets** use `SupportsShouldProcess` with `ConfirmImpact = 'High'`, emit a per-item
  result object, warn-and-continue on failure, and default destructive actions to opt-in.
- **Help**: comment-based help with a synopsis and at least three examples. Regenerate `docs/`
  with `./build/Build-GkDocs.ps1`.
- **Tests**: add fixture-mocked Pester tests under `tests/Unit`; no live tenant calls in CI.

## Commit and release

- One logical change per commit; keep the working tree lint- and test-clean.
- Update `CHANGELOG.md` under `[Unreleased]`.
- Releases are cut by bumping `ModuleVersion`, promoting the changelog, and tagging `vX.Y.Z`.
