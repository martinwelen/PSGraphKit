# Security Policy

## Reporting a vulnerability

If you discover a security issue in PSGraphKit, please report it privately rather than opening a
public issue. Use GitHub's **Report a vulnerability** (Security → Advisories) on the repository, or
email the maintainer.

Please include:

- A description of the issue and its impact.
- Steps to reproduce, or a proof of concept.
- The module version (`(Get-Module PSGraphKit).Version`) and PowerShell version.

You will receive an acknowledgement, and a fix or mitigation will be prioritized.

## Scope and handling notes

- PSGraphKit performs Microsoft Graph operations under the caller's own delegated or app-only
  credentials. It never stores or transmits credentials; authentication is handled by
  `Microsoft.Graph.Authentication`.
- Write cmdlets are `SupportsShouldProcess` and default to the least destructive action. Report
  any case where a cmdlet performs a state change without honoring `-WhatIf`/`-Confirm`.
- Output such as `Export-GkTenantAssessment` and the sign-in/audit reports may contain sensitive
  tenant data. Handle generated files accordingly; the repository ignores the local test folder
  to keep tenant data out of source control.
