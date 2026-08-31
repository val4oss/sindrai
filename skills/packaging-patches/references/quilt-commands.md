# quilt command reference

All of these run from inside the quilt working tree.

## Inspecting the series

| Command | Effect |
|---|---|
| `quilt series` | List every patch, in series order |
| `quilt applied` | List patches currently applied |
| `quilt unapplied` | List patches not yet applied |
| `quilt top` | Name the patch at the top of the stack |
| `quilt files` | Files tracked by the current patch |
| `quilt patches <file>` | Which patches touch a given file |
| `quilt graph` | Dependency graph between patches |

## Applying and unapplying

| Command | Effect |
|---|---|
| `quilt push` | Apply the next patch |
| `quilt push -a` | Apply all remaining patches |
| `quilt push -f` | Force-apply, leaving `.rej` for conflicting hunks |
| `quilt push <patch>` | Apply forward through to a named patch |
| `quilt pop` | Unapply the top patch |
| `quilt pop -a` | Unapply everything |
| `quilt pop -f` | Unapply discarding uncommitted changes |

## Creating and editing patches

| Command | Effect |
|---|---|
| `quilt new <name>` | Create a new patch slot at the top of the stack |
| `quilt add <file>` | Track a file under the current patch — **before editing it** |
| `quilt edit <file>` | `add` then open in `$EDITOR`, in one step |
| `quilt refresh` | Record working-tree changes into the current patch |
| `quilt diff` | Changes not yet recorded, vs the current patch |
| `quilt diff -z` | Only changes since the last refresh |
| `quilt header -e <patch>` | Edit the patch's description header |
| `quilt delete <patch>` | Remove a patch from the series |
| `quilt fold < patch.diff` | Merge an external diff into the current patch |
| `quilt rename <new>` | Rename the top patch |

## The two traps

**`quilt add` must precede the edit.** Quilt snapshots a file when you add it
and computes the diff against that snapshot. Edit first, and `quilt refresh`
records nothing for that file — silently, with a zero exit code.

**`quilt refresh` overwrites the patch file in place.** There is no undo. Back
up any patch you did not author before refreshing it.

## Useful flags

| Flag | Effect |
|---|---|
| `quilt refresh -p ab` | Write `a/`…`b/` prefixes (git-style paths) |
| `quilt refresh --no-timestamps` | Omit timestamps — keeps diffs reproducible |
| `quilt refresh --no-index` | Omit the `index` line |
| `quilt refresh -U 5` | Use 5 lines of context instead of 3 |
| `quilt push -q` / `pop -q` | Quiet |

Wider context (`-U 5`) makes a patch stricter but easier to rebase correctly;
narrower context makes it apply more often, sometimes in the wrong place.

## Configuration

`quilt` reads `~/.quiltrc`, or `.quiltrc` in the tree. Common settings:

```sh
QUILT_PATCHES=debian/patches
QUILT_DIFF_ARGS="--no-timestamps --no-index -p ab"
QUILT_REFRESH_ARGS="--no-timestamps --no-index -p ab"
QUILT_NO_DIFF_INDEX=1
```

`QUILT_PATCHES` tells quilt where the patch store lives. It is what makes quilt
work directly in a Debian source tree without a setup step; under RPM the store
is the `patches` link that `quilt setup` creates, so it is normally left alone.

## Diagnostics

| Symptom | Likely cause |
|---|---|
| `Patch is already applied` | You are further up the stack than you thought — `quilt applied` |
| `File ... is not in the series` | The patch was never declared in the metadata |
| `quilt refresh` records nothing | The file was edited before `quilt add` |
| `No series file found` | Wrong directory, or `QUILT_PATCHES` not set |
| Changes vanish after `pop -a` | Expected — unapplied patches are not lost, only removed from the tree |
