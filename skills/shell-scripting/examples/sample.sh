#!/bin/sh
# Sample example - Sample to show a shell script example.
# Copyright (C) 2026  val4oss <val4oss@pm.me>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANYWARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# ================
# Global variables
# ----------------

# Return codes
SUCCESS=0
FAILURE=1

# Main variables
PRJ_ID="sample-script"

# Path variables
ROOT_D="$(cd "$(dirname "$0")" && pwd)"

# ========
# Includes
# --------

. "${ROOT_D}/printer.sh"


# ==================
# Internal functions
# ------------------

###
# Helper, it returns a status only and writes no global
# ARGUMENTS:
#   1 - path : file to check
# OUTPUTS:
#   fd 3 : an error message when the file is missing
# RETURNS:
#   SUCCESS, FAILURE when the file is not readable
###
_check_file() {
    _cf_rc="$SUCCESS"
    if [ ! -r "$1" ]; then
        print_error "File not readable: ${1}"
        _cf_rc="$FAILURE"
    fi
    return "$_cf_rc"
}

###
# Producer, it prints one value and never writes a global, it runs in the
# subshell of the caller's command substitution
# ARGUMENTS:
#   1 - path : configuration file to read
# GLOBALS:
#   read: PRJ_ID
# OUTPUTS:
#   fd 3   : the debug messages
#   stdout : the value of the 'name' key, empty when the key is absent
# RETURNS:
#   SUCCESS, FAILURE when the file cannot be read
###
_get_conf_name() {
    _gcn_rc="$SUCCESS"
    _gcn_name=""
    if ! _check_file "$1"; then
        _gcn_rc="$FAILURE"
    else
        _gcn_name=$(sed -n 's/^name=//p' "$1")
        print_debug "Read the name '${_gcn_name}' from ${1}"
    fi
    printf '%s\n' "$_gcn_name"
    return "$_gcn_rc"
}

# ================
# Main functions
# ----------------

###
# Public function, the only kind allowed to write a global variable
# ARGUMENTS:
#   1 - path : configuration file to read
# GLOBALS:
#   write: NAME
# OUTPUTS:
#   fd 3 : the messages of the called functions
# RETURNS:
#   SUCCESS, FAILURE when the configuration cannot be read
###
load_conf() {
    _lc_rc="$SUCCESS"
    # The value and the status are collected on the same line, never prefix
    # this assignment with 'local', 'export' or 'readonly'.
    NAME=$(_get_conf_name "$1") || _lc_rc="$FAILURE"
    return "$_lc_rc"
}

# Print usage information
usage() {
    _str="Usage: ${PRJ_ID} [-q|-v|-h] <actions> <agent> [options]
  -q, --quiet   Suppress all output except errors
  -v, --verbose Enable verbose output
  --version     Show version information and exit
  -h, --help    Show this help message and exit

Actions:
  run           Run the sandbox with the specified agent

Options:
  --conf       Defined conf file path for building the image. See Notes.

  Notes:
  - Usefull notes for the script.
"
    printf "%s\n" "$_str"
}

# ===========
# Entry point
# -----------

_check_tools_needed || {
    print_error "Please install the missing tools and try again. Aborting."
    exit $FAILURE
}

# Get arguments
PARSED_ARGUMENTS=$(
    getopt -a -n $PRJ_ID -o c:vh --long conf:,verbose,help -- "$@"
)

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -c | --conf)        CONF=$2                     ; shift 2 ;;
    -v | --verbose)     VERBOSE=1                   ; shift 1 ;;
    -h | --help)        usage                       ;;
    --)                 shift                       ; break   ;;
    *)                  print_warning "Unexpected option: $1"; usage   ;;
  esac
done

# Verify that the required arguments are provided
# ...


# Entry point
# ...

exit $SUCCESS
