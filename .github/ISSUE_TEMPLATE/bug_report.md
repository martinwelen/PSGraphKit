---
name: Bug report
about: Report a problem with a cmdlet
title: "[Bug] "
labels: bug
---

**Cmdlet**
Which cmdlet is affected (e.g. `Get-GkStaleUser`).

**What happened**
A clear description of the problem, including the exact error message if any.

**Repro**
The command you ran (redact tenant data):

```powershell
# ...
```

**Expected**
What you expected instead.

**Environment**
- PSGraphKit version: `(Get-Module PSGraphKit).Version`
- PowerShell version: `$PSVersionTable.PSVersion`
- Microsoft.Graph.Authentication version
- Auth type: delegated / app-only

**Additional context**
Anything else — a `request-id` from the error is very helpful.
