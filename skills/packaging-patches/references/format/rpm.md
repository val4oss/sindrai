# Format: RPM

## Detect

A `*.spec` file plus at least one source tarball in the current directory.

```bash
ls *.spec
ls *.tar.* 2>/dev/null
```

If there are several spec files, ask which package is meant rather than
guessing.

## Layout

`quilt setup <spec>` unpacks the sources into a build tree beside the spec:

```
mypkg/                                  ← packaging source tree
├── mypkg.spec
├── mypkg-1.4.2.tar.xz
├── fix-something.patch
└── mypkg-1.4.2-build/                  ← created by quilt setup
    └── mypkg-1.4.2/                    ← the quilt working tree
        ├── patches -> ../../           (link to the patch store)
        ├── .pc/                        (quilt state)
        └── … unpacked sources …
```

The working tree is `<name>-<version>-build/<name>-<version>`. Note the doubled
directory: the `-build` wrapper, then the source directory inside it.

## §2 — Register the patch in the spec

Two edits, both required.

**Declare the patch.** Find the last `PatchN:` line and add the next number
immediately after it:

```
Patch0:  existing-one.patch
Patch1:  existing-two.patch
Patch2:  fix-something.patch      ← added
```

```bash
grep -n '^Patch' mypkg.spec        # find the highest N in use
```

Numbers must not collide; they need not be contiguous, but keeping them so makes
review easier.

**Ensure it is applied in `%prep`.** Which edit depends on what the spec already
does:

| `%prep` currently uses | Do this |
|---|---|
| `%autosetup` (with or without `-p1`) | nothing — it applies every declared patch automatically |
| explicit `%patch N -p1` lines | add a matching `%patch 2 -p1` for the new number |
| `%setup` with no patch application at all | replace the setup macro with `%autosetup -p1` |

```bash
sed -n '/^%prep/,/^%build/p' mypkg.spec    # read the whole %prep section first
```

Note the RPM macro syntax change: modern RPM wants `%patch 2 -p1` (spaced);
older specs use `%patch2 -p1`. Match whatever the surrounding lines already do.

## §3 — Setup and enter

**Back up the spec first.** Setup may need temporary edits, and this backup is
your only way back:

```bash
cp mypkg.spec mypkg.spec.bac
quilt setup mypkg.spec
```

If `quilt setup` fails, edit the spec temporarily to get past it:

- rewrite `%patchX` as `%patch X` (or the reverse, depending on the RPM version)
- comment out macros quilt's parser does not know
- resolve `%global`/`%define` indirection in `Source:` or `Patch:` lines

Setup only needs to parse the spec far enough to unpack and lay out patches — a
temporarily degraded spec is fine here.

**Restore the real spec as soon as setup succeeds:**

```bash
cp mypkg.spec.bac mypkg.spec
```

Do this immediately. Forgetting is how a debugging edit ships to the build.

**Find and enter the working tree — once:**

```bash
ls -d *-build/*/          # confirm the actual path
cd mypkg-1.4.2-build/mypkg-1.4.2
```

Everything from here until §7 runs from inside this directory.

## §7 — Unapply and clean up

From inside the working tree:

```bash
quilt pop -a              # unapply everything cleanly
cd ../..                  # back to the packaging source tree — two levels
```

Then remove the debris:

```bash
rm -rf mypkg-1.4.2-build      # the whole build wrapper, not just the inner dir
rm -f mypkg.spec.bac          # the spec backup, once you are sure it is restored
find . -name "*~" -delete     # editor backups
find . -name "*.rej" -o -name "*.orig" | head   # should print nothing
```

Check the spec really is the restored version before deleting the backup:

```bash
grep -n '^Patch\|^%patch\|^%autosetup' mypkg.spec
```

Watch the `-build` suffix when removing — `rm -rf` on a mistyped path exits 0
and removes nothing, leaving the tree behind while looking like it succeeded.
Verify:

```bash
ls -d *-build 2>/dev/null && echo "STILL PRESENT — check the name"
```

## Optional verification

Confirm the series applies through RPM itself, not just through quilt:

```bash
rpmbuild -bp --define "_topdir $PWD" mypkg.spec
```

This runs `%prep` only. It catches a patch that quilt applies happily but RPM
does not — usually a wrong `-p` level or a `%patch` number that does not match
the `PatchN:` declaration. Clean up the resulting `BUILD/` directory afterwards.
