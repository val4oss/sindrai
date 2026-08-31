---
name: packaging-patches
description: Manage patches in a packaging source tree with quilt — backport a patch to an older package version, add or refresh a patch, resolve a conflicted patch, and clean up afterwards. Use when working with a .spec file or debian/patches, a patch series, quilt setup/push/refresh errors, or .rej rejects.
allowed-tools: Bash(quilt *), Bash(cd *), Bash(cp *), Bash(rm *), Bash(find *), Bash(ls *), Bash(grep *), Bash(rpmbuild *), Read, Write, Edit
---

# Patch management in a packaging source tree

Add, adapt or repair a patch in a distribution package's patch series, using
quilt.

## The cardinal rule — two locations

Quilt separates **where patches are stored** from **where they are applied**.
Confusing the two is the most common source of errors in this workflow.

| Location | Contains | You are here |
|---|---|---|
| **Packaging source tree** | package metadata (`.spec`, `debian/`), source tarballs, patch files | before setup, and after cleanup |
| **Quilt working tree** | unpacked sources, a link to the patch store, quilt's `.pc/` state | during every `quilt` command |

**Enter the working tree exactly once, run every quilt command from there, and
leave only at cleanup.** Never `cd` mid-workflow — quilt resolves the series
relative to your current directory, and a stray `cd` silently targets the wrong
tree.

The concrete layout differs by packaging format and comes from the format file
loaded in Step 1.

| Reference | Load it |
|---|---|
| `references/format/rpm.md` | Step 1 — RPM layout, spec editing, setup and cleanup commands |
| `references/backport.md` | Step 6 — when the patch came from a different version |
| `references/conflicts.md` | Step 4 — when `quilt push` stops on a conflict |
| `references/quilt-commands.md` | anytime — command lookup |

---

## Step 0 — Preconditions

- A patch file is available and readable. **If none was provided, ask for it
  before doing anything else** — do not guess which patch is meant.
- The current directory is a packaging source tree (see the format file's
  *Detect* section).
- Work in the directory where you were invoked. If the patch lives elsewhere,
  copy it in rather than referencing it by an outside path.

---

## Step 1 — Identify the packaging format

| Signal in the directory | Format | Read |
|---|---|---|
| `*.spec` plus a source tarball | RPM | `references/format/rpm.md` |

Read **exactly one**. The file supplies the commands for steps 2, 3 and 7, and
the concrete working-tree path for the cardinal rule above.

If nothing matches, say the format is unsupported and stop rather than
improvising commands — a wrong `quilt setup` invocation leaves debris in the
source tree.

---

## Step 2 — Register the patch in the package metadata

Do this **before** touching quilt, so the metadata and the series stay in step.

The patch must be declared where the build system will find it, and applied at
build time. Both are format-specific.

→ commands: **your format file §2**

---

## Step 3 — Set up and enter the quilt working tree

Back up the package metadata first — setup can require temporary edits to it,
and you need a known-good copy to restore.

→ commands: **your format file §3**

Then enter the working tree once, per the cardinal rule.

---

## Step 4 — Apply the existing series

```bash
quilt series          # every patch, in order
quilt applied         # what is applied right now
quilt push -a         # apply all of them
```

**If `quilt push` stops on a conflict**, resolve it with
`references/conflicts.md` before adding anything new. Do not add your patch on
top of a half-applied series — the new patch would record unrelated changes.

---

## Step 5 — Create and record the new patch

```bash
quilt new <patch-filename>     # a new slot at the top of the stack
quilt add <file>               # once per file the patch will touch
                               # — a file not added is a change silently lost
# edit the files
quilt refresh                  # record the edits into the patch
```

`quilt add` before editing, always. Quilt snapshots a file when you add it; edit
first and the change is invisible to `quilt refresh`.

---

## Step 6 — Verify the patch content

```bash
quilt diff
```

Read every hunk. Confirm it does what the source patch intended, touches only
files you added, and contains no editor debris or unrelated whitespace.

**If the patch originated from a different version of the software than this
package ships** — the usual case for a backport — the mechanical application
succeeding proves nothing. Work through `references/backport.md` before
accepting it.

Run `quilt refresh` again after every correction.

---

## Step 7 — Unapply and clean up

Leave the tree as you found it: patches unapplied, working tree removed, backups
and editor droppings deleted. A leftover build directory or `.bac` file will end
up in the next source archive.

→ commands: **your format file §7**

---

## Step 8 — Report

State:

- **Metadata changes** — what was added to the spec or series, and why.
- **Conflicts** — which existing patches conflicted and how each was resolved.
  Note if any turned out to be already applied upstream and was dropped.
- **Adaptations** — every change made to the patch to fit this version, and the
  reason. This is the part a reviewer cannot reconstruct from the diff alone, so
  be specific: symbol renamed, hunk dropped, API signature differs.
- **Anything you could not verify** — hunks you adapted by inference, or
  behaviour that needs a build or test run to confirm.
- **Final state** — patch applied cleanly, refreshed, series unapplied, working
  tree removed.

If the adaptation required judgement calls, say so plainly rather than
presenting the result as a clean cherry-pick.
