# PSGraphKit — Design (Phase 2+)

Status: **Shipped — kept as the design record.** Everything below was delivered in v0.2.0 and
v0.3.0: the write/remediation cmdlets (Phase 2), the broader reports (Phase 3), and the assessment
export (Phase 4). It is preserved because it documents *why* each endpoint, method and body was
chosen, which the code cannot show; it is no longer a plan, and the build sequencing in section 7 is
history rather than instruction.

**For the current scope model, read `DESIGN.md` section 7, not this file.** The scopes named here
were correct when written, but the whole surface was re-audited afterwards and the capability groups
have since widened — notably to accept `ReadWrite` scopes wherever Graph treats them as covering the
corresponding read. Where the two documents disagree, DESIGN.md wins and this one is out of date.

Extends the Phase 1 baseline (`DESIGN.md`, v0.1.0). Every endpoint, scope, HTTP method, and request
body below was verified against Microsoft Learn (URLs cited); nothing is invented. Constraints that
change the approach are called out under **Notable constraints**.

The dependency constraint holds: **Microsoft.Graph.Authentication only**. Exports use
`Microsoft.PowerShell.Utility` (`ConvertTo-Html`, `Export-Csv`), which ships with PowerShell.

---

## 1. `Invoke-GkGraphRequest` changes required

Phase 2 introduces state-changing verbs. The chokepoint needs:

- **Methods:** add `PATCH` and `DELETE` to the `-Method` set (currently `GET`/`POST`).
- **Bodies:** hashtable `-Body` is serialized to JSON by `Invoke-MgGraphRequest` — already supported;
  ensure `Content-Type: application/json` for PATCH/POST.
- **Empty responses:** `204 No Content` (most writes) yields no body; the success path must return
  cleanly (no unwrap). Actions returning a body (`addPassword` → `secretText`) use `-Raw`.
- The existing paging/throttling/error-translation applies unchanged to writes.

## 2. Write-safety conventions (Phase 2)

Every state-changing cmdlet:

- Declares `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]` and gates the call on
  `$PSCmdlet.ShouldProcess(<target>, <action>)`, so `-WhatIf` and `-Confirm` work and destructive
  runs prompt by default.
- Accepts targets from the pipeline so a report composes into its remediation
  (`Get-GkStaleUser -InactiveDays 180 | Disable-GkStaleUser -WhatIf`).
- Surfaces the concrete change (which user/SKU/role) in the `ShouldProcess` description before acting.
- Emits a typed result object (`PSGraphKit.<Verb>Result`) recording target, action, and outcome, so
  bulk runs are auditable and pipeable.
- Distinguishes **scope** from **directory role**: many writes require the caller to *also* hold an
  Entra role (e.g. User Administrator, Cloud Device Administrator, Privileged Role Administrator).
  The existing 403 role-enrichment in `Invoke-GkGraphRequest` already surfaces this; per-cmdlet
  `RoleHints` in the scope map name the roles.

## 3. Scope handling for writes

Write scopes join the same capability-group `$script:GkScopeMap`; `Test-GkConnection` validates them
identically. Write cmdlets require the write scope for the action; enumeration of candidates is the
paired reader's responsibility (and its read scopes).

---

## 4. Phase 2 — write / remediation cmdlets (verified)

### `Disable-GkStaleUser`
- `PATCH /users/{id}` body `{ "accountEnabled": false }` · v1.0
- Scope: `User.EnableDisableAccount.All` (least, paired with `User.Read.All`) or `User.ReadWrite.All`.
- Role: User Administrator (higher role required to disable admins). Response 204.
- Docs: https://learn.microsoft.com/graph/api/user-update?view=graph-rest-1.0

### `Remove-GkUserLicense`
- `POST /users/{id}/assignLicense` body `{ "addLicenses": [], "removeLicenses": ["<skuId>"] }` · v1.0
- Scope: `LicenseAssignment.ReadWrite.All`. Reading SKUs to resolve GUIDs uses `Organization.Read.All`.
- Note: group-based licenses cannot be removed per-user (must change group assignment) — detect
  `assignedByGroup` (from `Get-GkLicenseAssignmentError` / licenseAssignmentStates) and refuse with a
  clear message. Response 200 + user.
