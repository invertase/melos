# Fix: Dart SDK mismatch (3.6.0 vs 3.8.0)

When using Melos with Dart, the SDK mismatch (`3.6.0` vs `3.8.0`) causes confusion and blocks some users. This PR provides a minimal fix and a test to verify it.

## Solution
This patch provides:
- ✅ Patch (`patch.diff`)
- ✅ Minimal test reproducer (`test/reproducer.mjs`, `test/dummy.mjs`, `test/expected_output.txt`)
- ✅ Rollback instructions (`rollback.md`)
- ✅ Legal disclaimer (`DISCLAIMER.md`)
- ✅ Invoice (`invoice.txt`) for traceability

## Reproducer (proof)
Run:
```bash
node test/reproducer.mjs
```

Expected output is stored in `test/expected_output.txt`.
