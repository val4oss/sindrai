---
name: packaging
description: Manage RPM packaging source tree. Resolves build failures. Creates, manages, backports, resolves conflicted patches. Use when working with sources of RPM package with .spec file or patches, a patch series, quilt setup/push/refresh errors.
allowed-tools: Bash(quilt *), Bash(cd *), Bash(cp *), Bash(rm *), Bash(find *), Bash(ls *), Bash(grep *), Bash(rpmbuild *), Read, Write, Edit
metadata:
  author: val4oss
  version: 0.3.0
---

# Managing Package's sources

## cardinal rule

* Ask, don't assume. Unclear intent, or an open-ended request ("restructure it",
  "clean it up") that could go several ways, gets a question before a line is
  written — surface the fork in the road, never a silent assumption.
* Verify you are in a packaging source tree, see "Detect" section in 
  [format-rpm.md](./references/format-rpm.md).
* **Only working with patch:**
  * A patch file is available and readable. **If none was provided, ask for it
    before doing anything else** — do not guess which patch is meant.
  * Check the current state with quilt. See
    layout section in [format-rpm.md](./references/format-rpm.md) and
    [quilt-commands](./references/quilt-commands.md).
* Work in the directory where you were invoked. If the patch lives elsewhere,
  copy it in rather than referencing it by an outside path.
* If a command is not installed, do not try to install it, warn the user and
  continue with the next step. IF needed show what the user would need to run.
* For each request, print a report following the "Report" section below.

## Create a patch

* Step 1 - If user doesn't provides details information of what to change,
  neither link to a diff, git commit, ask it before doing anything else.
* Step 2 - If user provides a diff, git commit or link to a diff, check if the
  patch is already present in the source, and register in the specfile,
  otherwise references it following [rpm-format.md](./references/format-rpm.md)
  instructions. Go to Step 5 for verification.
* Step 3 - If the user provides a link to git commits, downlaod the patch
  `https://github.com/foo/bar/commit/${SHA}.patch`. Il mulitples are provides,
  merge them into a single patch file. Got to Step 5 for verification.
* Step 4 - If the user describes the changes, use `quilt` commands to setup 
  the working directory, investigate in the sources and what to change, then 
  create a patch and verify it with `quilt` again. Skip Step 5.
* Step 5 - Verify if the patch applies cleanly with quilt commands, otherwise go
  to section "To fix a patch that fails to apply" below.

## To fix a patch that fails to apply

Follow the steps in [conflicts.md](./references/conflicts.md) to resolve a patch
that fails to apply. The steps include checking if the patch is still needed,
backing up the failing patch, force-applying to see the damage,
and applying the rejected hunks by hand.

## To backport a patch

* Step 1 - Verify first if the patch is already present in the source, and
  register in the specfile, otherwise references it following
  [rpm-format.md](./references/format-rpm.md) instructions.
* Step 2 - Follow the steps in [backport.md](./references/backport.md) to
  backport a patch. The steps include deciding per hunk, verifying the fix
  actually landed, tagging the patch with its provenance, and when it is a
  security backport, confirming the CVE or advisory ID and putting it in the
  patch header and the metadata.

## Update a package

* if `package_check_version` tool ecists execute it as follows:
  `package_check_version --source <package-name>` to get the version of sources
  and check if update is needed and which versions to update.
* if `_service` files exists in the source tree, execute the
  `osc service runall` command. If the `osc` command not available, print a 
  warning and skip this section. Verify if the archive has been updated and if 
  the changelog has been updated, otherwise go to section "Add changelog" below.
* Otherwise:
  1. get from where the sources were downloaded if the user doesn't
    provide it, by fetching "Source" and "Url" from the specfile.
  2. Look at the current archive, and extract the folder to know how the archive
    and source folder are formated.
  3. Download the new archive, extract it, search any changelogs informations
    and format the source directory and archive name, if it didn't fit with 
    previous pattern.
  4. Update the specfile with the new archive name, the version, and add from
    the changelog the new entries, if any, following "Add changelog" section.
    If no changelog entriesn has been found, ask the user to do it himself.

## Add changelog

Changelog entries are added to the `<pkg>.changes` file, with a specific tool
to keep homogeneity. If the `osc` command is not available, print a warning and
skip this section.

`osc vc` command allows to interactively add a changelog entry. It will open an
editor for the user to write the entry. See
[changelog.md](./references/changelog.md) for more information.


## Report

* Do not edit file, just print in the conversation.
* State:
  * **Metadata changes** — what was added to the spec or series, and why.
  * **Conflicts** — which existing patches conflicted and how each was resolved.
    Note if any turned out to be already applied upstream and was dropped.
  * **Adaptations** — every change made to the patch to fit this version, and
    the reason. This is the part a reviewer cannot reconstruct from the diff
    alone, so be specific: symbol renamed, hunk dropped, API signature differs.
  * **Anything you could not verify** — hunks you adapted by inference, or
    behaviour that needs a build or test run to confirm.
  * **Final state** — patch applied cleanly, refreshed, series unapplied,
    working tree removed.
* If the adaptation required judgement calls, say so plainly rather than
presenting the result as a clean cherry-pick.
