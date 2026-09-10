# PSGraphKit — Design (Phase 1)

Status: **Baseline design for Phase 1** (implemented in v0.1.0).

PSGraphKit is a hand-curated PowerShell 7.4+ layer over Microsoft Graph that exposes
Entra ID / M365 admin *intentions* as cmdlets. Phase 1 is **read-only** reporting and
inventory. Every endpoint, property, and scope below was verified against Microsoft Learn
(URLs cited per function); nothing is invented. Items that could not be confirmed from
docs are called out explicitly, and the resolved decisions are summarized under
**Design decisions** at the end.

---

## 1. The `Invoke-GkGraphRequest` contract

Single internal chokepoint for all Graph traffic. Wraps `Invoke-MgGraphRequest`
(Microsoft.Graph.Authentication only). Handles pagination, throttling, header
re-injection, and optional beta fallback.

### Signature

```powershell
function Invoke-GkGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]   $Uri,          # relative ('/users?...') or absolute
        [ValidateSet('GET','POST')][string] $Method = 'GET',
        [hashtable] $Body,
        [hashtable] $Headers,                            # e.g. @{ ConsistencyLevel = 'eventual' }
        [ValidateSet('v1.0','beta')][string] $ApiVersion = 'v1.0',
        [switch]  $BetaFallback,                          # opt-in per call; see below
        [switch]  $All,                                   # follow @odata.nextLink to completion (default ON for GET collections)
        [switch]  $Raw,                                   # return the raw response hashtable, don't unwrap 'value'
        [int]     $MaxRetry = 5
    )
}
```

### Behavior

- **Base URL / version.** Relative `$Uri` is prefixed with `https://graph.microsoft.com/$ApiVersion`.
  Absolute URIs (i.e. an `@odata.nextLink`) are passed through unchanged.
- **Output type.** Calls `Invoke-MgGraphRequest -OutputType Hashtable`. Hashtable indexing
  (`$r['value']`, `$r['@odata.nextLink']`, `$r['@odata.count']`) avoids the `$r.'@odata.x'`
  quoting dance and gives clean nested access. Verified: nextLink/count are **body**
  properties, not headers.
- **Pagination.** Loops on `$r['@odata.nextLink']` (a full absolute URL, confirmed reusable
  as-is) until absent, accumulating `value[]`. Returns the flattened array. With `-Raw`,
  returns the first page's hashtable untouched (for `$count`-only or single-object reads).
- **Header re-injection (critical).** Custom headers — notably `ConsistencyLevel: eventual`
  — are **not** carried to nextLink requests by Graph, so the wrapper re-passes `$Headers`
  on **every** page. Also note `@odata.count` appears only on page 1.
- **Throttling / transient errors.** Calls with `-SkipHttpErrorCheck -StatusCodeVariable sc
  -ResponseHeadersVariable rh` so a 429/503 does not throw and we can inspect status +
  `Retry-After`. On **429** or **503**: honor `Retry-After` (seconds) if present, else bounded
  exponential backoff (2^n with jitter), up to `-MaxRetry`; 503 retried on a fresh request.
  Other 4xx/5xx are classified and translated to actionable errors (see below).

### Error classification — permission & role failures (the part you asked about)

Two layers, because a scope in the token is **not** the same as holding the directory role:

- **Pre-flight** — `Test-GkConnection` catches *missing OAuth scopes* before any call (fast,
  no wasted request). Covers the "you never consented to AuditLog.Read.All" case.
- **Runtime** — even after that passes, Graph can still reject the call because the *signed-in
  admin's Entra role* is insufficient, or the object is out of scope. `Invoke-GkGraphRequest`
  inspects `$sc` (StatusCodeVariable) + the parsed `error.code` and re-throws a curated,
  actionable message rather than a raw Graph blob:

  | Status | Graph `error.code` | Translated message (example) |
  |---|---|---|
  | 401 | `InvalidAuthenticationToken` | "Session expired or invalid. Run Connect-MgGraph again." |
  | 403 | `Authorization_RequestDenied` | "Access denied calling `<uri>`. Your token has the scope, but the signed-in identity lacks the required Entra role (e.g. Directory Readers / Global Reader) — or this is app-only where delegated is required. Function: `<fn>`." |
  | 403 | *(app-only on delegated-only API)* | "`licenseDetails` is delegated-only; reconnect with an interactive/delegated session." |
  | 400 | `Request_UnsupportedQuery` | "Query needs advanced parameters — retried with ConsistencyLevel:eventual; still failing, please report." |
  | 404 | `Request_ResourceNotFound` | passed through with the resource id for context |

  The original Graph `error.code`/`message`/`request-id` is always attached to the
  `ErrorRecord` (via `-ErrorId` / `TargetObject`) so nothing is lost for troubleshooting, but
  the top-line message tells the admin *what to fix*. Scope-vs-role is called out explicitly
  because holding e.g. `Directory.Read.All` as a scope does **not** guarantee the role behind
  it — a 403 after a green `Test-GkConnection` is a role problem, and the message says so.
- **License/feature-gated data** (signInActivity → P1/P2; PIM → P2) may surface as a 403 or as
  empty/null data depending on the endpoint; per the degrade-mode default these warn-and-continue
  with null fields rather than aborting the whole report.

### Enriching 403s with the caller's *actual* roles

To make 403s specific instead of guesses, on an access-denied (and on demand) we enumerate the
signed-in admin's current roles and name both what they have and what the operation needs.

