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

## v0.4 — connection UX / error DX (idea)

Improvements to how `Test-GkConnection` reports a not-connected / missing-scope failure. The
pre-flight check itself works (throws an actionable terminating error); these refine what it
points the user at and how it renders.

- **Recommend `Connect-GkGraph`, not raw `Connect-MgGraph`.** The not-connected and missing-scope
  hints currently say `Run: Connect-MgGraph -Scopes <scope...>`, which pushes the user to
  hand-assemble scopes. Change the hint to `Run: Connect-GkGraph -ForCommand <FunctionName>` (our
  helper already derives the scope set from `$script:GkScopeMap`), so the user never has to
  remember scopes per cmdlet. Keep the raw `-Scopes` value as a secondary/manual note.
  Touches `Get-GkConnectScopeHint` / the two `ThrowTerminatingError` messages in
  `Test-GkConnection.ps1`; update `Test-GkConnection.Tests.ps1` assertions in the same pass.
- **Clean error rendering.** PS7 ConciseView wraps the message in an internal code-frame pointing
  at `Test-GkConnection:<file>:61` (the helper call site), which reads like a leaked stack trace.
  Surface the failure as a clean one-liner attributed to the public cmdlet the user actually typed.
- **Optional opt-in auto-connect (idea).** On not-connected, offer to run
  `Connect-GkGraph -ForCommand <name>` interactively instead of erroring. Must stay opt-in (a
  `$GkAutoConnect` preference or explicit switch) — never surprise unattended/scripted runs with an
  interactive prompt.

- **`Get-GkSecureScore` pages the full history to use one day.** `secureScores?$top=1` returns a
  `@odata.nextLink`, so `Invoke-GkGraphRequest`'s auto-pagination walks all ~90 days of daily scores
  when only the latest is needed. Output is correct (fixed in 0.3.2) but wasteful — short-circuit to
  the first page (e.g. read with `-Raw` and take `value[0]`, or add a first-page-only option to
  `Invoke-GkGraphRequest`).

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
