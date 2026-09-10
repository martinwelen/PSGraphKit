# PSGraphKit test protocol

How to validate the cmdlets before a release so that the class of bug fixed in **0.3.2** cannot ship
again.

## The bug this protocol exists to catch

In 0.3.1, `Get-GkSecureScore` and `Get-GkTenantInfo` returned a **correctly-typed object with every
field null/blank** (numbers left at `0`). The cause was a result-consumption mistake, not a Graph or
scope problem: both took the first item of a collection with `@(Invoke-GkGraphRequest ...) |
Select-Object -First 1`, but `Invoke-GkGraphRequest` returns a page as a *single non-unrolled array
object*, so that expression handed back the whole array and every `Get-GkDictValue` resolved to
`$null`. (See the code comments at the fixed call sites, and the changelog for 0.3.2.)

Why it slipped through:

- **The unit tests mocked `Invoke-GkGraphRequest` itself with a plain array**, which does *not*
  reproduce the real non-unrolling return contract — so the mock made the buggy consumer look fine.
- **The live smoke test only checked row counts.** A hollow one-row result reads as `OK, 1 row`.

The protocol closes both gaps with three layers.

---

## Layer 1 — Unit tests that mock the real seam

`Invoke-GkGraphRequest` (pagination, throttling, the `, $items.ToArray()` return contract) is itself
the thing most likely to be consumed incorrectly. So a cmdlet's unit test should exercise the **real**
`Invoke-GkGraphRequest` and mock only the low-level HTTP seam beneath it, `Invoke-GkRawGraphCall`.

Reference pattern (see `tests/Unit/Get-GkSecureScore.Tests.ps1` and `Get-GkTenantInfo.Tests.ps1`):

```powershell
Mock Invoke-GkRawGraphCall {
    [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @{
        value             = @(@{ <#... realistic item ...#> })
        '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/...&$skiptoken=x'   # exercise paging
    } }
}
```

Then assert on **field values**, not just object counts (`$r.CurrentScore | Should -Be 42`, etc.).
With the seam mocked, the genuine comma-return + pagination runs, so a consumer that grabs the whole
array instead of the first item makes the test go red — as proven by temporarily reverting the fix.

### Fidelity check

Any cmdlet that selects a **single / first** item from a collection must mock the seam (or otherwise
reproduce the non-unrolling contract). A plain-array `Mock Invoke-GkGraphRequest` is safe only for
cmdlets that consume the result with `foreach`. To list tests that mock the shallow seam and review
whether each is one of the single-item consumers:

```powershell
Get-ChildItem tests/Unit -Filter *.Tests.ps1 |
    Select-String -Pattern 'Mock\s+Invoke-GkGraphRequest' |
    Select-Object -ExpandProperty Path -Unique
```

---

## Layer 2 — Run the whole unit suite

```powershell
Invoke-Pester -Path tests/Unit -Output Detailed
```

Gate: **0 failures.** (Currently 244 tests.)

---

## Layer 3 — Live shape validation

`build/Invoke-GkTestProtocol.ps1` runs every read (`Get-*`) cmdlet against a real tenant and validates
the **shape** of what each returns, not just that the call succeeded. It is READ-ONLY and safe against
any tenant you can read.

Graph auth is interactive and per-process, so run it in **your own terminal**:

```powershell
Connect-GkGraph -AllCommands        # interactive sign-in, full read-only scope set
./build/Invoke-GkTestProtocol.ps1
# or: ./build/Invoke-GkTestProtocol.ps1 -Login
```

### What it checks, per returned row

