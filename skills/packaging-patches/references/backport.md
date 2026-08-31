# Backporting a patch across versions

Applies when the patch was written against a different — usually newer —
version of the software than this package ships.

**A patch applying cleanly proves nothing here.** `quilt refresh` succeeds
whenever the context lines match. It cannot tell you that the code you inserted
calls a helper this version does not have, or guards a config option introduced
two releases later. Mechanical success plus semantic nonsense is the normal
failure mode of a backport, and it compiles often enough to reach a build.

## Read every hunk against the old tree

For each hunk in `quilt diff`, take the identifiers it *introduces or relies on*
and confirm each exists in this version:

```bash
grep -rn "<identifier>" --include="*.[ch]" .    # adjust for the language
```

What to check, roughly in order of how often it bites:

- **Functions and macros called by added lines.** Introduced later, renamed, or
  moved to a different header.
- **Struct fields and enum members** the patch reads or sets.
- **Function signatures.** The name exists but the parameter list differs — an
  extra flags argument, a changed return convention, a context pointer added.
- **Include paths and headers.** Files split or merged between versions.
- **Error-handling idiom.** The tree may have migrated between return codes,
  `goto err` labels, and a cleanup helper. Match the surrounding code, not the
  patch's origin.
- **Config or feature guards.** `#ifdef`, build options, or capability checks
  that do not exist yet.
- **Locking and allocation conventions.** A newer tree may hold a lock the older
  one takes inside the callee — double-locking is silent until runtime.
- **Whitespace and formatting churn.** Reformatting hunks carry no fix; drop
  them rather than importing an unrelated style change.

## Decide per hunk

Each hunk resolves one of four ways. Record which, for the report:

| Situation | Action |
|---|---|
| Applies and all referenced symbols exist | Keep unchanged |
| Symbol renamed or signature differs | Adapt to this version's API |
| Depends on a refactor not in this version | Pull in the prerequisite, or reimplement the fix in this version's idiom |
| Pure cleanup, reformatting, or unrelated to the fix | Drop it |

Prefer reimplementing over pulling in prerequisites. A backport should be the
smallest change that fixes the issue — dragging in a refactor to make a patch
apply enlarges the diff, and the distro carries that risk for the package's
lifetime.

If you cannot determine whether a hunk is needed, keep it and say so in the
report. Silently dropping a hunk from a security fix is the worst outcome here.

## Verify the fix actually landed

After adapting, check the fix is still present rather than merely that the file
changed. Re-read the original patch's intent — the guard it adds, the value it
bounds, the path it rejects — and confirm that behaviour now exists in this
tree, in this version's terms.

```bash
quilt diff                # the adapted patch
quilt refresh             # after every correction
```

An adapted patch that no longer performs the security check is worse than no
patch: it makes the package look fixed to anyone reading the series.

## Tag the patch with its provenance

A backported patch outlives everyone's memory of it. Add a DEP-3 style header at
the top of the patch file so the next maintainer knows where it came from and
what was changed:

```
Description: fix out-of-bounds read when parsing oversized headers
Origin: upstream, https://github.com/example/proj/commit/<sha>
Bug: https://github.com/example/proj/issues/1234
Applied-Upstream: 1.6.0
Forwarded: not-needed
Last-Update: <YYYY-MM-DD>
Comment: Backported to 1.4.2. Upstream uses hdr_ctx_new(), absent here;
 reimplemented using the ctx_alloc() path. Reformatting hunks dropped.
```

Edit the header into the patch file after `quilt refresh` — refresh preserves
text above the first `---`/`diff` line. Or use `quilt header -e <patch>`.

The `Comment:` field is the one that matters: it is the only record of the
judgement calls, and it is what makes the next rebase possible.

## When it is a security backport

- Confirm the CVE or advisory ID and put it in the patch header and the metadata
  changelog entry.
- Check whether the advisory lists **multiple** commits — fixes are frequently
  split into a fix plus a follow-up, and applying only the first leaves the bug
  reachable.
- If this version's code diverges enough that the fix cannot be reproduced
  faithfully, say so rather than shipping an approximation.