- **How:** `GET /me/transitiveMemberOf/microsoft.graph.directoryRole?$select=displayName,roleTemplateId`
  (the OData cast filters memberOf's mixed collection to directory roles). Self-read least scope
  is `User.Read` — almost always already present, so even an under-privileged admin can read their
  own roles. Wrapped in a session-cached helper `Get-GkCurrentUserRole` so it runs at most once.
- **Per-function role hints:** the scope map gains an optional companion table of the *documented
  least-privileged built-in roles* per endpoint (sourced from each Graph "list" doc's "Delegated
  Entra roles" section, only where MS documents it — no invented roles). Lets the message say
  "you hold X; this needs one of Y/Z."
- **Three honesty guards baked into the wording:**
  1. **Active-only** — `memberOf` reflects *activated* assignments; a PIM-eligible-but-inactive
     role won't show. Message says "currently *active* roles" and, where relevant, hints at PIM
     activation rather than asserting the role is absent.
  2. **Custom roles** — built-in list is guidance; phrasing is "one of: …, or a custom role
     granting `<microsoft.directory/... action>`."
  3. **Delegated-only** — app-only has no user roles; for `AuthType = AppOnly` we report the
     service principal's granted app-role scopes instead of calling `/me`.
- **Bonus public helper (proposed):** `Get-GkConnectionInfo` (a "whoami") surfacing identity,
  auth type, granted scopes, and active roles in one object — handy to run at the start of an
  engagement to confirm you're connected with enough privilege before generating reports.
  > Two behaviors the research flagged as inferred, not doc-stated, and to confirm in a live
  > session before finalizing: (a) that `Invoke-MgGraphRequest` throws terminating on 429 by
  > default — we sidestep this entirely with `-SkipHttpErrorCheck`; (b) exact `-OutputType`
  > return types. Neither blocks the design.
- **Beta fallback.** Phase 1 uses **v1.0 for every function** (all 10 confirmed GA). The
  `-BetaFallback` switch is plumbing for the future: when set, a 404/`BadRequest` on a v1.0
  path is retried once against `beta`. It stays **off** by default and unused in Phase 1;
  no function silently reaches for beta.

---

## 2. Scope handling

### Declaration — module-level lookup table

Scopes are declared in a single module-scoped hashtable `$script:GkScopeMap` keyed by
function name, rather than a `[GkRequiredScopes()]` attribute. Rationale: a PowerShell class
attribute can't be trivially read back from an *exported advanced function* at call time
without reflection gymnastics; a lookup table is introspectable, testable, and lets docs
enumerate requirements without invoking anything.

```powershell
$script:GkScopeMap = @{
    'Get-GkStaleUser'            = @('AuditLog.Read.All','User.Read.All')
    'Get-GkGuestInventory'       = @('User.Read.All')
    'Get-GkLicenseOverview'      = @('Organization.Read.All','User.Read.All')
    'Get-GkAdminRoleAssignment'  = @('RoleManagement.Read.All')
    'Get-GkUserMfaStatus'        = @('AuditLog.Read.All')
    'Get-GkUserAccessReport'     = @('Directory.Read.All','LicenseAssignment.Read.All')
    'Get-GkAppRegistrationReport'= @('Application.Read.All')
    'Get-GkGroupReport'          = @('Group.Read.All','GroupMember.Read.All')
    'Get-GkCaPolicyReport'       = @('Policy.Read.All')
    'Get-GkDeviceInventory'      = @('Device.Read.All')
}
```

### Authentication model (proposed default — pending confirmation)

The module is **auth-agnostic**: all traffic goes through whatever `Connect-MgGraph`
session exists, so the data path never forks on auth type. Proposed defaults:

- **Delegated-first.** Interactive/device-code delegated sign-in is the default and the
  example throughout — best for zero-footprint cross-tenant assessments (nothing to register
  or admin-consent in the customer tenant).
- **App-only fully supported, secondary.** An optional thin `Connect-GkGraph` passes through
  to `Connect-MgGraph`, accepting `-Scopes` (interactive) or `-ClientId/-TenantId/-Certificate`
  (app-only). It is never *required* — an admin who already ran `Connect-MgGraph` just works.
- **Managed identity** deferred to a later phase (relevant only for Azure-hosted scheduled runs).
- Auth type only matters in two spots: `licenseDetails` is delegated-only (see below), and
  `/me` + delegated-role-gated `/sponsors` reads. `Test-GkConnection` enforces these.

### Validation — `Test-GkConnection`

Called at the top of every public function (or via a shared `begin` helper):

1. `$ctx = Get-MgContext`; if `$null` → actionable error: *"Not connected. Run: Connect-MgGraph -Scopes <required>"*.
2. Compare `$ctx.Scopes` (string[], confirmed the granted-scopes property) against the
   function's required set. Treat a broader scope as satisfying a narrower need where Graph
   documents that (e.g. `Directory.Read.All` covers `User.Read.All`) via a small
   equivalence map.
3. On any missing scope, throw:
   `"Missing scope AuditLog.Read.All for Get-GkStaleUser. Run: Connect-MgGraph -Scopes AuditLog.Read.All,User.Read.All"`.
4. **Auth-type caveat:** one Phase-1 data source is **delegated-only** — `licenseDetails`
   (used by `Get-GkUserAccessReport`, fn 6) does not support app-only permissions.
   `userRegistrationDetails` (fn 5) *does* support app-only (`AuditLog.Read.All` as an
   application permission). `Test-GkConnection` checks `$ctx.AuthType -eq 'Delegated'` for
   `Get-GkUserAccessReport` and warns/branches accordingly. Also note app-only cannot use
   `/me`, and delegated `/sponsors` reads depend on the signed-in admin's directory role.

---

## 3. Output conventions

- Each function emits **typed `PSCustomObject`s** with `PSTypeName = 'PSGraphKit.<Name>'`
  (e.g. `PSGraphKit.StaleUser`).
- Curated default column sets via `Formats/PSGraphKit.Format.ps1xml` — a few meaningful
  columns per type; full data still accessible via `Select-Object *`.
- **Dates are `[datetime]`**, never strings. Graph returns ISO-8601 DateTimeOffset; the
  wrapper/functions cast to `[datetime]` (or leave `$null`).
- Derived convenience fields are computed, not raw: e.g. `InactiveDays` (int, from
  signInActivity), `IsStale` (bool, from threshold), `DaysUntilExpiry` (secrets/certs).
- **`-AsReport`**: flattens nested/collection fields to export-friendly scalars (e.g.
  `MethodsRegistered` joined to a `; `-delimited string, owner arrays to counts + names)
  so `Export-Csv` / `Export-Excel` produce clean rows. Without it, objects keep rich nested
  members for pipeline use.
- All functions stream to the pipeline (emit per-object), accept relevant identifiers from
  the pipeline where sensible (e.g. `Get-GkUserAccessReport -UserId` by value/property).

---

## 4. Per-function endpoint & scope plan (all v1.0, verified)

Legend: **CL** = requires `ConsistencyLevel: eventual` + `$count=true` (advanced query).

### 1. `Get-GkStaleUser`
- `GET /users?$select=id,displayName,userPrincipalName,accountEnabled,userType,signInActivity`
- Scopes: **AuditLog.Read.All** (mandatory for signInActivity) + **User.Read.All**.
- signInActivity sub-props: `lastSignInDateTime`, `lastNonInteractiveSignInDateTime`,
  `lastSuccessfulSignInDateTime` (+ requestId siblings). `lastSuccessfulSignInDateTime` is
  only populated from **2023-12-01**, not backfilled — use `lastSignInDateTime` as the
  primary staleness signal, expose the others.
- **Requires Entra ID P1/P2** to read signInActivity. Max page size drops to **500** when
  selecting signInActivity. signInActivity `$filter` **cannot** combine with other property
  filters — so we filter server-side on the date alone (or fetch + filter client-side by the
  `-InactiveDays` threshold, which is simpler and robust). Flags: disabled (`accountEnabled`),
  guest (`userType`).
- Docs: https://learn.microsoft.com/graph/api/user-list?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/resources/signinactivity?view=graph-rest-1.0

### 2. `Get-GkGuestInventory`
- `GET /users?$filter=userType eq 'Guest'&$select=id,displayName,userPrincipalName,mail,externalUserState,externalUserStateChangeDateTime,createdDateTime,signInActivity,accountEnabled`
- Sponsor: `GET /users/{id}/sponsors` (v1.0, directoryObject collection — user or group).
- Scopes: **User.Read.All**. (Sponsors also gated by `User.Read`/`User.Read.All`; delegated
  work/school access additionally needs a directory role with
  `microsoft.directory/users/sponsors/read`, e.g. Directory Readers. **There is no
  `User-Sponsors.Read.All` scope** — that scope does not exist.)
- Derived: inactivity age from signInActivity, guest age from `createdDateTime`. One
  `/sponsors` call per guest (N+1) — will note the cost; acceptable for inventory runs.
- Docs: https://learn.microsoft.com/graph/api/user-list-sponsors?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/resources/user?view=graph-rest-1.0#properties

### 3. `Get-GkLicenseOverview`
- `GET /subscribedSkus` → `skuId, skuPartNumber, consumedUnits, prepaidUnits{enabled,suspended,warning,lockedOut}, servicePlans[], capabilityStatus, appliesTo`.
- Users per SKU: `GET /users?$filter=assignedLicenses/any(l:l/skuId eq {guid})&$select=...,accountEnabled`.
- Disabled-but-licensed: filter `assignedLicenses/any(...)` server-side, then client-side
  `accountEnabled -eq $false` (combining lambda + scalar in one server filter is **not**
  confirmed doc-supported and may need CL — safer to split).
- Scopes: **Organization.Read.All** (or `LicenseAssignment.Read.All`/`Directory.Read.All`)
  for SKUs + **User.Read.All** for the per-SKU user enumeration.
- Available = `prepaidUnits.enabled - consumedUnits`. Optional SKU GUID→friendly-name map
  (curated static table for common SKUs; `skuPartNumber` always shown as source of truth).
- Docs: https://learn.microsoft.com/graph/api/resources/subscribedsku?view=graph-rest-1.0

### 4. `Get-GkAdminRoleAssignment`
- Active: `GET /roleManagement/directory/roleAssignments?$expand=principal,roleDefinition`
  (modern RBAC API — preferred over legacy `directoryRoles/{id}/members`).
- PIM **eligible** (current): `GET /roleManagement/directory/roleEligibilityScheduleInstances`.
- PIM **active/time-bound**: `GET /roleManagement/directory/roleAssignmentScheduleInstances`
  (`assignmentType` Assigned/Activated, `startDateTime`/`endDateTime`).
- Scopes: **RoleManagement.Read.All** (single scope covers all three surfaces).
- PIM endpoints need **Entra ID P2 / Governance** to return data — absence handled
  gracefully (empty → note, not error). Output tags each row `AssignmentKind` =
  Active|Eligible|TimeBound.
- Docs: https://learn.microsoft.com/graph/api/rbacapplication-list-roleassignments?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/rbacapplication-list-roleeligibilityscheduleinstances?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/rbacapplication-list-roleassignmentscheduleinstances?view=graph-rest-1.0

### 5. `Get-GkUserMfaStatus`
- `GET /reports/authenticationMethods/userRegistrationDetails` → `isMfaCapable`,
  `isMfaRegistered`, `isSsprCapable/Registered`, `isPasswordlessCapable`, `methodsRegistered[]`,
  `isAdmin`, `userType`, `userPrincipalName`, `userDisplayName`, `lastUpdatedDateTime`.
- Scope: **AuditLog.Read.All** — the *only* documented scope. **`Reports.Read.All` is NOT
  accepted here** (corrected). Report chosen over per-user `/authentication/methods` because
  it answers "MFA-capable?" tenant-wide in one paged call with a ready boolean.
- Caveat surfaced in output: report has latency (`lastUpdatedDateTime`) and reflects policy
  state; `isMfaCapable` = strong method allowed by policy vs `isMfaRegistered` = registered
  regardless of policy.
- Docs: https://learn.microsoft.com/graph/api/authenticationmethodsroot-list-userregistrationdetails?view=graph-rest-1.0

### 6. `Get-GkUserAccessReport`
- Groups/roles/AUs: `GET /users/{id}/transitiveMemberOf` (cast `/microsoft.graph.group` for
  groups; returns groups + directoryRoles + administrativeUnits).
- App role assignments: `GET /users/{id}/appRoleAssignments` (`appRoleId`,
  `resourceDisplayName`, `principalType`, `createdDateTime`).
- Licenses: `GET /users/{id}/licenseDetails`.
- Scopes: **Directory.Read.All** (covers memberOf + appRoleAssignments read) +
  **LicenseAssignment.Read.All** (licenseDetails). Note `Application.Read.All` does **not**
  grant user appRoleAssignments read (corrected).
- **Delegated-only**: `licenseDetails` has no app-only permission — `Test-GkConnection`
  enforces `AuthType = Delegated` for this function.
- Docs: https://learn.microsoft.com/graph/api/user-list-transitivememberof?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/user-list-approleassignments?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/user-list-licensedetails?view=graph-rest-1.0

### 7. `Get-GkAppRegistrationReport`
- `GET /applications?$select=id,appId,displayName,passwordCredentials,keyCredentials,requiredResourceAccess,signInAudience`.
- Secrets/certs: `passwordCredentials`/`keyCredentials` → `keyId, displayName, startDateTime,
  endDateTime` → compute `DaysUntilExpiry`, `IsExpired`. (Scope `$select` to avoid pulling
  `keyCredentials.key` cert blobs, which are throttled and heavy.)
- High-privilege perms: `requiredResourceAccess[].resourceAppId` + `resourceAccess[]{id,type}`
  where `type = Role` (application permission) is highest risk. Resolve GUID→name by joining
  against the resource service principal's `appRoles`/`oauth2PermissionScopes`; flag against a
  curated high-risk permission list (e.g. `*.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`,
  `Directory.ReadWrite.All`). No `isHighPrivilege` flag exists on the app object — mapping is ours.
- Scope: **Application.Read.All**.
- Docs: https://learn.microsoft.com/graph/api/application-list?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/resources/requiredresourceaccess?view=graph-rest-1.0

### 8. `Get-GkGroupReport`
- `GET /groups?$select=id,displayName,groupTypes,securityEnabled,mailEnabled,membershipRule,membershipRuleProcessingState,visibility`.
- Type classification from (`groupTypes`, `mailEnabled`, `securityEnabled`): Unified=M365,
  `DynamicMembership` in groupTypes = dynamic, else security/distribution/mail-enabled-security
  per the verified truth table.
- Member count: `GET /groups/{id}/members/$count` (**CL** header, text/plain int).
- Owners: `GET /groups/{id}/owners`; ownerless = empty owners. **Caveat surfaced:** owners
  aren't returned for Exchange-created/distribution/on-prem-synced groups, so "ownerless" is
  reported with that qualifier, not as absolute truth.
- Scopes: **Group.Read.All** + **GroupMember.Read.All**.
- Docs: https://learn.microsoft.com/graph/api/group-list?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/group-list-members?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/group-list-owners?view=graph-rest-1.0

### 9. `Get-GkCaPolicyReport`
- `GET /identity/conditionalAccess/policies` (v1.0, GA).
- Fields: `displayName`, `state` (enabled/disabled/enabledForReportingButNotEnforced),
  `conditions` (users/applications/clientAppTypes/platforms/locations/signInRiskLevels…),
  `grantControls` (operator + builtInControls, authenticationStrength), `sessionControls`.
- Summarize into readable scalars: `IncludedUsers`, `ExcludedUsers`, `TargetApps`,
  `Controls` (e.g. `mfa AND compliantDevice`), `SessionControls`, plus raw nested objects
  retained for `Select *`.
- Scope: **Policy.Read.All** (doc lists only this for the v1.0 list endpoint — not
  `Policy.Read.ConditionalAccess`).
- Docs: https://learn.microsoft.com/graph/api/conditionalaccessroot-list-policies?view=graph-rest-1.0

### 10. `Get-GkDeviceInventory`
- `GET /devices?$select=id,deviceId,displayName,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime,registrationDateTime,accountEnabled,isCompliant,isManaged,deviceOwnership`.
- `trustType` values: **`AzureAd`** (cloud joined), **`ServerAd`** (hybrid/domain joined),
  **`Workplace`** (registered/BYO) — corrected: there is **no** "Hybrid" literal.
- Stale: `IsStale` from `approximateLastSignInDateTime` vs `-StaleDays` threshold. Caveat
  surfaced: the timestamp is *approximate* (periodic, not real-time).
- Scope: **Device.Read.All**.
- Docs: https://learn.microsoft.com/graph/api/device-list?view=graph-rest-1.0 ·
  https://learn.microsoft.com/graph/api/resources/device?view=graph-rest-1.0

---

## 5. Repository layout (to scaffold after approval)

```
src/PSGraphKit/
  PSGraphKit.psd1            # RequiredModules: Microsoft.Graph.Authentication only
  PSGraphKit.psm1            # dot-source Private/*, Public/*; export Public + Format
  Public/                    # one file per public function
  Private/                   # Invoke-GkGraphRequest, Test-GkConnection, scope map, helpers
  Formats/PSGraphKit.Format.ps1xml
tests/                       # Pester 5; unit tests mock Invoke-GkGraphRequest
  fixtures/                  # saved sample Graph JSON per function
.github/workflows/ci.yml     # PSScriptAnalyzer + Pester, no live tenant
PSScriptAnalyzerSettings.psd1
README.md  CHANGELOG.md (Keep a Changelog)  LICENSE (MIT)
```

Build order (priority): scaffold + `Invoke-GkGraphRequest` + `Test-GkConnection` + scope map
first (with their own tests/fixtures), then functions 1→10, one commit each with tests.

---

## 6. Design decisions

1. **Scope declaration mechanism** — module-level `$script:GkScopeMap` lookup (introspectable,
   testable, doc-friendly) over a `[GkRequiredScopes()]` attribute.
2. **Auth model** — delegated-first, with app-only fully supported via the optional
   `Connect-GkGraph`; managed identity is deferred. Only `licenseDetails` (fn 6) is truly
   delegated-only; `userRegistrationDetails` (fn 5) supports app-only.
3. **Scope breadth** — the map leans to the practical/broad consultant-friendly set
   (`Directory.Read.All`, `RoleManagement.Read.All`) so fewer connects cover more, expressed as
   capability groups so a broad scope satisfies a narrower need. Tightening to least-privilege
   per function is a mechanical change if wanted later.
4. **Degrade behavior** — warn-and-continue with nulls. When auth type or tenant license can't
   serve the data (app-only → `licenseDetails`; no P1/P2 → signInActivity; no P2 → PIM), an
   actionable warning is emitted and the unavailable fields are null, so the report runs
   end-to-end rather than hard-failing.
5. **Guest sponsor N+1** — sponsors are resolved per guest by default (one `/sponsors` call
   each) since sponsor is a headline column; `-SkipSponsor` opts out for large-tenant runs.
6. **`-OutputType`** — Hashtable internally, for clean `@odata.*` access.

---

## 7. Verified scope model (whole surface)

Section 4 above is the original Phase 1 plan for the first ten cmdlets. This section supersedes it
and covers every cmdlet the module ships.

### How it was verified

Each cmdlet's declared capability groups were reconciled against Microsoft's own documentation for
**every Graph call it makes** — 70 calls across 59 distinct endpoints:

1. Graph calls were extracted from the source by AST, resolving URIs assigned to a local variable
   and normalising OData segments (`$ref`, `$count`) and id placeholders.
2. Permission tables were read from the docs source (`microsoftgraph/microsoft-graph-docs-contrib`),
   following the per-channel `includes/permissions/*.md` file that each API page embeds.
3. Each declared scope was checked in both directions: does Graph accept it for at least one of the
   cmdlet's calls (otherwise the pre-flight check passes and Graph returns 403), and is the
   documented least-privileged option offered (otherwise a legitimate caller is falsely rejected).

Two sources were compared, and **Learn is the authority**. The machine-readable
`permissions.json` used by Graph Explorer lags it — `User.ReadUpdate.All` went GA for
`PATCH /users/{id}` in July 2026 and is still absent from that snapshot.

Two things the generated permission tables do **not** capture, which were supplied by hand from the
prose on the same page:

- **Property-level requirements.** `accountEnabled` needs
  `User.EnableDisableAccount.All` **+** `User.Read.All`, and `signInActivity` on `user` needs
  `AuditLog.Read.All`. Neither appears in the resource's permission table.
- **Provider-scoped tables.** `/roleManagement/*` pages carry one table per RBAC provider. Only the
  *directory (Microsoft Entra ID)* provider applies here; the entitlement-management table is a
  different API surface that happens to share the page.

### Deliberate deviations

These are documented least-privileged options that the module intentionally does **not** accept.
Each is a judgment call, not an oversight:

| Endpoint | Documented least privileged | Why it is not offered |
|---|---|---|
| `GET /groups` | `Group-NestingSupport.ReadWrite.All` | A **write** scope classified as least privileged for a read. Offering it in a read-only cmdlet would contradict the module's least-privilege story; `Group.Read.All` and `GroupMember.Read.All` are accepted instead. |
| `GET /users/{id}/transitiveMemberOf` | `User.Read` | Grants the signed-in user's *own* profile only. `Get-GkUserAccessReport` reads arbitrary users, so `User.Read` cannot serve it. |
| `GET /users/{id}/authentication/methods` | `UserAuthenticationMethod.Read` | The same trap without the `.All` suffix: it returns only the signed-in user's own methods. `Get-GkUserAuthMethod` reads arbitrary users, so only the `.All` variants are accepted. |
| `POST /users/{id}/authentication/temporaryAccessPassMethods` | `UserAuthMethod-TAP.Read`, `UserAuthMethod-TAP.Read.All` | Both are **read** permissions for a call that creates a credential. `New-GkTemporaryAccessPass` accepts only the `ReadWrite.All` variants. |
| `PATCH /users/{id}` (passwordProfile) | `User.ReadUpdate.All` | **Open question, resolved conservatively.** The endpoint's table lists `User.ReadUpdate.All`, but the same page names `User-PasswordProfile.ReadWrite.All` as the least privileged permission for the **passwordProfile** property specifically. The docs do not say whether the generic update permission also carries that property. Accepting it would risk a pre-flight pass followed by a 403 part-way through a bulk reset, which is the worse failure — so `Reset-GkUserPassword` leaves it out. Settle this with a live run against a test tenant and then relax or keep it deliberately. |
| `GET /roleManagement/directory/role{Assignment,Eligibility}ScheduleInstances` | `Role{Assignment,Eligibility}Schedule.Read.Directory` | These PIM reads are **optional** in `Get-GkAdminRoleAssignment` — it warns and continues when they fail. A caller holding only these scopes could not perform the cmdlet's required calls, so accepting them alone would trade a clear pre-flight error for a confusing partial result. |
| `POST /roleManagement/directory/role{Assignment,Eligibility}ScheduleRequests` | `Role{Assignment,Eligibility}Schedule.ReadWrite.Directory` | Same reasoning for `Remove-GkAdminRoleAssignment`: `RoleManagement.ReadWrite.Directory` covers every path it can take. |

### Correction: ReadWrite scopes now satisfy read capability groups

The original audit checked that each group offered Graph's documented *least-privileged* option. It
did not check the other direction — whether a caller holding a **broader** scope that subsumes the
read would be accepted. In Graph, `X.ReadWrite.All` grants everything `X.Read.All` grants, but 39 of
the map's capability groups listed only the `.Read.All` form. `Test-GkConnection` therefore rejected
connections that Graph itself accepts, which is exactly the "false missing-scope failure" the
capability-group design exists to prevent. It hit anyone who connected with write scopes for a
remediation workflow and then piped into a `Get-` cmdlet.

Verified empirically rather than from the documentation: an app-only token holding
`Group.ReadWrite.All` and `Application.ReadWrite.All` and **no** `.Read.All` or `Directory.Read.All`
successfully served `GET /groups` and `GET /applications`.

A first pass covered `X.Read.All` only, which missed `RoleManagement.Read.Directory` — precisely the
scope `Remove-GkAdminRoleAssignment` tells callers to connect with, so the role workflow still failed
the exact case this correction exists to fix. Four more groups gained
`RoleManagement.ReadWrite.Directory`. The remaining unpaired read scopes (`Policy.Read.All`,
`AuditLog.Read.All`, `ServiceHealth.Read.All`, `DeviceLocalCredential.Read.All`) have no `ReadWrite`
sibling in Graph, so those omissions are correct rather than oversights.

87 scopes were added across 40 of the map's 82 groups, each one confirmed to exist as a real permission by
querying the Microsoft Graph service principal's `appRoles` and `oauth2PermissionScopes` in a live
tenant. Ordering was preserved — the least-privileged option stays first, so `Get-GkConnectScopeHint`
and the `-ForCommand` connect line still request the narrow scope. Only what is *accepted* widened;
nothing the module *asks for* changed.

`tests/Unit/ScopeMap.Tests.ps1` was updated in the same change: the pinned declarations now include
the ReadWrite variants, and the "does not lead with a directory-wide scope" guard now exempts a group
in which *every* option is directory-wide (group lifecycle policies have no narrower permission)
rather than exempting single-element groups, which was a proxy for the same thing that stopped
holding once the groups grew.

### Re-running the audit

The scope table below is generated from `$script:GkScopeMap` and the extracted call inventory. It is
pinned by `tests/Unit/ScopeMap.Tests.ps1`, so an accidental edit fails the suite. When Microsoft
changes a permission, update the map, re-run the tests, and regenerate this table.

### The table

| Cmdlet | Graph calls | Capability groups (any one scope per group) |
|---|---|---|
| `Add-GkGroupMember` | `POST /groups/{id}/members/$ref` | **manage group membership**: `GroupMember.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Connect-GkGraph` | _(no direct Graph call)_ | _(none — validates the session only)_ |
| `Disable-GkStaleDevice` | `DELETE /devices/{id}`<br>`PATCH /devices/{id}` | **disable or delete a device**: `Directory.AccessAsUser.All`, `Device.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Disable-GkStaleUser` | `PATCH /users/{id}` | **block user sign-in (accountEnabled)**: `User.EnableDisableAccount.All`, `User.ReadUpdate.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All`<br>**read the target user**: `User.Read.All`, `User.ReadUpdate.All`, `User.ReadWrite.All`, `Directory.Read.All`, `Directory.ReadWrite.All` |
| `Export-GkTenantAssessment` | _(no direct Graph call)_ | _(none — validates the session only)_ |
| `Get-GkAdministrativeUnit` | `GET /directory/administrativeUnits/{id}/members`<br>`GET /directory/administrativeUnits` | **read administrative units**: `AdministrativeUnit.Read.All`, `Directory.Read.All` |
| `Get-GkAdminRoleAssignment` | `GET /roleManagement/directory/roleAssignments`<br>`GET /roleManagement/directory/roleAssignmentScheduleInstances`<br>`GET /roleManagement/directory/roleDefinitions`<br>`GET /roleManagement/directory/roleEligibilityScheduleInstances` | **read role assignments and PIM schedules**: `RoleManagement.Read.Directory`, `RoleManagement.Read.All`, `Directory.Read.All` |
| `Get-GkAppRegistrationReport` | `GET /applications`<br>`GET /servicePrincipals({id})` | **read app registrations**: `Application.Read.All`, `Directory.Read.All` |
| `Get-GkAuthMethodPolicy` | `GET /policies/authenticationMethodsPolicy` | **read the authentication methods policy**: `Policy.Read.AuthenticationMethod`, `Policy.Read.All` |
| `Get-GkAuthStrengthPolicy` | `GET /policies/authenticationStrengthPolicies` | **read authentication strength policies**: `Policy.Read.AuthenticationMethod`, `Policy.Read.All` |
| `Get-GkCaPolicyReport` | `GET /identity/conditionalAccess/policies` | **read Conditional Access policies**: `Policy.Read.All` |
| `Get-GkConditionalAccessTemplate` | `GET /identity/conditionalAccess/templates` | **read Conditional Access templates**: `Policy.Read.All` |
| `Get-GkConnectionInfo` | _(no direct Graph call)_ | _(none — validates the session only)_ |
| `Get-GkConsentRequest` | `GET /identityGovernance/appConsent/appConsentRequests` | **read admin-consent requests**: `ConsentRequest.Read.All` |
| `Get-GkCrossTenantAccess` | `GET /policies/crossTenantAccessPolicy/default`<br>`GET /policies/crossTenantAccessPolicy/partners` | **read cross-tenant access policy**: `Policy.Read.All` |
| `Get-GkCustomRole` | `GET /roleManagement/directory/roleDefinitions` | **read role definitions**: `RoleManagement.Read.Directory`, `Directory.Read.All` |
| `Get-GkDeletedItem` | `GET /directory/deletedItems/microsoft.graph.administrativeUnit`<br>`GET /directory/deletedItems/microsoft.graph.application`<br>`GET /directory/deletedItems/microsoft.graph.group`<br>`GET /directory/deletedItems/microsoft.graph.servicePrincipal`<br>`GET /directory/deletedItems/microsoft.graph.user` | **read deleted directory objects**: `User.Read.All`, `Group.Read.All`, `Application.Read.All`, `AdministrativeUnit.Read.All`, `Directory.Read.All` |
| `Get-GkDeletedItem:AdministrativeUnit` | `GET /directory/deletedItems/microsoft.graph.administrativeUnit`<br>`GET /directory/deletedItems/microsoft.graph.application`<br>`GET /directory/deletedItems/microsoft.graph.group`<br>`GET /directory/deletedItems/microsoft.graph.servicePrincipal`<br>`GET /directory/deletedItems/microsoft.graph.user` | **read deleted administrative units**: `AdministrativeUnit.Read.All`, `Directory.Read.All` |
| `Get-GkDeletedItem:Application` | `GET /directory/deletedItems/microsoft.graph.administrativeUnit`<br>`GET /directory/deletedItems/microsoft.graph.application`<br>`GET /directory/deletedItems/microsoft.graph.group`<br>`GET /directory/deletedItems/microsoft.graph.servicePrincipal`<br>`GET /directory/deletedItems/microsoft.graph.user` | **read deleted applications**: `Application.Read.All`, `Directory.Read.All` |
| `Get-GkDeletedItem:Group` | `GET /directory/deletedItems/microsoft.graph.administrativeUnit`<br>`GET /directory/deletedItems/microsoft.graph.application`<br>`GET /directory/deletedItems/microsoft.graph.group`<br>`GET /directory/deletedItems/microsoft.graph.servicePrincipal`<br>`GET /directory/deletedItems/microsoft.graph.user` | **read deleted groups**: `Group.Read.All`, `Directory.Read.All` |
| `Get-GkDeletedItem:ServicePrincipal` | `GET /directory/deletedItems/microsoft.graph.administrativeUnit`<br>`GET /directory/deletedItems/microsoft.graph.application`<br>`GET /directory/deletedItems/microsoft.graph.group`<br>`GET /directory/deletedItems/microsoft.graph.servicePrincipal`<br>`GET /directory/deletedItems/microsoft.graph.user` | **read deleted service principals**: `Application.Read.All`, `Directory.Read.All` |
| `Get-GkDeletedItem:User` | `GET /directory/deletedItems/microsoft.graph.administrativeUnit`<br>`GET /directory/deletedItems/microsoft.graph.application`<br>`GET /directory/deletedItems/microsoft.graph.group`<br>`GET /directory/deletedItems/microsoft.graph.servicePrincipal`<br>`GET /directory/deletedItems/microsoft.graph.user` | **read deleted users**: `User.Read.All`, `Directory.Read.All` |
| `Get-GkDeviceInventory` | `GET /devices` | **read devices**: `Device.Read.All`, `Directory.Read.All` |
| `Get-GkDirectoryAudit` | `GET /auditLogs/directoryAudits` | **read directory audit logs**: `AuditLog.Read.All` |
| `Get-GkDomain` | `GET /domains` | **read domains**: `Domain.Read.All`, `Directory.Read.All` |
| `Get-GkExternalCollaborationSetting` | `GET /policies/authorizationPolicy` | **read the authorization policy**: `Policy.Read.All` |
| `Get-GkGroupBasedLicense` | `GET /groups`<br>`GET /subscribedSkus` | **read groups and their assigned licenses**: `Group.Read.All`, `Directory.Read.All`, `GroupMember.Read.All` |
| `Get-GkGroupBasedLicense:ResolveSkuName` | `GET /groups`<br>`GET /subscribedSkus` | **read groups and their assigned licenses**: `Group.Read.All`, `Directory.Read.All`, `GroupMember.Read.All`<br>**resolve SKU names from subscribedSkus**: `LicenseAssignment.Read.All`, `Organization.Read.All`, `Directory.Read.All` |
| `Get-GkGroupExpirationPolicy` | `GET /groupLifecyclePolicies` | **read group lifecycle policies**: `Directory.Read.All` |
| `Get-GkGroupMember` | `GET /groups/{id}/members` | **read group members**: `GroupMember.Read.All`, `Group.Read.All`, `Directory.Read.All` |
| `Get-GkGroupReport` | `GET /groups/{id}/members`<br>`GET /groups` | **read groups**: `Group.Read.All`, `Directory.Read.All`, `GroupMember.Read.All`<br>**read group members and owners**: `GroupMember.Read.All`, `Group.Read.All`, `Directory.Read.All` |
| `Get-GkGuestInventory` | `GET /users/{id}/sponsors`<br>`GET /users` | **read guest users and sponsors**: `User.Read.All`, `Directory.Read.All` |
| `Get-GkInactiveApp` | `GET /reports/servicePrincipalSignInActivities`<br>`GET /servicePrincipals` | **read service principal sign-in activity**: `AuditLog.Read.All`<br>**read service principals**: `Application.Read.All`, `Directory.Read.All` |
| `Get-GkLapsPassword` | `GET /directory/deviceLocalCredentials/{id}`<br>`GET /directory/deviceLocalCredentials` | **list devices with LAPS credentials**: `DeviceLocalCredential.ReadBasic.All`, `DeviceLocalCredential.Read.All` |
| `Get-GkLapsPassword:Password` | `GET /directory/deviceLocalCredentials/{id}`<br>`GET /directory/deviceLocalCredentials` | **retrieve a LAPS password**: `DeviceLocalCredential.Read.All` |
| `Get-GkLegacyAuthSignIn` | `GET /auditLogs/signIns` | **read sign-in logs**: `AuditLog.Read.All` |
| `Get-GkLicenseAssignmentError` | `GET /subscribedSkus`<br>`GET /users` | **read users**: `User.Read.All`, `Directory.Read.All`<br>**read subscribed SKUs**: `Organization.Read.All`, `LicenseAssignment.Read.All`, `Directory.Read.All` |
| `Get-GkLicenseOverview` | `GET /subscribedSkus`<br>`GET /users` | **read subscribed SKUs**: `Organization.Read.All`, `LicenseAssignment.Read.All`, `Directory.Read.All`<br>**enumerate users per SKU**: `User.Read.All`, `Directory.Read.All` |
| `Get-GkNamedLocation` | `GET /identity/conditionalAccess/namedLocations` | **read named locations**: `Policy.Read.All` |
| `Get-GkPrivilegedRoleMember` | _(no direct Graph call)_ | **read role assignments**: `RoleManagement.Read.All`, `RoleManagement.Read.Directory` |
| `Get-GkRiskDetection` | `GET /identityProtection/riskDetections` | **read risk detections**: `IdentityRiskEvent.Read.All` |
| `Get-GkRiskyUser` | `GET /identityProtection/riskyUsers` | **read risky users**: `IdentityRiskyUser.Read.All` |
| `Get-GkRoleAssignableGroup` | `GET /groups/{id}/owners`<br>`GET /groups` | **read groups and owners**: `GroupMember.Read.All`, `Group.Read.All`, `Directory.Read.All` |
| `Get-GkRoleDefinition` | `GET /roleManagement/directory/roleDefinitions` | **read role definitions**: `RoleManagement.Read.Directory`, `Directory.Read.All` |
| `Get-GkSecureScore` | `GET /security/secureScores` | **read Secure Score**: `SecurityEvents.Read.All` |
| `Get-GkServiceHealth` | `GET /admin/serviceAnnouncement/healthOverviews`<br>`GET /admin/serviceAnnouncement/issues` | **read service health**: `ServiceHealth.Read.All` |
| `Get-GkServiceMessage` | `GET /admin/serviceAnnouncement/messages` | **read message center posts**: `ServiceMessage.Read.All` |
| `Get-GkServicePrincipalReport` | `GET /oauth2PermissionGrants`<br>`GET /servicePrincipals` | **read service principals (and consent grants)**: `Application.Read.All`, `Directory.Read.All` |
| `Get-GkSignInReport` | `GET /auditLogs/signIns` | **read sign-in logs**: `AuditLog.Read.All` |
| `Get-GkStaleAppCredential` | `GET /reports/appCredentialSignInActivities`<br>`GET /servicePrincipals` | **read app credential sign-in activity**: `AuditLog.Read.All`<br>**read service principals**: `Application.Read.All`, `Directory.Read.All` |
| `Get-GkStaleUser` | `GET /users` | **read user objects**: `User.Read.All`, `Directory.Read.All`<br>**read signInActivity**: `AuditLog.Read.All` |
| `Get-GkSubscription` | `GET /directory/subscriptions` | **read directory subscriptions**: `Organization.Read.All`, `Directory.Read.All` |
| `Get-GkTenantInfo` | `GET /organization` | **read organization info**: `Organization.Read.All`, `Directory.Read.All` |
| `Get-GkUserAccessReport` _(delegated-only)_ | `GET /users/{id}/appRoleAssignments`<br>`GET /users/{id}/licenseDetails`<br>`GET /users/{id}/transitiveMemberOf`<br>`GET /users/{id}` | **read group and role memberships**: `User.Read.All`, `GroupMember.Read.All`, `Directory.Read.All`<br>**read app role assignments**: `Directory.Read.All`, `AppRoleAssignment.ReadWrite.All`<br>**read license details**: `LicenseAssignment.Read.All`, `User.Read.All`, `Directory.Read.All` |
| `Get-GkUserAuthMethod` | `GET /users/{id}/authentication/methods` | **read a user's authentication methods**: `UserAuthenticationMethod.Read.All`, `UserAuthenticationMethod.ReadWrite.All` |
| `Get-GkUserMfaStatus` | `GET /reports/authenticationMethods/userRegistrationDetails` | **read authentication method registration report**: `AuditLog.Read.All` |
| `New-GkGuestInvitation` | `POST /invitations` | **invite guests**: `User.Invite.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All` |
| `New-GkTemporaryAccessPass` | `POST /users/{id}/authentication/temporaryAccessPassMethods` | **issue a Temporary Access Pass**: `UserAuthMethod-TAP.ReadWrite.All`, `UserAuthenticationMethod.ReadWrite.All` |
| `Remove-GkAdminRoleAssignment` | `DELETE /roleManagement/directory/roleAssignments/{id}`<br>`POST /roleManagement/directory/roleAssignmentScheduleRequests`<br>`POST /roleManagement/directory/roleEligibilityScheduleRequests` | **remove role assignments (active and PIM)**: `RoleManagement.ReadWrite.Directory` |
| `Remove-GkConsentGrant` | `DELETE /oauth2PermissionGrants/{id}` | **revoke delegated consent grants**: `DelegatedPermissionGrant.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Remove-GkGroupMember` | `DELETE /groups/{id}/members/{id}/$ref` | **manage group membership**: `GroupMember.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Remove-GkStaleGuest` | `DELETE /users/{id}`<br>`GET /users/{id}`<br>`PATCH /users/{id}` | **disable a guest (accountEnabled)**: `User.EnableDisableAccount.All`, `User.ReadUpdate.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All`<br>**read the target user (guest-type check)**: `User.Read.All`, `User.ReadUpdate.All`, `User.ReadWrite.All`, `Directory.Read.All`, `Directory.ReadWrite.All` |
| `Remove-GkStaleGuest:Delete` | `DELETE /users/{id}`<br>`GET /users/{id}`<br>`PATCH /users/{id}` | **delete a user (30-day soft-delete)**: `User.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Remove-GkUserLicense` | `POST /users/{id}/assignLicense` | **remove license assignments**: `LicenseAssignment.ReadWrite.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Reset-GkAppCredential` | `POST /applications/{id}/addPassword`<br>`POST /applications/{id}/removePassword` | **manage application secrets**: `Application.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Reset-GkUserPassword` | `PATCH /users/{id}` | **reset a user's password**: `User-PasswordProfile.ReadWrite.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Restore-GkDeletedObject` | `POST /directory/deletedItems/{id}/restore` | **restore a deleted directory object**: `User.DeleteRestore.All`, `Group.ReadWrite.All`, `Application.ReadWrite.All`, `AdministrativeUnit.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Restore-GkDeletedObject:AdministrativeUnit` | `POST /directory/deletedItems/{id}/restore` | **restore a deleted administrative unit**: `AdministrativeUnit.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Restore-GkDeletedObject:Application` | `POST /directory/deletedItems/{id}/restore` | **restore a deleted application**: `Application.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Restore-GkDeletedObject:Group` | `POST /directory/deletedItems/{id}/restore` | **restore a deleted group**: `Group.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Restore-GkDeletedObject:ServicePrincipal` | `POST /directory/deletedItems/{id}/restore` | **restore a deleted service principal**: `Application.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Restore-GkDeletedObject:User` | `POST /directory/deletedItems/{id}/restore` | **restore a deleted user**: `User.DeleteRestore.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Revoke-GkUserSession` | `POST /users/{id}/revokeSignInSessions` | **revoke sign-in sessions**: `User.RevokeSessions.All`, `User.ReadWrite.All`, `Directory.ReadWrite.All` |
| `Set-GkGroupOwner` | `POST /groups/{id}/owners/$ref` | **add a group owner**: `Group.ReadWrite.All`, `Directory.ReadWrite.All` |
