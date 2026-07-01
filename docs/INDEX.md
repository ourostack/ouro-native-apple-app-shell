# Ouro Native Apple App Shell Docs Index

Use this index to start with current shell ownership docs before reading
consumer-specific task artifacts.

## Normative Docs

- [README](../README.md): package products, validation commands, downstream
  consumer checks, shell doctor, and scaffold workflow.
- [Shell Boundary](shell-boundary.md): ownership contract for reusable native
  Ouro app chrome, consumer adapters, allowlists, and CI enforcement.
- [Privacy And Diagnostics Contract](privacy-diagnostics-contract.md): descriptor
  shape for telemetry consent, privacy docs, support bundles, and redaction
  promises.

## Third-app adoption quick start

1. Generate the reference fixture:

   ```bash
   scripts/scaffold-consumer-adoption.sh --output /tmp/ouro-shell-fixture \
     --package-name ExampleConsumer \
     --module-name ExampleApp \
     --app-name Example \
     --bundle-id com.ouro.example \
     --repository ourostack/example \
     --force
   ```

2. Inspect `Sources/ExampleApp/ExampleAppShellContract.swift`,
   `Tests/ExampleAppTests/ExampleAppShellContractTests.swift`,
   `scripts/preflight.sh`, and `config/ouro-app-control-deck.json`.
3. Move that shape into the real app's shell adapter and CI without adding
   product-specific UI to this shell package.
4. Validate the consumer with `scripts/shell-doctor.sh --repo /path/to/app`
   from this repo.

## Executable Validation References

- `scripts/check-shell-boundary.sh`: shared boundary scanner.
- `scripts/shell-doctor.sh`: downstream adoption checklist.
- `scripts/scaffold-consumer-adoption.sh`: reference consumer scaffold.
- `scripts/validate-adoption-docs.py`: cold-start adoption docs validator.
- `scripts/check-downstream-consumers.sh`: pinned downstream compatibility
  smoke for Ouro MD and Ouro Workbench.
- `scripts/ui-surface-probe.sh`: offscreen shell UI rendering probe.

## Historical And Task Artifacts

This repo keeps most planning history in PRs and downstream task docs rather
than a broad in-tree docs backlog. Treat consumer-specific planning bundles in
Ouro MD or Workbench as provenance unless a current shell task cites them.
