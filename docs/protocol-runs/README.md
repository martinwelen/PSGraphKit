# Protocol runs

Committed evidence for the release gate in [TEST-PROTOCOL.md](../TEST-PROTOCOL.md).

`build/Invoke-GkWriteProtocol.ps1` writes a timestamped report here on every run. A release that
touches a write cmdlet should reference the run that validated it — the point is that "we tested the
writes" is a checkable claim rather than a memory.

Reports record the tenant id, the account, the module version, and every assertion that ran. They
contain no secrets: the protocol asserts *that* a password or passcode came back, never its value.

## What is kept

Every run writes a report, but most are working artefacts: the same suite passing again, or a single
scenario re-run while chasing a flake. Committing all of them buries the two kinds that are worth
keeping, so only these stay:

- **The run that gated a release.** One per released version, referenced by that release.
- **Any run that found something.** A failing run is the evidence that the protocol earns its
  keep — deleting it leaves only the record of things going well, which is the least informative
  half of the story.

Everything else is deleted when the work that produced it is finished. Reports are not a log; they
are the answer to "what did you actually verify, and when".

| Report | Why it is here |
|---|---|
| `write-protocol-20260910-113426.md` | The protocol's first ever run. 1 PASS, 6 FAIL — it found two real bugs in cmdlets that 437 unit tests called healthy, and its failures also exposed that the protocol itself verified state by reading once after a sleep. |
| `write-protocol-20260910-153648.md` | The release gate for v0.4.2. 11 PASS, 4 SKIPPED, 0 FAIL across all 15 write cmdlets. The four skips are tenant limitations, not passes — see TEST-PROTOCOL.md. |
