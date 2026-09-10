# Milestones

A short log of the moments worth remembering.

## 🚀 Went public — 3 July 2026

**Friday, 3 July 2026 · 16:02 UTC (18:02 CEST)**

PSGraphKit went public at **v0.3.0** — **50 cmdlets** spanning read-only reporting,
write/remediation, and a one-file tenant assessment export, over a single dependency
(`Microsoft.Graph.Authentication`). 243 tests, green CI on Windows/Linux/macOS, every endpoint
and scope verified against Microsoft Learn and validated end-to-end against a live tenant.

From an empty folder to a published, branded, professional module.

## Release history

| Date | Tag | Milestone |
|---|---|---|
| 3 Jul 2026 | v0.1.0 | Phase 1 — 12 read-only reporting cmdlets |
| 3 Jul 2026 | v0.2.0 | Phases 2–4 — writes, broader reports, HTML assessment (29 cmdlets) |
| 3 Jul 2026 | v0.3.0 | 20 more across five security/governance themes — **50 cmdlets**; repo made public |
| 3 Jul 2026 | v0.3.1 | Release kit + brand package; **first PowerShell Gallery release** |
| 4 Aug 2026 | v0.4.0 | Seven read-only cmdlets (Phase 6) — 57 cmdlets |
| 9 Aug 2026 | v0.4.1 | Four write / sensitive-read cmdlets (Phase 7) — **61 cmdlets** |
| 10 Sep 2026 | v0.4.2 | **First signed release**, and the first validated against a live tenant |

## 🔏 First signed release — 10 September 2026

v0.4.2 is the first version published with a publicly trusted Authenticode signature, through Azure
Artifact Signing, with an RFC 3161 countersignature and a signed file catalog covering the module.

It is also the first release the live write protocol actually ran against. That run found two bugs
invisible to 437 passing unit tests, because both concerned what Graph does rather than what request
the module builds: `Get-GkDeletedItem` never reported a restore window and its two date filters
returned nothing in any tenant, and 39 capability groups in the scope map rejected callers holding a
`ReadWrite` scope that Graph itself accepts for reading.

The protocol needed more repair than the module did. Directory reads are eventually consistent —
reading one freshly written property four times returned `False, False, True, False` — so verifying
by sleeping and reading once failed runs that were correct, and moved the failure between scenarios
from run to run. Coverage went from 8 of 15 write cmdlets to all 15.
