# Scope audit

Reconciles `$script:GkScopeMap` against Microsoft's own permission tables for every Graph call the
module makes. Run it whenever Microsoft changes a permission, or before a release that touches the
scope map. The verified result lives in `DESIGN.md` section 7 and is pinned by
`tests/Unit/ScopeMap.Tests.ps1`.

## Prerequisite

The permission tables are read from the docs source, not scraped from the rendered site. Clone it
once (shallow and sparse — the full repo is large):

```powershell
git -c core.longpaths=true clone --depth 1 --filter=blob:none --sparse `
    https://github.com/microsoftgraph/microsoft-graph-docs-contrib.git .\graph-docs
Push-Location .\graph-docs
git config core.longpaths true
git sparse-checkout set api-reference/v1.0/api api-reference/v1.0/includes `
                        api-reference/beta/api api-reference/beta/includes
Pop-Location
```

`core.longpaths` is required on Windows: some Intune doc filenames exceed the default limit and the
checkout aborts without it.

## Run

```powershell
.\Get-GkCallInventory.ps1     # source -> call-inventory.csv
.\Get-LearnPermissions.ps1    # docs   -> learn-permissions.csv
.\Compare-GkScopes.ps1        # verdicts per cmdlet
.\New-ScopeTable.ps1          # regenerates the DESIGN.md table
```

`Get-GkCallInventory.ps1` resolves URIs built in a local variable, but a handful are assembled at
runtime in ways static analysis cannot follow. Those are listed by hand in `call-supplement.csv`;
the script prints anything still unresolved, so a new one cannot slip through silently. Merge the
supplement into `call-inventory-final.csv` before running the comparison.

## Reading the output

`Compare-GkScopes.ps1` classifies each cmdlet:

- **OVER-PERMISSIVE** — the map offers a scope no call accepts. The pre-flight check passes and
  Graph returns 403. This is the failure mode worth fixing first.
- **TOO-STRICT** — a caller holding the documented least-privileged scope is rejected before any
  request is made.
- **OK** — every declared scope is accepted somewhere, and each call's least-privileged option is
  offered.

**The output is triage, not a verdict.** Confirm every finding against the Learn page before
changing code. Known reasons the tool is wrong:

- Permission tables do not carry **property-level** requirements. `accountEnabled` and
  `signInActivity` need extra scopes documented only in the surrounding prose; these are hard-coded
  in `Compare-GkScopes.ps1`.
- `/roleManagement/*` pages carry **one table per RBAC provider**. Only the directory provider
  applies; `Get-LearnPermissions.ps1` narrows to it, but a new page layout could defeat that.
- Graph sometimes classifies a **write** scope as least privileged for a read (for example
  `AppRoleAssignment.ReadWrite.All` on `GET /users/{id}/appRoleAssignments`). Offering it would be
  wrong for a reporting cmdlet, so some TOO-STRICT results are deliberate. See DESIGN.md section 7.

The machine-readable `permissions.json` that backs Graph Explorer was evaluated as a source and
rejected: it lags Learn. `User.ReadUpdate.All` went GA for `PATCH /users/{id}` in July 2026 and is
still missing from it.
