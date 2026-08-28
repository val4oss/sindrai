# sindrAI usage

Complete reference of everything the `sindrai` CLI can run. For the project
rationale, see the [README](../README.md).

```
sindrai [-q|-v|-vv] <action> [skill...] [options]
```

`sindrai` never needs root privileges. It only reads the system skill
repository and writes into your own enclave directory.

---

## Table of contents

- [Concepts](#concepts)
- [Actions](#actions)
  - [list](#list)
  - [install](#install)
  - [remove](#remove)
  - [status](#status)
  - [help](#help)
  - [version](#version)
- [Options](#options)
- [Exit codes](#exit-codes)
- [Configuration file](#configuration-file)
- [Environment variables](#environment-variables)
- [Anatomy of a skill](#anatomy-of-a-skill)
- [Recipes](#recipes)
- [Build and maintainer commands](#build-and-maintainer-commands)

---

## Concepts

**System skill repository** — where the RPMs drop their skills, by default
`/usr/share/sindrai/skills/`. It is read only as far as `sindrai` is
concerned. Extra directories can be added with `EXTRA_SKILLS_DIRS`.

**Enclave** — your own agent directory, by default `~/.agents`. Skills are
equipped into `<enclave>/skills/`, which is where the AI agents look.

**Forging** — equipping a skill, either as a symlink (the default) or as a
copy (`--copy`).

**Managed vs foreign** — an entry of your enclave is *managed* when
`sindrai` can prove it forged it: a symlink pointing into the system search
path, or a copied directory carrying a `.sindrai-source` marker that points
there. Anything else is left alone unless you pass `--force`.

---

## Actions

Exactly one action per invocation. Options and skill names may appear
before or after the action, in any order.

### list

List the skills available in the system repositories.

```
sindrai list [options]
```

```bash
$ sindrai list
Available system skills (/usr/share/sindrai/skills/):
  - pr-reviewer     (v1.2) - Automatically review Pull Requests
  - python-dev      (v2.0) - Python code generation and testing
```

- One block per search directory; directories that do not exist are
  skipped, existing but empty ones print their header with no entry.
- The version and the description come from the skill's `SKILL.md` front
  matter. A skill without one is listed as `(vn/a) - no description`.
- `list` takes no skill argument. Passing one prints a warning and the
  argument is ignored.
- When no skill is found anywhere, a warning is printed and the action
  still succeeds.

### install

Forge one or more system skills into your enclave.

```
sindrai install <skill>... [options]
sindrai install --all [options]
```

```bash
$ sindrai install pr-reviewer
[OK] Skill 'pr-reviewer' successfully forged into ~/.agents/skills/pr-reviewer
```

- Several skills at once: `sindrai install pr-reviewer python-dev`.
- `--all` equips every skill of every search directory.
- The enclave directory is created if missing.
- Already equipped from the same source: prints
  `Skill '<name>' is already equipped.` and succeeds without touching it.
  Use `--force` to forge it again, which is how you switch an existing
  entry between link and copy mode.
- An existing entry that `sindrai` did not forge is **not** overwritten;
  the action fails and asks for `--force`.
- With `--copy`, the tree is copied, made user writable, and a
  `.sindrai-source` file recording the origin is dropped in it.
- Unknown or malformed skill names fail the action. With several skills,
  the valid ones are still equipped and the exit status is `1`.

### remove

Remove skills from your enclave. The system copy and the RPM are never
touched.

```
sindrai remove <skill>... [options]
sindrai remove --all [options]
```

```bash
$ sindrai remove pr-reviewer
[OK] Skill 'pr-reviewer' removed from your enclave.
```

- `--all` targets **every** entry of the enclave, including foreign ones;
  those fail unless `--force` is given, so a mixed enclave needs either
  explicit names or `--force`.
- Removing an entry `sindrai` did not forge fails and asks for `--force`.
- A skill that is not equipped is an error.

### status

Show what your agents currently have access to.

```
sindrai status [options]
```

```bash
$ sindrai status
Equipped skills in ~/.agents/skills/:
  - pr-reviewer -> /usr/share/sindrai/skills/pr-reviewer
  - my-own -> /home/me/dev/my-own (foreign)
  - handmade (local, not managed by sindrai)
```

| Line form | Meaning |
| --------- | ------- |
| `name -> source` | Forged by `sindrai`, from the system search path |
| `name -> source (foreign)` | Resolvable, but its source is outside the search path |
| `name (local, not managed by sindrai)` | A plain directory you created |

`(none)` is printed when the enclave is empty or does not exist.

### help

```bash
sindrai help
sindrai --help
sindrai -h
```

Prints the built-in help, which shows the resolved default paths of your
installation, and exits with `0`. It is also printed on a usage error.

### version

```bash
sindrai version
sindrai --version
```

```
sindrai version: 1.0.0
```

---

## Options

Every option has a `--long` form; most also accept a bare word and a short
letter, so `sindrai remove all` and `sindrai remove --all` are the same.

| Option | Bare word | Description |
| ------ | --------- | ----------- |
| `-a`, `--all` | `all` | Apply the action to every skill |
| `-f`, `--force` | `force` | Overwrite or remove entries not managed by `sindrai`, and re-forge an already equipped skill |
| `--copy` | `copy` | Copy the skill tree instead of symlinking it |
| `--link` | `link` | Symlink the skill tree; the default |
| `-t`, `--target <dir>` | | Enclave directory; skills go to `<dir>/skills`. Default `~/.agents` |
| `--conf <file>` | | Read this configuration file. See below |
| `-q`, `--quiet` | `quiet` | Errors only |
| `-v`, `--verbose` | `verbose` | Verbose output |
| `-vv` | | Verbose plus shell tracing (`set -x`) |
| `-h`, `--help` | `help` | Show the help and exit |
| `--version` | `version` | Show the version and exit |

Notes:

- `-q` suppresses the `[INFO]` and `[WARN]` lines. The listings produced by
  `list` and `status` are the output of those commands, not log messages,
  so they are still printed.
- An unknown `-` prefixed argument is a usage error. Anything else is taken
  as a skill name.
- `--target` and `--conf` require an argument.

---

## Exit codes

| Code | Meaning |
| ---- | ------- |
| `0` | Success, including `help` and `version` |
| `1` | Failure: no action, unknown option or skill, invalid name, refused overwrite or removal, unreadable configuration file, missing required tool |

A failing action prints `[✗] Action '<action>' failed.`, a successful one
prints `[✓] Done.`

---

## Configuration file

An optional file of `KEY=value` lines; `#` starts a comment, values may be
quoted. Unknown keys are reported and ignored.

| Key | Description |
| --- | ----------- |
| `AGENTS_D` | Enclave directory, same as `--target` |
| `EXTRA_SKILLS_DIRS` | Additional system skill directories, space separated |
| `LINK_MODE` | `link` or `copy` |

```sh
# ~/.config/sindrai/sindrai.conf
AGENTS_D="${HOME}/.agents"
EXTRA_SKILLS_DIRS="/opt/team-skills /srv/skills"
LINK_MODE=copy
```

Where it is read from:

- Installed: `${XDG_CONFIG_HOME:-~/.config}/sindrai/sindrai.conf`
- From a checkout: `sindrai.conf` next to the script

That default file is read **before** the command line, so command line
options win over it. An explicit `--conf <file>` is applied at the point it
appears, so it overrides options written before it and is overridden by
options written after it:

```bash
$ sindrai --copy --conf team.conf install pr-reviewer  # team.conf wins
$ sindrai --conf team.conf --copy install pr-reviewer  # --copy wins
```

An invalid `LINK_MODE` is rejected before any action runs.

---

## Anatomy of a skill

A skill is a directory in a search path. Its metadata is read from the YAML
front matter of `SKILL.md`, which is optional:

```
/usr/share/sindrai/skills/pr-reviewer/
├── SKILL.md
└── ...
```

```markdown
---
name: pr-reviewer
version: 1.2
description: Automatically review Pull Requests
---
```

Only `version` and `description` are used by `sindrai`. Skill names must
match `[A-Za-z0-9][A-Za-z0-9._-]*`; anything else is refused, and hidden
directories are ignored.

---

## Recipes

Equip everything available, as copies you can then tweak locally:

```bash
sindrai --copy install --all
```

Move an already equipped skill from a symlink to an editable copy:

```bash
sindrai --copy install pr-reviewer --force
```

Try a skill in a throwaway enclave, without touching `~/.agents`:

```bash
sindrai --target /tmp/enclave install pr-reviewer
sindrai --target /tmp/enclave status
```

Use a team repository in addition to the system one:

```bash
printf 'EXTRA_SKILLS_DIRS=/srv/team-skills\n' \
    > ~/.config/sindrai/sindrai.conf
sindrai list
```

Install skill for specific agents

```bash
# For claude
sindrai --target ~/.claude install pr-review
# For Gemini
sindrai --target ~/.gemini install pr-review
# For opencode
sindrai --target ~/.config/opencode install pr-review
# For copilot
sindrai --target ~/.copilot install pr-review
```

Clean the enclave completely, including entries `sindrai` does not own:

```bash
sindrai remove --all --force
```

Debug what is happening:

```bash
sindrai -vv status
```

