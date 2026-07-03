<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/martinwelen/PSGraphKit/main/assets/readme-banner-dark.png">
    <img alt="PSGraphKit — Curated PowerShell cmdlets for Entra ID & Microsoft Graph" src="https://raw.githubusercontent.com/martinwelen/PSGraphKit/main/assets/readme-banner-light.png" width="820">
  </picture>
</p>

<p align="center">
  <a href="https://www.powershellgallery.com/packages/PSGraphKit"><img alt="PowerShell Gallery" src="https://img.shields.io/powershellgallery/v/PSGraphKit?logo=powershell&label=PSGallery"></a>
  <a href="https://www.powershellgallery.com/packages/PSGraphKit"><img alt="Downloads" src="https://img.shields.io/powershellgallery/dt/PSGraphKit?logo=powershell"></a>
  <a href="https://github.com/martinwelen/PSGraphKit/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/martinwelen/PSGraphKit/actions/workflows/ci.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-blue.svg"></a>
  <a href="https://learn.microsoft.com/powershell/"><img alt="PowerShell 7.4+" src="https://img.shields.io/badge/PowerShell-7.4%2B-5391FE?logo=powershell"></a>
</p>

A curated PowerShell module for everyday **Entra ID / Microsoft Graph** administration,
reporting, and remediation. It is a hand-built layer over the Microsoft Graph SDK that exposes
admin *intentions* as cmdlets — the inventory, assessment, and remediation tasks an M365
consultant performs at every engagement — without the raw OData, manual pagination, and cryptic
errors of the auto-generated SDK.

**50 cmdlets** across reporting, remediation, and a one-file tenant assessment export.
Dependency: `Microsoft.Graph.Authentication` only.

## Install

```powershell
Install-PSResource PSGraphKit      # or: Install-Module PSGraphKit
```

See [DESIGN.md](DESIGN.md) / [DESIGN-phase2.md](DESIGN-phase2.md) for the endpoint/scope plan,
[ROADMAP.md](ROADMAP.md) for what's planned, and [CHANGELOG.md](CHANGELOG.md) for history.

## Requirements

- **PowerShell 7.4+** (Windows PowerShell 5.1 is not supported)
- **Microsoft.Graph.Authentication** 2.10.0+ — the *only* dependency. PSGraphKit does not
  require the full Microsoft.Graph meta-module or any per-resource SDK module.

## Design principles

- **No invented endpoints.** Every Graph endpoint, property, and scope is verified against
  Microsoft Learn documentation.
- **One Graph chokepoint.** All traffic flows through an internal `Invoke-GkGraphRequest`
  that handles pagination, 429/503 throttling with `Retry-After` backoff, and
  `ConsistencyLevel` header re-injection across pages.
- **Actionable auth errors.** A pre-flight scope check plus runtime translation of 401/403
  errors — including *which Entra role you hold vs. which the operation needs* — so a
  permission failure tells you exactly what to fix.
- **Typed output.** Every cmdlet returns typed `PSCustomObject`s (`PSGraphKit.*`) with
  curated default columns and real `[datetime]` values, plus `-AsReport` for clean export.

## Authentication

PSGraphKit is auth-agnostic — it runs against whatever `Connect-MgGraph` session exists.

```powershell
# Delegated (interactive) — recommended for ad-hoc, cross-tenant assessments
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All

# App-only (enterprise app) — for automated/recurring reporting
Connect-MgGraph -ClientId <appId> -TenantId <tenantId> -CertificateThumbprint <thumb>
```

Or let PSGraphKit derive the scopes for the cmdlets you plan to run:

```powershell
Connect-GkGraph -ForCommand Get-GkStaleUser, Get-GkGuestInventory   # only what those need
Connect-GkGraph -AllCommands                                         # full read-only footprint
Connect-GkGraph -ClientId <appId> -TenantId <tid> -CertificateThumbprint <thumb>   # app-only
```

One caveat: `Get-GkUserAccessReport` reads `licenseDetails`, a Graph API with no application
permission, so it requires a **delegated** session.

## Quick start

```powershell
Import-Module ./src/PSGraphKit/PSGraphKit.psd1

# Confirm you're connected with enough privilege BEFORE generating reports
Get-GkConnectionInfo

# IsConnected : True
# Account     : admin@contoso.com
# AuthType    : Delegated
# Scopes      : AuditLog.Read.All, User.Read.All
# ActiveRoles : Global Reader
```