- Docs: https://learn.microsoft.com/graph/api/user-assignlicense?view=graph-rest-1.0

### `Set-GkGroupOwner`
- `POST /groups/{id}/owners/$ref` body `{ "@odata.id": "https://graph.microsoft.com/v1.0/users/{id}" }` · v1.0
- Scope: `Group.ReadWrite.All`. Max **100 owners**/group. Owner may be user or servicePrincipal.
  Response 204 (400 if already an owner).
- Docs: https://learn.microsoft.com/graph/api/group-post-owners?view=graph-rest-1.0

### `Remove-GkStaleGuest`
- `DELETE /users/{id}` (or `PATCH accountEnabled=false` to only block) · v1.0
- Scope: `User.ReadWrite.All`. **Soft-delete**: recoverable 30 days via
  `/directory/deletedItems/microsoft.graph.user`; a `-Permanent` switch could `DELETE
  /directory/deletedItems/{id}` (guarded). Default action = disable; deletion requires explicit intent.
- Docs: https://learn.microsoft.com/graph/api/user-delete?view=graph-rest-1.0

### `Disable-GkStaleDevice`
- Disable `PATCH /devices/{id}` body `{ "accountEnabled": false }`; delete `DELETE /devices/{id}` · v1.0
- Scope: delegated `Directory.AccessAsUser.All` (**no delegated `Device.ReadWrite.All` exists**);
  app-only `Device.ReadWrite.All`. Role: Cloud Device Administrator (enable/disable) or Intune
  Administrator (delete). Soft-delete 30 days. Default action = disable.
- Docs: https://learn.microsoft.com/graph/api/device-update?view=graph-rest-1.0 · https://learn.microsoft.com/graph/api/device-delete?view=graph-rest-1.0

### `Revoke-GkUserSession`
- `POST /users/{id}/revokeSignInSessions` (no body) · v1.0
- Scope: `User.RevokeSessions.All` (least — *not* `User.ReadWrite.All`). Skips external/B2B users
  (they authenticate in their home tenant). ~minutes propagation.
- Docs: https://learn.microsoft.com/graph/api/user-revokesigninsessions?view=graph-rest-1.0

### `Reset-GkAppCredential` (secrets only)
- Add `POST /applications/{id}/addPassword` body `{ "passwordCredential": { "displayName": "...",
  "endDateTime": "..." } }` → returns `secretText` **once** (use `-Raw`); remove `POST
  /applications/{id}/removePassword` body `{ "keyId": "<guid>" }` · v1.0
- Scope: `Application.ReadWrite.All` (app: `Application.ReadWrite.OwnedBy`).
- **Certificates are out of scope:** `addKey`/`removeKey` require a self-signed proof-of-possession
  JWT signed by an existing valid private key, and cannot bootstrap the first/only cert. Certificate
  rotation belongs to a dedicated tool with key material; this cmdlet manages client secrets only.
- Docs: https://learn.microsoft.com/graph/api/application-addpassword?view=graph-rest-1.0 · https://learn.microsoft.com/graph/api/application-removepassword?view=graph-rest-1.0

### `Remove-GkAdminRoleAssignment`
- Direct (non-PIM) active: `DELETE /roleManagement/directory/roleAssignments/{id}` ·
  scope `RoleManagement.ReadWrite.Directory`.
- PIM eligible: `POST /roleManagement/directory/roleEligibilityScheduleRequests` body
  `{ "action": "adminRemove", "principalId", "roleDefinitionId", "directoryScopeId": "/" }` ·
  scope `RoleEligibilitySchedule.ReadWrite.Directory`.
- PIM active: `POST /roleManagement/directory/roleAssignmentScheduleRequests` (same body shape,
  `scheduleInfo` generally required) · scope `RoleAssignmentSchedule.ReadWrite.Directory`.
