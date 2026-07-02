# PSGraphKit

A curated PowerShell module for everyday **Entra ID / Microsoft Graph** administration and
reporting. It is a hand-built layer over the Microsoft Graph SDK that exposes admin
*intentions* as cmdlets — the read-only inventory and assessment tasks an M365 consultant
performs at every engagement — without the raw OData, manual pagination, and cryptic errors
of the auto-generated SDK.

> **Status:** Phase 1 (read-only reporting/inventory) is under active development.
> See [DESIGN.md](DESIGN.md) for the endpoint/scope plan and [CHANGELOG.md](CHANGELOG.md).

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

| Cmdlet | Purpose |
|--------|---------|
| `Get-GkConnectionInfo` | Show the current Graph session: identity, auth type, scopes, active roles. |

_Phase 1 reporting cmdlets (stale users, guests, licenses, roles, MFA, access, app
registrations, groups, Conditional Access, devices) are being added one at a time in
priority order — see DESIGN.md._

## Development

```powershell
# Run the test suite (Pester 5)
Invoke-Pester -Path ./tests

# Lint
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

CI runs PSScriptAnalyzer + Pester on every push/PR (`.github/workflows/ci.yml`).

## License

[MIT](LICENSE)