| Check   | Fails when | Catches |
|---------|-----------|---------|
| Type    | a row is not the declared `PSGraphKit.*` type | a raw Graph array/hashtable leaking to output |
| Content | a row has no populated text/date/object field (numbers/booleans don't count) | the 0.3.1 all-fields-null signature |
| Keys    | a declared `KeyFields` field is null/blank on any row | precise, tenant-agnostic hollowness |

### Status legend

| Status | Meaning | Action |
|--------|---------|--------|
| `OK` | rows returned and every check passed | none |
| `WARN` | passed, but the cmdlet emitted a warning (e.g. no P1/P2, no PIM) | usually expected; glance |
| `EMPTY` | zero rows — **shape could not be validated** (tenant had no data) | coverage gap; Layer 1 covers it |
| `HOLLOW` | rows returned but a row has no populated text/date field | **bug** — investigate before shipping |
| `KEYFIELD` | a required key field is empty | **bug** — investigate before shipping |
| `BADTYPE` | a row is the wrong (non-`PSGraphKit`) type | **bug** — investigate before shipping |
| `FAIL` | the cmdlet threw | investigate |

`FAIL` / `HOLLOW` / `KEYFIELD` / `BADTYPE` are hard problems; the run prints them again under a
`PROBLEMS` heading at the end.

### Extending the checks

The `Content` check is a heuristic that works without per-cmdlet knowledge. The `KeyFields` check is
precise but must be curated. As each cmdlet's output schema is confirmed, add its identity fields to
that cmdlet's `Key = @(...)` entry in `$specs` (e.g. `Get-GkTenantInfo` → `TenantId`, `DisplayName`).
More key fields = tighter validation and fewer relies on the heuristic.

### Coverage note

Shape is only validated for cmdlets that return data in the test tenant; anything reported `EMPTY`
(commonly `Get-GkRiskyUser`, `Get-GkRiskDetection`, `Get-GkConsentRequest` without the right
licensing/data) is not shape-checked here — Layer 1's seam-level tests carry those cases. Run the
protocol against the richest tenant you have access to for the widest live coverage.

---

## Layer 4 — Live write validation

`build/Invoke-GkWriteProtocol.ps1`

Unit tests mock the HTTP seam, so they prove the module builds the right request. They cannot prove
Graph *accepts* it, and they cannot see tenant preconditions — Temporary Access Pass enabled in the
authentication methods policy, Windows LAPS deployed, the signed-in admin's role outranking the
target. Those only fail in a real tenant.

```powershell
Connect-GkGraph -ForCommand Reset-GkUserPassword, New-GkTemporaryAccessPass, Restore-GkDeletedObject
./build/Invoke-GkWriteProtocol.ps1
```

### The shape of every scenario

1. Create a disposable object named `<Prefix>-<runstamp>-...`.
2. Run the cmdlet with `-WhatIf` and assert **nothing changed**.
3. Run it for real.
4. **Verify server state, not the return code** — read the object back through
   `Invoke-MgGraphRequest`, deliberately bypassing the module, and check the property actually
   moved. A 2xx that changed nothing is exactly what this catches.
5. Tear down in a `finally`, so a mid-run failure still cleans up.

### Safety

It resets passwords, issues MFA-satisfying credentials, and deletes objects. **Dev tenant only.**

Every write is guarded: `Assert-GkDisposable` refuses to touch an object whose name does not carry
the run prefix, so a scenario that loses track of what it created fails loudly instead of acting on
a real object. `-CleanOrphans` sweeps anything left behind by a run that died before its teardown.

### Scenarios

| Scenario | What it proves |
|---|---|
| `ResetPassword` | `lastPasswordChangeDateTime` advanced on the server |
| `TemporaryAccess` | the pass is registered on the account, and a **second** concurrent pass is rejected |
| `DeleteRestore` | full round trip: delete → appears in `Get-GkDeletedItem` → restore → live again |
| `DisableUser` | `accountEnabled` is `false` on the server |
| `GroupMembership` | the member is added, resolves as `User`, and is removed again |
| `GroupOwner` | the right principal owns the group |
| `AppCredential` | the secret exists on the application, then does not |
| `RevokeSession` | `signInSessionsValidFromDateTime` advanced — the only externally visible trace of a revocation |
| `UserLicense` | a staged licence is assigned, then gone from `assignedLicenses` |
| `GuestInvitation` | the invited object exists and is `userType = Guest` |
| `StaleGuest` | the guest is disabled, then soft-deleted into the recycle bin (both scope variants) |
| `StaleDevice` | `accountEnabled` is `false` on the device |
| `AdminRole` | a staged Directory Readers assignment is removed and no longer retrievable |
| `ConsentGrant` | a staged `oauth2PermissionGrant` is revoked and no longer retrievable |
| `LapsRead` | the password decodes; **`SKIPPED` without `-LapsDeviceId`**, never a pass on no evidence |

All 15 write cmdlets are covered. Four scenarios report `SKIPPED` in a Microsoft 365 developer
sandbox, and the reason is the tenant rather than the code: `GuestInvitation` and `StaleGuest`
because such tenants refuse B2B outright (*"Guest invitations not allowed for your company"*, with
`allowInvitesFrom` already set to `everyone`), `StaleDevice` because Graph will not accept a
synthetic device object and a real Entra-joined device cannot be staged from an API, and `LapsRead`
because a LAPS credential only exists once a real device has backed one up. A `SKIPPED` scenario
proves nothing — treat it as untested, not as passed.

### Reading a result honestly

The runner reports `SKIPPED` only when **every** check in a scenario is a skip. A scenario that
records a real assertion and *then* discovers the tenant cannot stage it would report `PASS` while
proving nothing, so a scenario that bails out mid-way clears its collected checks first. If you add
a scenario, do the same.

### Eventual consistency

Directory reads are eventually consistent. Reading one freshly written property four times in a row
returned `False, False, True, False`. Nothing in this protocol may verify by sleeping and reading
once — that fails runs that are correct, and the failure moves between scenarios from run to run,
which is far worse than failing outright. The rules:

- **A write happened** → `Wait-GkUntil`: poll until the expected state appears. The value we wrote is
  the one that eventually wins, so the first replica to report it is proof enough.
- **A write did NOT happen** (`-WhatIf`) → watch for the *written* state and require that it never
  appears, or wait for the untouched object to still be there. Never assert "the old value is still
  present on every read": a transient read miss says nothing about whether we wrote.
- **Several assertions about one object** → `Wait-GkFor`, and inspect the snapshot that satisfied the
  wait. A fresh read per assertion can land on a different replica and contradict the one before it.
- **Counting a collection** → `Get-GkRawCollectionCount`, never `@(Get-GkRawProperty ...).Count`.
  `@($null).Count` is `1` in PowerShell, so a failed read otherwise counts as one element.

### The scope matrix

This is the part that validates the scope map against Graph rather than against the documentation.

```powershell
./build/Invoke-GkWriteProtocol.ps1 -ScopePlan
```

prints the least-privilege connect line per scenario. Connect with exactly that, then run
`-Only <scenario>`. Green means the declared scope is sufficient. A 403 means the map is too strict
or too permissive, and you now know which.

Graph's interactive auth replaces the whole session on each connect, so this cannot be swept
automatically in one process — it is a deliberate pass, worked through one scenario at a time.

The open question in DESIGN.md section 7 — whether `User.ReadUpdate.All` carries the
`passwordProfile` property — is settled by connecting with only that scope and running
`-Only ResetPassword`.

---

## Release gate checklist

Before tagging `vX.Y.Z`:

- [ ] `Invoke-Pester -Path tests/Unit` — 0 failures.
- [ ] Fidelity check reviewed — every single-item consumer's test mocks the seam.
- [ ] `./build/Invoke-GkTestProtocol.ps1` against a real tenant — no `FAIL` / `HOLLOW` / `KEYFIELD` /
      `BADTYPE`; `EMPTY`/`WARN` understood.
- [ ] **When the release touches a write cmdlet:** `./build/Invoke-GkWriteProtocol.ps1` against the
      dev tenant — no `FAIL`; every `SKIPPED` understood. Commit the run report from
      `docs/protocol-runs/` so the release names the evidence behind it.
- [ ] `Test-ModuleManifest ./src/PSGraphKit/PSGraphKit.psd1` version bumped and matches the tag.
- [ ] `CHANGELOG.md` updated.
- [ ] **Signing is on.** The repository variable `SIGNING_ENABLED` is `true`. Once any version ships
      signed, every later version must be signed by the same publisher or PowerShellGet's publisher
      check makes it fail to install over the previous one without `-SkipPublisherCheck`. Publishing
      unsigned after that point breaks upgrades for existing users; the workflow emits a warning
      rather than failing, because the very first signed release has to come from somewhere.
- [ ] The GitHub Release is created from the CHANGELOG section — a tag alone is not a release.

### Code signing

Release artefacts are Authenticode-signed through Azure Artifact Signing, in `publish.yml`. Two
things about the arrangement are easy to get wrong:

**Order.** Signing covers file content byte for byte. Every step that modifies anything under
`src/PSGraphKit` — the version stamp, the README/LICENSE/CHANGELOG copy — must run *before* signing,
or the module ships looking signed and fails verification on the installing machine. The catalog is
built after the script files are signed, because it records their post-signature hashes.

**Timestamping.** Artifact Signing certificates are valid for 72 hours and are renewed daily. Without
an RFC 3161 countersignature from `http://timestamp.acs.microsoft.com`, every signature we publish
expires within three days. The verify step fails the release if any file is signed but not
timestamped, and verification runs *before* publishing — a Gallery version cannot be replaced, and a
module that installs but fails signature validation is worse than an unsigned one.

Configuration lives in repository variables (`ARTIFACT_SIGNING_ENDPOINT`, `ARTIFACT_SIGNING_ACCOUNT`,
`ARTIFACT_SIGNING_PROFILE`, `SIGNING_ENABLED`) and secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`). Authentication is OIDC workload identity federation, so no client secret is
stored. The signing identity needs the **Artifact Signing Certificate Profile Signer** role.

### Why this is not in CI

The write protocol needs a real tenant and interactive delegated auth, neither of which exists in a
GitHub Actions runner. So the gate is *"the release commit references an approved protocol run"*,
not an automatic check. That is weaker than a true gate — and stated plainly here rather than
implied — but it replaces an undocumented manual pass with a repeatable, reviewable artefact.