- The cmdlet picks the path from the assignment kind (as reported by `Get-GkAdminRoleAssignment`).
  Cannot remove the caller's own Global Administrator assignment (400). Role: Privileged Role Admin.
- Docs: https://learn.microsoft.com/graph/api/unifiedroleassignment-delete?view=graph-rest-1.0 · https://learn.microsoft.com/graph/api/rbacapplication-post-roleeligibilityschedulerequests?view=graph-rest-1.0 · https://learn.microsoft.com/graph/api/rbacapplication-post-roleassignmentschedulerequests?view=graph-rest-1.0

---

## 5. Phase 3 — broader reports (verified)

### `Get-GkServicePrincipalReport`
- `GET /servicePrincipals` (`appId`, `displayName`, `appRoleAssignmentRequired`, `accountEnabled`,
  `servicePrincipalType`, `tags`, credential metadata) · scope `Application.Read.All`.
- Consent grants `GET /oauth2PermissionGrants` (`clientId`, `consentType`, `principalId`,
  `resourceId`, `scope`) · scope `Directory.Read.All` (**no read-only `DelegatedPermissionGrant.Read.All`
  exists**). App permissions held: `GET /servicePrincipals/{id}/appRoleAssignments`.
- Flag `consentType == AllPrincipals` (tenant-wide delegated consent) and application permissions.
- Docs: https://learn.microsoft.com/graph/api/serviceprincipal-list?view=graph-rest-1.0 · https://learn.microsoft.com/graph/api/oauth2permissiongrant-list?view=graph-rest-1.0

### `Get-GkSignInReport`
- `GET /auditLogs/signIns` (`userPrincipalName`, `appDisplayName`, `status`, `riskLevelAggregated`,
  `riskState`, `conditionalAccessStatus`, `ipAddress`, `createdDateTime`, `clientAppUsed`) · v1.0
- Scope: `AuditLog.Read.All`; add `Policy.Read.All` to populate `appliedConditionalAccessPolicies`.
- **Requires Entra ID P1/P2.** Supports `$top`/`$skiptoken`/`$filter` only; a date-range `$filter` is
  mandatory in practice (default `-Days 7`). Retention ~7 days (free) / ~30 days (P1/P2).
- Docs: https://learn.microsoft.com/graph/api/signin-list?view=graph-rest-1.0

### `Get-GkAuthMethodPolicy`
- `GET /policies/authenticationMethodsPolicy` → per-method `state` in
  `authenticationMethodConfigurations[]` (fido2, microsoftAuthenticator, sms, temporaryAccessPass, …)
  · scope `Policy.Read.AuthenticationMethod` (or `Policy.Read.All`). No OData params.
- Docs: https://learn.microsoft.com/graph/api/authenticationmethodspolicy-get?view=graph-rest-1.0

### `Get-GkNamedLocation`
- `GET /identity/conditionalAccess/namedLocations` (heterogeneous by `@odata.type`: `ipNamedLocation`
  with `isTrusted`/`ipRanges[].cidrAddress`; `countryNamedLocation` with `countriesAndRegions`) ·
  scope `Policy.Read.All`.
- Docs: https://learn.microsoft.com/graph/api/conditionalaccessroot-list-namedlocations?view=graph-rest-1.0

### `Get-GkCrossTenantAccess`
- `GET /policies/crossTenantAccessPolicy/default` (`isServiceDefault`, inbound/outbound B2B blocks,
  `automaticUserConsentSettings`) and `/partners` (per-tenant overrides) · scope `Policy.Read.All`.
  `identitySynchronization` needs `$expand` + a higher role; `m365Capabilities` is beta-only.
- Docs: https://learn.microsoft.com/graph/api/crosstenantaccesspolicy-list-partners?view=graph-rest-1.0

### `Get-GkCustomRole`
- `GET /roleManagement/directory/roleDefinitions?$filter=isBuiltIn eq false` (`displayName`,
  `isEnabled`, `rolePermissions[].allowedResourceActions`) · scope `RoleManagement.Read.Directory`.
  `isPrivileged` is **beta-only** — not used in v1.0.
