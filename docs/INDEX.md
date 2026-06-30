# Ouro Native Apple App Shell Docs Index

Use this index to start with current shell ownership docs before reading
consumer-specific task artifacts.

## Normative Docs

- [README](../README.md): package products, validation commands, downstream
  consumer checks, shell doctor, and scaffold workflow.
- [Shell Boundary](shell-boundary.md): ownership contract for reusable native
  Ouro app chrome, consumer adapters, allowlists, and CI enforcement.

## Executable Validation References

- `scripts/check-shell-boundary.sh`: shared boundary scanner.
- `scripts/shell-doctor.sh`: downstream adoption checklist.
- `scripts/scaffold-consumer-adoption.sh`: reference consumer scaffold.
- `scripts/check-downstream-consumers.sh`: pinned downstream compatibility
  smoke for Ouro MD and Ouro Workbench.
- `scripts/ui-surface-probe.sh`: offscreen shell UI rendering probe.

## Historical And Task Artifacts

This repo keeps most planning history in PRs and downstream task docs rather
than a broad in-tree docs backlog. Treat consumer-specific planning bundles in
Ouro MD or Workbench as provenance unless a current shell task cites them.
