# Protocol runs

Committed evidence for the release gate in [TEST-PROTOCOL.md](../TEST-PROTOCOL.md).

`build/Invoke-GkWriteProtocol.ps1` writes a timestamped report here on every run. A release that
touches a write cmdlet should reference the run that validated it — the point is that "we tested the
writes" is a checkable claim rather than a memory.

Reports record the tenant id, the account, the module version, and every assertion that ran. They
contain no secrets: the protocol asserts *that* a password or passcode came back, never its value.