- Docs: https://learn.microsoft.com/graph/api/rbacapplication-list-roledefinitions?view=graph-rest-1.0

### `Get-GkAdministrativeUnit`
- `GET /directory/administrativeUnits` (+ `/members`, `/scopedRoleMembers`). Scopes:
  `AdministrativeUnit.Read.All` (AU + members) and `RoleManagement.Read.Directory` (scoped role
  members — a *second* capability group); hidden-membership AUs also need `Member.Read.Hidden`.
- Docs: https://learn.microsoft.com/graph/api/directory-list-administrativeunits?view=graph-rest-1.0

### `Get-GkLicenseAssignmentError`
- `GET /users?$select=id,userPrincipalName,licenseAssignmentStates` (returned only on `$select`);
  filter client-side where `state` in `Error`/`ActiveWithError`. Each state: `skuId`, `state`,
  `error`, `assignedByGroup` (group id = group-based licensing). Scope `User.Read.All`; resolve SKU
  names via `/subscribedSkus`.
- Docs: https://learn.microsoft.com/graph/api/resources/licenseassignmentstate?view=graph-rest-1.0

---

## 6. Phase 4 — `Export-GkTenantAssessment`

Pure-read orchestration; no Graph write. Runs the Phase 1/3 readers and renders one self-contained
report, using only `Microsoft.PowerShell.Utility`:

- **HTML:** `ConvertTo-Html -Fragment` per dataset (with `-PreContent` section headings), collect the
  fragments, then one wrapping `ConvertTo-Html -Body $fragments -Head '<style>…</style><title>…'`
  (inline CSS via `-Head`, **not** `-CssUri`, to stay self-contained). `Out-File`.
- **CSV:** one `Export-Csv -NoTypeInformation -Encoding UTF8` per dataset.
- **Pre-flatten** nested/array properties (`ipRanges.cidrAddress`, `allowedResourceActions`,
  `disabledPlans`, methods) with `Select-Object` calculated properties — `ConvertTo-Html`/`Export-Csv`
  render collections as type names otherwise, and derive columns from the first object only, so
  objects must be normalized to a consistent shape first.
- Docs: https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertto-html?view=powershell-7.6

---

## 7. Build sequencing

1. **Wrapper prep:** add PATCH/DELETE + 204 handling to `Invoke-GkGraphRequest` (with tests) — enables
   all of Phase 2.
2. **Phase 2 writes**, lowest-risk first: `Revoke-GkUserSession`, `Disable-GkStaleUser`,
   `Remove-GkUserLicense`, `Set-GkGroupOwner`, then the more destructive `Remove-GkStaleGuest`,
   `Disable-GkStaleDevice`, `Reset-GkAppCredential`, `Remove-GkAdminRoleAssignment`. One commit each,
   ShouldProcess + fixture-mocked tests (assert the request is *not* sent under `-WhatIf`).
3. **Phase 3 reports** (independent, low-risk) can interleave.
4. **Phase 4 export** last, once the readers it composes are stable.

## 8. Notable constraints (decisions)

- **App certificate rotation is out of scope** (proof-of-possession JWT + private key required);
  `Reset-GkAppCredential` handles client secrets only.
- **Device writes are delegated-role gated** and use `Directory.AccessAsUser.All`, not a device-
  specific delegated scope.
- **User/device/guest deletes are soft** (30-day recovery); destructive cmdlets default to *disable*
  and require explicit intent (and a guarded `-Permanent`) to purge.
- **PIM removals are request-based** (`adminRemove`), not DELETEs, with their own schedule scopes.
- **Group-based licenses** cannot be removed per user; `Remove-GkUserLicense` detects and refuses.
- **Sign-in reporting requires P1/P2**; `isPrivileged` (custom roles) and `m365Capabilities`
  (cross-tenant) are beta-only and excluded from the v1.0 surface.
