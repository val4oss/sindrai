---
name: v4o-commit
description: Create or update commit according to the actuel changes, folowing conventions.
metadata:
  author: val4oss
  version: '1.0.0'
---

# v4o-commit

Create commit according conventions. Check the actual changes not already
committed or in status.

## Cardinal rules

- Never sign a commit by the AI agent name. Always use the user signature if
  found.
- If previous commit can be used, amend to it.
- Don't print anything else, no noises.

## Conventions

- Never guess, always ask if missing informations.
- commit are always structured as follow:

  ```
  <type>[optional scope]: <description>

  [optional body]

  [optional footer(s)]
  ```

- commit title `<type>[optional scope]: <description>`:
  - Never exceed 50 characters.
  - `description` made with letters and no symbols.
  - `type` see the [types](#Types) section for the list
- `optional body`:
  - Lines never exceeds 72 characters.
  - Never answer `why?` but gives the `what`. Short explanation of what it
    changes, and never the reason or the issue.

### Types

- `fix:` a commit that patches a bug in the codebase.
- `feat:` a commit that introduces a new feature to the codebase.
- **BREAKING CHANGES**:  commit that has a footer BREAKING CHANGE:, or appends
  a ! after the type/scope, introduces a breaking API change. A BREAKING CHANGE
  can be part of commits of any type.
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, 
  formatting, etc.)
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to our CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files
- `revert`: Reverts a previous commit

## Examples

### Commit message with description and breaking change footer

```
feat: allow provided config to extend others

BREAKING CHANGE: `extends` key in config file is now used for extending
other config files
```

### Commit message with ! to draw attention to breaking change

```
feat!: send mail to customer when product shipped
```

### Commit message with scope and ! to draw attention to breaking change

```
feat(api)!: send mail when a product is shipped
```

### Commit message with both ! and BREAKING CHANGE footer

```
feat!: drop support for Node 6

BREAKING CHANGE: use JavaScript features not available in Node 6.
```

### Commit message with no body

```
docs: correct spelling of CHANGELOG
```

### Commit message with scope

```
feat(lang): add Polish language
```

### Commit message with multi-paragraph body and multiple footers

```
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```
