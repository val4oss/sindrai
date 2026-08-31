# sindrAI

> **Forging weapons and skills for your AI agents.**

<div align="center">
  <img src="docs/sindrai.jpeg" alt="sindrai project banner">
</div>

In Norse mythology, Sindri is the legendary dwarf blacksmith who forged the gods
most powerful artifacts, including Thor's hammer. **sindrAI** is a lightweight,
secure shell utility designed to equip your local AI agents (Claude, Gemini,
custom agents) with new system-wide skills. 

This project is the perfect companion to [glAIpnir](https://github.com/val4oss/ai-agents-sandbox)
(securing and enclaving AI agents). While *glAIpnir* binds and secures the AI,
*sindrAI* provides it with the right tools.

---

## The Problem

AI agents typically look for their skill and tool definitions in user-local
directories like `~/.agents/skills/`. However, standard Linux packaging
practices (RPM, DEB) dictate that **system packages must never modify a user's
`$HOME` directory directly**. 

If a system administrator wants to deploy an enterprise-wide skill
(e.g., `agent-skill-pr-reviewer`) via RPM, there is no FHS-compliant way to
inject it directly into every user's home folder.

## The Solution

**sindrAI** bridges this gap using a controlled, opt-in mechanism:

1. **System Administrators** install AI skills via standard RPMs
  (e.g., `dnf install sindrai-skill-pr-reviewer`). These files are safely placed
  in `/usr/share/sindrai/skills/`.
2. **Standard Users** run the `sindrai` CLI tool without root privileges.
3. `sindrai` securely symlinks or copies the requested skills from the
  system-wide repository into the user's `~/.agents/skills/` directory.

---

## Installation

Install the core package, which provides the `sindrai` binary:

```bash
sudo zypper install sindrai-core
```

Then install any skill packages you want available on the system:

```bash
sudo zypper install sindrai-skill-pr-review sindrai-skill-python-dev
```

### From source

```bash
./build.sh                          # generate the build/ artefacts
./build.sh install                  # system wide install
PREFIX="${HOME}/.local" ./build.sh  # Build  for local user installation
DESTDIR="/tmp/pkg" PREFIX="/usr" ./build.sh install # packaging insatllation
```

`./build.sh check` lints the sources with `shellcheck`, `./build.sh test` runs
the testsuite on the built tool.

## Usage

The `sindrai` CLI is designed to be simple and intuitive for end-users.
See [docs/usage.md](docs/usage.md) for the complete command reference.

### List available skills

```bash
$ sindrai list
Available system skills (/usr/share/sindrai/skills/):
  - pr-reviewer     (v1.2) - Automatically review Pull Requests
  - python-dev      (v2.0) - Python code generation and testing
```

### Install (Equip) a skill

Link a system skill into your local AI enclave (`~/.agents/skills/pr-reviewer`):

```bash
$ sindrai install pr-reviewer
[OK] Skill 'pr-reviewer' successfully forged into ~/.agents/skills/pr-reviewer
```

### View equipped skills

See what your AI agents currently have access to:

```bash
$ sindrai status
Equipped skills in ~/.agents/skills/:
  - pr-reviewer -> /usr/share/sindrai/skills/pr-reviewer
```

### Remove (Unequip) a skill

Remove the skill from your local enclave (this doesn't remove the RPM):

```Bash
$ sindrai remove pr-reviewer
[OK] Skill 'pr-reviewer' removed from your enclave.
```

### Options

| Option | Description |
| ------ | ----------- |
| `-a`, `--all` | Apply the action to every skill |
| `-f`, `--force` | Overwrite or remove entries not managed by `sindrai` |
| `--copy` | Copy the skill tree instead of symlinking it |
| `--link` | Symlink the skill tree, the default |
| `--target <dir>` | Agent enclave directory, default `~/.agents` |
| `--<agent>` | Specific agent to manage sindrai skills. See list agents just below |
| `--conf <file>` | Configuration file to read |
| `-q`, `-v`, `-vv` | Quiet, verbose and debug output |

`<agent>` can be:
* `claude`
* `gemini`
* `opencode`
* `copilot`

An optional configuration file, read from
`${XDG_CONFIG_HOME:-~/.config}/sindrai/sindrai.conf`, accepts the
`AGENTS_D`, `EXTRA_SKILLS_DIRS` and `LINK_MODE` keys. The command line
always wins over the configuration file.

## Architecture for Packagers

If you want to package a new skill for sindrAI, follow these simple rules:

1. Package Name: Prefix your RPM with sindrai-skill- (e.g.,
  `sindrai-skill-aws-cli`).
2. Dependencies: Ensure your package Requires: sindrai-core.
3. Installation Path: Your specfile should install all skill assets
  (prompts, scripts, yaml definitions) into:
  `/usr/share/sindrai/skills/<skill-name>/`
4. No Scriptlets: Do NOT use `%post` or `%postun` to modify user
  directories. Let the `sindrai` binary handle the user-space mapping.

## Security & glAIpnir Compatibility

`sindrai` is written in pure POSIX shell and requires no root privileges
to run. It only reads from `/usr/share/sindrai/` and writes to the user's
own `~/.agents/` directory, ensuring strict compatibility with glAIpnir
sandboxing.

## Testing

Testsuite is developed into [./test/](./test) and use the [bats](https://github.com/bats-core/bats-core) project.

You would need first to install git submodules using `--recurse-submodules` in
the `git clone command`, or if already coned: `git pull --recurse-submodules`.

Then run `bats test/` to run the testsuite.
