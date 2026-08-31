# Resolving a conflicted patch

`quilt push` stopped. Before fixing anything, work out *why* — the cheapest
resolution is often not "repair the patch".

## First: is the patch still needed?

A patch that fails to apply after a version bump is frequently one the new
upstream release already contains. Check before repairing:

```bash
quilt top                             # which patch failed
quilt header <patch>                  # what it claims to do
grep -n "<distinctive line from the patch>" <target-file>
```

If the change is already present in the source, **drop the patch** instead of
fixing it:

```bash
quilt delete <patch>                  # removes it from the series
```

Then remove its declaration from the package metadata too, and note the removal
in the report. A patch kept alive past its purpose costs someone a conflict
resolution at every future rebase.

## Repairing a genuine conflict

### 1. Back up the failing patch — before anything else

```bash
cp patches/<failing-patch> patches/<failing-patch>.bac
```

`quilt refresh` in step 4 **overwrites the patch file in place**. This backup is
your only copy of the original.

### 2. Force-apply to see the damage

```bash
quilt push -f
```

Hunks that match are applied. Each file with rejected hunks gets a `.rej`
alongside it; some setups also leave a `.orig`.

```bash
find . -name "*.rej"
```

### 3. Apply the rejected hunks by hand

For each `.rej`:

1. Read the `.rej` to see what the hunk intended.
2. Read the target file around the intended location to see why the context
   drifted — moved code, renamed identifier, reindentation, or the change is
   partially present already.
3. Edit the target file to achieve the intent, in this tree's idiom. Do not
   paste the hunk verbatim if the surrounding code has changed shape.
4. Delete the `.rej` (and any `.orig`) once resolved.

If the resolution touches a file the patch did not previously cover, track it or
the change will not be recorded:

```bash
quilt add <newly-changed-file>
```

Check what the current patch tracks at any point:

```bash
quilt files
```

### 4. Record the resolution

```bash
quilt diff            # review before committing it to the patch
quilt refresh         # overwrites patches/<failing-patch>
```

Review with `quilt diff` **first**. Refresh records whatever is in the working
tree, including a half-finished edit or a stray debug line.

### 5. Continue the series

```bash
quilt push -a
```

Later patches often conflict for the same underlying reason. Repeat from step 1
for each.

## Leaving the tree clean

Once the series applies, confirm no rejects survived and remove the backups you
no longer need:

```bash
find . -name "*.rej" -o -name "*.orig" | head    # must print nothing
rm -f patches/*.bac                              # only after verifying the result
```

Keep a `.bac` until you are confident in the resolution — comparing the original
against the refreshed patch is the fastest way to review what you changed:

```bash
diff -u patches/<patch>.bac patches/<patch>
```

## Report what you did

Conflict resolution is a judgement call that the final diff hides. For each
conflicted patch, record: why it conflicted, whether it was repaired or dropped,
and — where hunks were rewritten rather than reapplied — what changed and why.
