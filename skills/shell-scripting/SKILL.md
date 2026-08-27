---
name: shell-scripting
description: Expert in Shell scripting with deep knowledge of shell programming and Linux system
allowed-tools: Read, Grep, Write, Bash(shellcheck *), Bash(grep *), Bash(find *), Bash(cat *), Bash(awk *), Bash(sed *), Bash(sort *), Bash(cut *), Bash(head *), Bash(tail *), Bash(tr *), Bash(printf *), Bash(test *), Bash(readlink *), Bash(realpath *), Bash(dirname *), Bash(basename *), Bash(mkdir *), Bash(cp *), Bash(ls *)
version: 0.1.0
---

## Core Principles

* Write portable, maintainable scripts
* Prioritize security and input validation
* Use proper error handling throughout
* Follow consistent naming and formatting

## Naming & Formating

* Maximum line length of 80 characters
* Use 4 spaces for indentation, no tabs
* Use descriptive names for scripts, functions and variables
  (e.g. `backup_objects.sh`, `create_backup()`, `backup_dir`)
* Employ modular scripts with functions to enhance readability and facilitate
  reuse
* Include comments for each major section or function
  * One header block per function, describing its purpose and declaring its
    three channels. See the Function contract section below

    ```shell
    ###
    # This is a short description of the function's purpose and usage
    ###
    function() {
      ...
    }
    ```

  * Section header comments
 
    ```shell
    # ========
    # Includes
    # --------
    ```

* Use global variables in uppercase with underscores for constants
  (e.g. `PRJ_ID`)
* Use lowercase with underscores for functions and variable names
  (e.g. `this_function()`, `this_variable`)
* Use underscores prefix for private/internal functions and variables
  (e.g. `_this_function()`, `_this_variable`)
* Always declare the return codes as globals

    ```shell
    # Return codes
    SUCCESS=0
    FAILURE=1
    ```

* One `return` per function, always the last statement, always 
  `return "$_<fn>_rc"`
* Accumulate the status of a function into a private `_<fn>_rc` variable

## Function contract

A function has exactly three output channels and they never overlap. Declare
all three in the header block of every function.

| Channel | Carries | Written with |
| --- | --- | --- |
| fd 3 | The log messages | the `print_xxx()` functions |
| stdout | The single returned value, if any | `printf '%s\n' "$_value"` |
| status | `SUCCESS` or `FAILURE` | `return "$_ret"` |

* The log channel is the file descriptor 3, opened once by `printer.sh`. A
  command substitution captures the standard output only, so a log message is
  never swallowed by a `$(...)` and never pollutes a returned value. The
  standard error is left to the external tools
* Never write a log message on the standard output. The standard output of a
  script belongs to its user, the standard output of a function belongs to its
  caller
* The log channel does not need to be closed before exiting, the kernel
  releases it. Close it with `printer_close()` only when the library is
  sourced by a long lived shell. Every child process inherits the descriptor,
  so append `3>&-` to any command that must not hold the channel open, a
  backgrounded or long lived one above all: it would keep a deleted log file
  on the disk and defeat the log rotation

### Returning a value

* A function returns **at most one value**, printed on its standard output as
  a single line, and read by the caller with a command substitution
* A function that returns a value **must not write any global variable**. The
  `$(...)` runs it in a subshell, every assignment made there is lost when the
  subshell ends. Such a function reads the globals, it never writes them
* Only the public functions, the ones without a `_` prefix, are allowed to
  write a global variable. A private `_function()` is either a producer, it
  prints a value and touches nothing, or a helper, it returns a status only.
  Name a function after what it does: a function that mutates the state of the
  script is public, whatever its scope
* A value needing more than one field is the sign that the function does too
  much, split it. If the fields really are inseparable, print them as one
  record and let the caller split it with `IFS` and `read`, in a here-document
  so that `read` does not run in a subshell
* An empty output with a `SUCCESS` status means "no result". A failure is
  reported by the status only, never by an empty value

### Calling a function

```shell
_skills=$(_collect_user_skills "$USER_SKILLS_D") || _status_rc="$FAILURE"
```

* The exit status of an assignment holding a command substitution is the exit
  status of that substitution, so the value and the status are collected on
  one line
* Never prefix such an assignment with `export`, `readonly` or `local`, the
  status becomes the one of the prefix and the failure is lost
* Never write `for _item in $(_producer)`, the status is discarded. Capture
  first, check the status, iterate after
* Always check the status of a call

### Header block

```shell
###
# Collect every skill equipped in the user enclave
# ARGUMENTS:
#   1 - skills_d : enclave directory to scan
# GLOBALS:
#   read: SKILLS_PATH
# OUTPUTS:
#   fd 3   : the debug messages
#   stdout : the space separated list of the skill names, empty when none
# RETURNS:
#   SUCCESS, FAILURE when the directory cannot be read
###
```

Omit the sections that do not apply, never omit `RETURNS`.

## Structure

* Use a consistent structure for scripts:
  * Shebang line (e.g. `#!/bin/sh`)
  * Script description and usage instructions
  * License information AGPLv3
  * Global variable declarations
  * Include external scripts or libraries
  * Internal Functions definitions that are only used within the script
  * Main Functions definitions that can be shared across scripts
  * Actions functions that perform the main tasks of the script
    (e.g. `usage()`, `build()`)
  * Main script logic, entrypoint with some verifiacations, arguments
    parsing and calling the main functions

## Input Validation

* Input Validation & Security
* Validate all inputs using getopts or manual validation logic
* Avoid hardcoding; use environment variables or parameterized inputs
* Apply the principle of least privilege in access and permissions
* Quote all variable expansions to prevent word splitting
* Sanitize user input before use


## Code Quality

* Ensure portability by using POSIX-compliant syntax
* Use shellcheck to lint scripts and improve quality
* Keep the three channels separate, the logs on the file descriptor 3, the
  returned values on the standard output, the external tools on the standard
  error. See the Function contract section
* Use meaningful exit codes
* Use functions to encapsulate logic and avoid code duplication
* Always integrate an helper and usage argument to provide guidance on script
  usage
* Always create and use the `printer.sh` to use the `print_xxx()` functions
  with the verbose and the quiet modes. It opens the log channel once, on the
  file descriptor 3, writes every message there, and applies the colours only
  when that channel is a terminal. `PRINTER_SINK` chooses the destination:
  `stderr`, the default, which is the console when interactive and the journal
  when running as a systemd unit, `tty` for the controlling terminal even when
  stdout and stderr are both redirected, and `file` for the path held by
  `PRINTER_FILE`


## Aditional resources

- printer script to include: [printer.sh](resources/printer.sh)
- For script shell examples, see [sample.sh](examples/sample.sh)
