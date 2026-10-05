# Changelog

Describes how changelog entries are added to the `<pkg>.changes` file, with a
specific tool to keep homogeneity. If the `osc` command is not available,
print a warning and skip.

If entries are already present and differes in the pattern from the following
explanation, prefere to continue with existing pattern, to keep homogeneit.

## `osc vc` content

The command will prepare an interactive editor with the template at the top of
the file:

```changes
-------------------------------------------------------------------
Tue Sep 22 13:32:00 UTC 2026 - maintainer <maintainer@example.org>

- 
```

## entries in update

During an update, synthetizes the changelogs fetched as followed:

```changes
- Release <version>:
  * entry 1
  * entry 2 
  * ...
```

## entries for added/deleted/updated patch

* Always refer the patch with its filename, that has been managed

```changes
- Patch updated: <patch-name>.patch
```

* If multiple patches are added, list them all:

```changes
- Patches updated:
  * <patch-name-1>.patch
  * <patch-name-2>.patch
  * ...
```

* Always add references of the fixes, it can be:
  * and bugzilla.suse.com issue: "bsc#<number>"
  * a CVE: "CVE-<year>-<number>"

```changes
- Summary of the patch. [bsc#<number>, CVE-<year>-<number>]
  <patch-name>.patch
```

## One entry per multiple diff

If multiple changes is provided to the package (patching + release), create only
one entry in the changelog, with different "- " lines for each topics.
