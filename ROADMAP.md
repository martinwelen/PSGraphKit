# PSGraphKit Roadmap

Backlog of planned cmdlets beyond the Phase 1 read-only baseline (v0.1.0). Items are grouped
by theme and are intentions, not commitments — each is designed and endpoint-verified against
Microsoft Learn before implementation (see `DESIGN.md` for the working method).

Status legend: **shipped** · **planned** · **idea**

---

## Phase 1 — read-only reporting (shipped, v0.1.0)

`Connect-GkGraph`, `Get-GkConnectionInfo`, `Get-GkStaleUser`, `Get-GkGuestInventory`,
`Get-GkLicenseOverview`, `Get-GkAdminRoleAssignment`, `Get-GkUserMfaStatus`,
`Get-GkUserAccessReport`, `Get-GkAppRegistrationReport`, `Get-GkGroupReport`,
`Get-GkCaPolicyReport`, `Get-GkDeviceInventory`.

---

## Phase 2 — write / remediation (shipped)

Action counterparts to the Phase 1 reports. All are state-changing and outward-facing, so each
supports `-WhatIf` / `-Confirm` (SupportsShouldProcess) and requires an explicit opt-in for bulk
runs. Designed to compose with the reports (`Get-Gk… | <action>`).

| Cmdlet | Remediates | Action |
|--------|-----------|--------|
| `Disable-GkStaleUser` | `Get-GkStaleUser` | block sign-in (accountEnabled = false) |
| `Remove-GkUserLicense` | `Get-GkLicenseOverview` | reclaim licenses from disabled/stale users |
| `Set-GkGroupOwner` | `Get-GkGroupReport` | add owner(s) to ownerless groups |
| `Remove-GkStaleGuest` | `Get-GkGuestInventory` | disable or remove stale guest accounts |
| `Disable-GkStaleDevice` | `Get-GkDeviceInventory` | disable or delete stale devices |
| `Revoke-GkUserSession` | `Get-GkUserMfaStatus` | revoke sign-in sessions for at-risk users |
| `Reset-GkAppCredential` | `Get-GkAppRegistrationReport` | rotate an expiring secret/certificate |
| `Remove-GkAdminRoleAssignment` | `Get-GkAdminRoleAssignment` | remove an active/eligible role |

---

## Phase 3 — broader read coverage (shipped)

Lower-risk reports that widen the assessment surface.

- `Get-GkServicePrincipalReport` — enterprise apps and their OAuth2 consent grants (flags tenant-wide consent)
- `Get-GkSignInReport` — failed and risky sign-ins (audit log; P1/P2)
- `Get-GkAuthMethodPolicy` — tenant authentication-methods policy posture
- `Get-GkNamedLocation` — Conditional Access named locations
- `Get-GkCrossTenantAccess` — B2B / cross-tenant access settings
- `Get-GkCustomRole` — custom directory role definitions
- `Get-GkAdministrativeUnit` — administrative units
- `Get-GkLicenseAssignmentError` — users with failing license assignments

---

## Phase 4 — engagement deliverables (shipped / idea)

- `Export-GkTenantAssessment` (shipped) — runs the read suite into a single self-contained HTML
  (and optional CSVs) suitable to hand to a client. Pure read.
- `Get-GkSecurityBaseline` (idea) — compare tenant posture against a configurable checklist.

---

## Phase 5 — security & governance expansion (shipped, v0.3.0)

20 cmdlets across five themes, taking the module to 50 total:

- **Security posture & risk:** `Get-GkSecureScore`, `Get-GkRiskyUser`, `Get-GkRiskDetection`,
  `Get-GkDirectoryAudit`, `Get-GkPrivilegedRoleMember`
- **Access & CA hardening:** `Get-GkExternalCollaborationSetting`, `Get-GkRoleAssignableGroup`,
  `Get-GkLegacyAuthSignIn`, `Get-GkAuthStrengthPolicy`, `Get-GkConditionalAccessTemplate`
- **Apps, consent & credentials:** `Get-GkInactiveApp`, `Get-GkStaleAppCredential`,
  `Get-GkConsentRequest`, `Remove-GkConsentGrant`
- **Tenant, domains & licensing:** `Get-GkTenantInfo`, `Get-GkDomain`, `Get-GkSubscription`,
  `Get-GkGroupExpirationPolicy`
