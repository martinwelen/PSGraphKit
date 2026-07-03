## Summary

What does this change and why?

## Checklist

- [ ] `Invoke-Pester -Path ./tests` passes (0 failures)
- [ ] `Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` is clean
- [ ] New/changed public functions have comment-based help with 3+ examples
- [ ] Endpoints/scopes are verified against Microsoft Learn (no invented endpoints)
- [ ] New Graph traffic goes through `Invoke-GkGraphRequest`
- [ ] Scope-map entry added/updated for any new public function
- [ ] Write cmdlets support `-WhatIf`/`-Confirm`
- [ ] `docs/` regenerated (`./build/Build-GkDocs.ps1`) and `CHANGELOG.md` updated