If a cmdlet is missing a scope, it tells you the exact command to run:

```
Missing Graph scope(s) for Get-GkStaleUser: to read signInActivity: one of [AuditLog.Read.All].
Run: Connect-MgGraph -Scopes User.Read.All,AuditLog.Read.All
```

## Available cmdlets

**Connection**

| Cmdlet | Purpose |
|--------|---------|
| `Connect-GkGraph` | Connect to Graph, deriving required scopes from the cmdlets you plan to run. |
| `Get-GkConnectionInfo` | Show the current Graph session: identity, auth type, scopes, active roles. |

**Reports (read-only)**

| Cmdlet | Purpose |
|--------|---------|
| `Get-GkStaleUser` | Users with no sign-in for N days (signInActivity), flagging disabled/guest. |
| `Get-GkGuestInventory` | Guest accounts with sponsor, invitation state, age, and inactivity. |
| `Get-GkLicenseOverview` | Subscribed SKUs with assigned/available seats; optional disabled-but-licensed counts. |
| `Get-GkAdminRoleAssignment` | Directory role assignments — active, PIM-eligible, and PIM time-bound. |
| `Get-GkUserMfaStatus` | Per-user MFA capability and registered methods (registration report). |
| `Get-GkUserAccessReport` | One user's footprint: groups, roles, licenses, app assignments (delegated-only). |
| `Get-GkAppRegistrationReport` | App registrations with expiring secrets/certs and high-privilege permissions. |
| `Get-GkGroupReport` | Groups with type, membership count, owners, and ownerless flag. |
| `Get-GkCaPolicyReport` | Conditional Access policies with state and summarized conditions/controls. |
| `Get-GkDeviceInventory` | Entra devices with OS, join type, last activity, and stale flag. |
| `Get-GkServicePrincipalReport` | Enterprise apps with type/state and optional tenant-wide consent grants. |
| `Get-GkSignInReport` | Failed and risky sign-ins over a recent window (P1/P2). |
| `Get-GkAuthMethodPolicy` | Authentication-methods policy: which methods are enabled/disabled. |
| `Get-GkNamedLocation` | Conditional Access named locations (IP ranges / countries). |
| `Get-GkCrossTenantAccess` | Cross-tenant (B2B) access: default policy and partner trust settings. |
| `Get-GkCustomRole` | Custom directory role definitions and their permissions. |
| `Get-GkAdministrativeUnit` | Administrative units with membership type and member count. |
| `Get-GkLicenseAssignmentError` | Users with failing license assignments (incl. group-based). |

**Remediation (write — `-WhatIf`/`-Confirm`)**

| Cmdlet | Purpose |
|--------|---------|
| `Disable-GkStaleUser` | Block user sign-in (accountEnabled = false). |
| `Revoke-GkUserSession` | Revoke a user's sign-in sessions. |
| `Remove-GkUserLicense` | Reclaim license SKUs from a user. |
| `Set-GkGroupOwner` | Add an owner to a group. |
| `Remove-GkStaleGuest` | Disable (default) or delete a stale guest; refuses non-guests. |
| `Disable-GkStaleDevice` | Disable (default) or delete a device. |
| `Reset-GkAppCredential` | Add or remove an app registration client secret. |
| `Remove-GkAdminRoleAssignment` | Remove an active or PIM role assignment. |

**Deliverable**

| Cmdlet | Purpose |
|--------|---------|
| `Export-GkTenantAssessment` | Run the read suite into one self-contained HTML report (+ optional CSVs). |

All reporting cmdlets support `-AsReport` (export-shaped output) and emit typed `PSGraphKit.*`
objects with curated default views; write cmdlets support `-WhatIf`/`-Confirm`. Full per-cmdlet
reference is in **[docs/](docs/README.md)** (and via `Get-Help <name> -Full`); see
[DESIGN.md](DESIGN.md) / [DESIGN-phase2.md](DESIGN-phase2.md) for the endpoint/scope plan and
[ROADMAP.md](ROADMAP.md) for what's next.

## Development

```powershell
# Run the test suite (Pester 5)
Invoke-Pester -Path ./tests

# Lint
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1

# Regenerate the docs/ reference after changing any function's help
./build/Build-GkDocs.ps1
```

CI runs PSScriptAnalyzer + Pester on every push/PR (`.github/workflows/ci.yml`).

## License

[MIT](LICENSE)