- **Membership & invitation (write):** `New-GkGuestInvitation`, `Add-GkGroupMember`, `Remove-GkGroupMember`

---

## v0.4 — candidates (idea)

Endpoint- and scope-verified against Microsoft Learn; not yet committed.

| Cmdlet | Endpoint | Scope | Channel |
|--------|----------|-------|---------|
| `Get-GkGroupMember` | `GET /groups/{id}/members` | GroupMember.Read.All | v1.0 |
| `Get-GkDeletedItem` | `GET /directory/deletedItems/microsoft.graph.{user\|group\|application}` | User/Group/Application.Read.All | v1.0 |
| `Get-GkRoleDefinition` | `GET /roleManagement/directory/roleDefinitions` | RoleManagement.Read.Directory | v1.0 |
| `New-GkTemporaryAccessPass` (write) | `POST /users/{id}/authentication/temporaryAccessPassMethods` | UserAuthenticationMethod.ReadWrite.All | v1.0 |
| `Reset-GkUserPassword` (write) | `PATCH /users/{id}` (passwordProfile) | User.ReadWrite.All | v1.0 |
| `Get-GkLapsPassword` | `GET /directory/deviceLocalCredentials/{deviceId}` | DeviceLocalCredential.Read.All (+ Device.Read.All) | v1.0 |
| `Get-GkUserAuthMethod` | `GET /users/{id}/authentication/methods` | UserAuthenticationMethod.Read.All | v1.0 |
| `Get-GkServiceHealth` | `GET /admin/serviceAnnouncement/healthOverviews` (+ `/issues`) | ServiceHealth.Read.All | v1.0 |
| `Get-GkServiceMessage` | `GET /admin/serviceAnnouncement/messages` | ServiceMessage.Read.All | v1.0 |
| `Get-GkGroupBasedLicense` | `GET /groups?$select=assignedLicenses,licenseProcessingState` | Group.Read.All | v1.0 |

Notes: `Get-GkGroupMember` is the read companion to the shipped `Add`/`Remove-GkGroupMember`.
`Get-GkDeletedItem` pairs with the honorable-mention `Restore-GkDeletedObject`. `Get-GkLapsPassword`
returns a clear-text secret — treat as sensitive (mask by default).

## Connection UX / error DX (shipped, except auto-connect)

Improvements to how `Test-GkConnection` reports a not-connected / missing-scope failure.

- **Recommend `Connect-GkGraph`, not raw `Connect-MgGraph`** (shipped). All three pre-flight
  failures now lead with `Run: Connect-GkGraph -ForCommand <FunctionName>`, which derives the scope
  set from `$script:GkScopeMap`, and keep the raw `-Scopes` value as a secondary note.
- **Clean error rendering** (shipped). Public cmdlets pass `-Caller $PSCmdlet`, so the terminating
  error is raised from the cmdlet the user typed instead of the private helper. ConciseView renders
  it as `Get-GkStaleUser: <message>` rather than exposing `Test-GkConnection:<file>:<line>`.
- **Optional opt-in auto-connect (idea).** On not-connected, offer to run
  `Connect-GkGraph -ForCommand <name>` interactively instead of erroring. Must stay opt-in (a
  `$GkAutoConnect` preference or explicit switch) — never surprise unattended/scripted runs with an
  interactive prompt.

---

## Honorable mentions (idea)

`Restore-GkDeletedObject`, `Set-GkUserManager`, `Get-GkEnterpriseAppAssignment`,
`Get-GkBreakGlassAccount`, `Test-GkCaCoverage`, plus P2/governance reports (`Get-GkAccessReview`,
`Get-GkTermsOfUse`, `Get-GkAccessPackage`) and `Get-GkDelegatedAdminRelationship` (GDAP).

---

## Cross-cutting considerations

- **Dependency constraint holds:** Microsoft.Graph.Authentication only. Exports use native
  `ConvertTo-Html` / `Export-Csv`; no Excel/reporting module dependency.
- **Write safety:** every state-changing cmdlet is SupportsShouldProcess, defaults to per-item
  confirmation, and surfaces the exact change before making it.
- **Scopes:** write cmdlets require write scopes (e.g. `User.ReadWrite.All`) declared in the same
  capability-group scope map; `Test-GkConnection` validates them the same way.
