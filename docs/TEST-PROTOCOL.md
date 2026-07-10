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

## Write cmdlets

Write cmdlets (`Disable-*`, `Remove-*`, `Set-*`, `Add-*`, `New-*`, `Revoke-*`, `Reset-*`) mutate state
and take mandatory targets, and `-WhatIf` short-circuits before a result object is produced — so they
are **not** part of the live protocol. Validate them by:

1. Unit tests (all mock the seam and assert on the returned result object + the `ShouldProcess` call).
2. A manual pass against **disposable** objects (a throwaway user/group/app) in a test tenant: run once
   with `-WhatIf`, then for real, and confirm the returned `PSGraphKit.*Result` object is fully
   populated and the change actually happened.

---

## Release gate checklist

Before tagging `vX.Y.Z`:

- [ ] `Invoke-Pester -Path tests/Unit` — 0 failures.
- [ ] Fidelity check reviewed — every single-item consumer's test mocks the seam.
- [ ] `./build/Invoke-GkTestProtocol.ps1` against a real tenant — no `FAIL` / `HOLLOW` / `KEYFIELD` /
      `BADTYPE`; `EMPTY`/`WARN` understood.
- [ ] `Test-ModuleManifest ./src/PSGraphKit/PSGraphKit.psd1` version bumped and matches the tag.
- [ ] `CHANGELOG.md` updated.
