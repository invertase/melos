# Rollback Instructions

If this patch introduces regressions or incompatibilities:

1. Remove the changes applied in `patch.diff`.
2. Revert the SDK check logic to its previous state.
3. Run `melos bootstrap` to confirm original behavior.

Rollback is guaranteed safe, as the patch only extends version matching
and does not alter core logic.
