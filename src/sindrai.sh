#!/bin/sh
# sindrAI - Forging weapons and skills for your AI agents - Equip a user
# enclave with the AI agent skills installed system wide.
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
PRJ_ID="sindrai"
VERSION="0.1.0"

# Path variables
ROOT_D="$(cd "$(dirname "$0")/.." && pwd)"
DATA_D_DEFAULT="${ROOT_D}"
DATA_D="${DATA_D_DEFAULT}"
CONF_P="${ROOT_D}/${PRJ_ID}.conf"
AGENTS_D_DEFAULT="${HOME}/.agents"
AGENTS_D="${AGENTS_D_DEFAULT}"
CLAUDE_AGENT_D="${HOME}/.claude"
GEMINI_AGENT_D="${HOME}/.gemini"
OPENCODE_AGENT_D="${HOME}/.config/opencode"
COPILOT_AGENT_D="${HOME}/.copilot"
SKILLS_D_NAME="skills"
# Resolved by resolve_paths() once the arguments are parsed.
USER_SKILLS_D=""
SKILLS_PATH=""

# Skill variables
# Name of the file holding the metadata of a skill.
META_F="SKILL.md"
# Marker dropped in a copied skill, records where it has been forged from.
MARKER_F=".sindrai-source"
# Extra system wide skill directories, set from the configuration file.
EXTRA_SKILLS_DIRS=""

# argument variables
ACTION=""
SKILLS=""
LINK_MODE="link"
FORCE=0
ALL=0
DEBUG=0
TOOLS_NEEDED="awk chmod cp grep head ln mkdir readlink rm sed"

# ========
# Includes
# --------

. "${ROOT_D}/src/printer.sh"

# ==================
# Internal functions
# ------------------

###
# Check that every tool needed by the script is reachable in the PATH
# GLOBALS:
#   read: TOOLS_NEEDED
# OUTPUTS:
#   fd 3 : one error message per missing tool
# RETURNS:
#   SUCCESS, FAILURE when at least one tool is missing
###
_check_tools_needed() {
    _ctn_rc="$SUCCESS"
    for _ctn_tool in $TOOLS_NEEDED; do
        if ! command -v "$_ctn_tool" >/dev/null 2>&1; then
            print_error "Required tool not found: ${_ctn_tool}"
            _ctn_rc="$FAILURE"
        fi
    done
    return "$_ctn_rc"
}

###
# Validate a skill name, only plain path-less names are accepted
# ARGUMENTS:
#   1 - name : candidate skill name
# RETURNS:
#   SUCCESS, FAILURE when the name is empty, hidden or holds a separator
###
_valid_skill_name() {
    _vsn_rc="$SUCCESS"
    case "$1" in
        ''|.|..|.*|-*|*/*|*\\*)
            _vsn_rc="$FAILURE"
            ;;
        *)
            if ! printf '%s' "$1" | \
                grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then
                _vsn_rc="$FAILURE"
            fi
            ;;
    esac
    return "$_vsn_rc"
}

###
# Locate a skill in the system search path, the first hit wins
# ARGUMENTS:
#   1 - name : skill name to look for
# GLOBALS:
#   read: SKILLS_PATH
# OUTPUTS:
#   stdout : the directory holding the skill, empty when it is not found
# RETURNS:
#   SUCCESS, FAILURE when the skill is in none of the search directories
###
_find_skill() {
    _fs_rc="$FAILURE"
    _fs_src=""
    for _fs_dir in $SKILLS_PATH; do
        if [ "$_fs_rc" -ne "$SUCCESS" ] && [ -d "${_fs_dir}/${1}" ]; then
            _fs_src="${_fs_dir}/${1}"
            _fs_rc="$SUCCESS"
        fi
    done
    printf '%s\n' "$_fs_src"
    return "$_fs_rc"
}

###
# Read one field from the YAML front matter of the metadata file of a skill
# ARGUMENTS:
#   1 - skill_d : directory holding the skill
#   2 - key     : name of the front matter key to read
#   3 - default : value to print when the key or the metadata file is missing
# GLOBALS:
#   read: META_F
# OUTPUTS:
#   fd 3   : a debug message when the metadata file is missing
#   stdout : the value of the key, or the default
# RETURNS:
#   SUCCESS
###
_skill_field() {
    _sf_rc="$SUCCESS"
    _sf_value=""
    _sf_meta_p="${1}/${META_F}"
    if [ ! -r "$_sf_meta_p" ]; then
        print_debug "No ${META_F} in ${1}, '${2}' falls back to the default"
    else
        _sf_value=$(awk -v key="$2" '
            NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
            NR > 1 && $0 ~ /^---[[:space:]]*$/ { exit }
            NR > 1 && index($0, key ":") == 1 {
                value = substr($0, length(key) + 2)
                sub(/^[[:space:]]+/, "", value)
                sub(/[[:space:]]+$/, "", value)
                gsub(/^["'\'']|["'\'']$/, "", value)
                print value
                exit
            }
        ' "$_sf_meta_p" 2>/dev/null)
    fi
    [ -n "$_sf_value" ] || _sf_value="$3"
    printf '%s\n' "$_sf_value"
    return "$_sf_rc"
}

###
# List the skill names held by the given directory
# ARGUMENTS:
#   1 - dir : directory to scan
# OUTPUTS:
#   fd 3   : one debug message per rejected entry
#   stdout : one skill name per line, nothing when the directory holds none
# RETURNS:
#   SUCCESS
###
_list_dir_skills() {
    _lds_rc="$SUCCESS"
    for _lds_entry in "${1}"/*; do
        if [ -d "$_lds_entry" ]; then
            _lds_name="${_lds_entry##*/}"
            if _valid_skill_name "$_lds_name"; then
                printf '%s\n' "$_lds_name"
            else
                print_debug "Skipped invalid skill name: ${_lds_name}"
            fi
        fi
    done
    return "$_lds_rc"
}

###
# Collect every skill name of the system search path, duplicates removed
# GLOBALS:
#   read: SKILLS_PATH
# OUTPUTS:
#   fd 3   : the debug messages of _list_dir_skills()
#   stdout : the space separated skill names, empty when none is found
# RETURNS:
#   SUCCESS, FAILURE when a search directory cannot be listed
###
_collect_sys_skills() {
    _css_rc="$SUCCESS"
    _css_list=""
    for _css_dir in $SKILLS_PATH; do
        if [ -d "$_css_dir" ]; then
            _css_found=$(_list_dir_skills "$_css_dir") || _css_rc="$FAILURE"
            for _css_name in $_css_found; do
                case " ${_css_list} " in
                    *" ${_css_name} "*) : ;;
                    *) _css_list="${_css_list} ${_css_name}" ;;
                esac
            done
        fi
    done
    printf '%s\n' "${_css_list# }"
    return "$_css_rc"
}

###
# Collect every skill equipped in the user enclave
# GLOBALS:
#   read: USER_SKILLS_D
# OUTPUTS:
#   stdout : the space separated skill names, empty when the enclave is empty
# RETURNS:
#   SUCCESS
###
_collect_user_skills() {
    _cus_rc="$SUCCESS"
    _cus_list=""
    if [ -d "$USER_SKILLS_D" ]; then
        for _cus_entry in "${USER_SKILLS_D}"/*; do
            if [ -L "$_cus_entry" ] || [ -d "$_cus_entry" ]; then
                _cus_name="${_cus_entry##*/}"
                if _valid_skill_name "$_cus_name"; then
                    _cus_list="${_cus_list} ${_cus_name}"
                fi
            fi
        done
    fi
    printf '%s\n' "${_cus_list# }"
    return "$_cus_rc"
}

###
# Resolve where an equipped skill has been forged from
# ARGUMENTS:
#   1 - path : entry of the enclave, a symlink or a copied directory
# GLOBALS:
#   read: MARKER_F
# OUTPUTS:
#   stdout : the system directory the skill comes from, empty when unknown
# RETURNS:
#   SUCCESS, FAILURE when the origin cannot be resolved
###
_equipped_src() {
    _es_rc="$SUCCESS"
    _es_src=""
    if [ -L "$1" ]; then
        _es_src=$(readlink "$1")
    elif [ -r "${1}/${MARKER_F}" ]; then
        _es_src=$(head -n 1 "${1}/${MARKER_F}")
    fi
    if [ -z "$_es_src" ]; then
        _es_rc="$FAILURE"
    fi
    printf '%s\n' "$_es_src"
    return "$_es_rc"
}

###
# Tell whether the given path is a skill forged by sindrai
# ARGUMENTS:
#   1 - path : entry of the enclave to check
# GLOBALS:
#   read: SKILLS_PATH
# RETURNS:
#   SUCCESS when the entry comes from the system search path, FAILURE when it
#   is foreign or when its origin cannot be resolved
###
_is_managed() {
    _im_rc="$FAILURE"
    if _im_src=$(_equipped_src "$1"); then
        for _im_dir in $SKILLS_PATH; do
            case "$_im_src" in
                "${_im_dir}"/*) _im_rc="$SUCCESS" ;;
            esac
        done
    fi
    return "$_im_rc"
}

###
# Create the user skill directory of the enclave when it is missing
# GLOBALS:
#   read: USER_SKILLS_D
# OUTPUTS:
#   fd 3 : the progress and the error messages
# RETURNS:
#   SUCCESS, FAILURE when the directory cannot be created
###
_mkdir_user_skills_d() {
    _mus_rc="$SUCCESS"
    if [ ! -d "$USER_SKILLS_D" ]; then
        if mkdir -p "$USER_SKILLS_D"; then
            print_debug "Created ${USER_SKILLS_D}"
        else
            print_error "Cannot create ${USER_SKILLS_D}"
            _mus_rc="$FAILURE"
        fi
    fi
    return "$_mus_rc"
}

###
# Drop an equipped skill from the enclave, the system copy is left alone
# ARGUMENTS:
#   1 - path : entry of the enclave to remove
# RETURNS:
#   SUCCESS, FAILURE when the entry cannot be removed
###
_drop_equipped() {
    _de_rc="$SUCCESS"
    if [ -d "$1" ]; then
        rm -rf "$1" || _de_rc="$FAILURE"
    else
        rm -f "$1" || _de_rc="$FAILURE"
    fi
    return "$_de_rc"
}

###
# Copy a skill tree into the enclave and mark it as forged by sindrai
# ARGUMENTS:
#   1 - src : system directory holding the skill
#   2 - dst : destination directory in the enclave
# GLOBALS:
#   read: MARKER_F
# OUTPUTS:
#   fd 3 : the progress and the error messages
# RETURNS:
#   SUCCESS, FAILURE when the tree cannot be copied
###
_copy_skill() {
    _cps_rc="$SUCCESS"
    if ! mkdir -p "$2"; then
        print_error "Cannot create '${2}'."
        _cps_rc="$FAILURE"
    elif ! cp -R "${1}/." "${2}/"; then
        print_error "Cannot copy '${1}' into '${2}'."
        rm -rf "$2"
        _cps_rc="$FAILURE"
    else
        chmod -R u+w "$2" 2>/dev/null || \
            print_warning "Cannot make '${2}' writable."
        printf '%s\n' "$1" > "${2}/${MARKER_F}"
        print_debug "Copied ${1} into ${2}"
    fi
    return "$_cps_rc"
}

###
# Forge one system skill into the user enclave, link or copy mode
# ARGUMENTS:
#   1 - name : skill name to equip
# GLOBALS:
#   read: FORCE, LINK_MODE, PRJ_ID, USER_SKILLS_D
# OUTPUTS:
#   fd 3 : the progress and the error messages
# RETURNS:
#   SUCCESS, FAILURE when the skill cannot be forged
###
_equip_one() {
    _eo_rc="$SUCCESS"
    _eo_name="$1"
    _eo_src=""
    _eo_dst="${USER_SKILLS_D}/${_eo_name}"
    if ! _valid_skill_name "$_eo_name"; then
        print_error "Invalid skill name: '${_eo_name}'"
        _eo_rc="$FAILURE"
    elif ! _eo_src=$(_find_skill "$_eo_name"); then
        print_error "Unknown skill: '${_eo_name}'. \
See '${PRJ_ID} list' for the available ones."
        _eo_rc="$FAILURE"
    elif [ -e "$_eo_dst" ] || [ -L "$_eo_dst" ]; then
        # An unresolvable origin gives an empty value, never a false match.
        _eo_cur=$(_equipped_src "$_eo_dst")
        if [ "$_eo_cur" = "$_eo_src" ] && [ "$FORCE" -eq 0 ]; then
            print_info "Skill '${_eo_name}' is already equipped."
            _eo_src=""
        elif [ "$FORCE" -eq 0 ] && ! _is_managed "$_eo_dst"; then
            print_error "'${_eo_dst}' exists and is not managed by \
${PRJ_ID}. Use --force to overwrite it."
            _eo_rc="$FAILURE"
            _eo_src=""
        elif ! _drop_equipped "$_eo_dst"; then
            print_error "Cannot replace '${_eo_dst}'."
            _eo_rc="$FAILURE"
            _eo_src=""
        fi
    fi
    if [ "$_eo_rc" -eq "$SUCCESS" ] && [ -n "$_eo_src" ]; then
        if [ "$LINK_MODE" = "copy" ]; then
            _copy_skill "$_eo_src" "$_eo_dst" || _eo_rc="$FAILURE"
        elif ln -s "$_eo_src" "$_eo_dst"; then
            print_debug "Linked ${_eo_dst} -> ${_eo_src}"
        else
            print_error "Cannot link '${_eo_dst}'."
            _eo_rc="$FAILURE"
        fi
        if [ "$_eo_rc" -eq "$SUCCESS" ]; then
            print_info "[OK] Skill '${_eo_name}' successfully forged \
into ${_eo_dst}"
        fi
    fi
    return "$_eo_rc"
}

###
# Remove one skill from the user enclave, the system copy is left alone
# ARGUMENTS:
#   1 - name : skill name to unequip
# GLOBALS:
#   read: FORCE, PRJ_ID, USER_SKILLS_D
# OUTPUTS:
#   fd 3 : the progress and the error messages
# RETURNS:
#   SUCCESS, FAILURE when the skill cannot be removed
###
_unequip_one() {
    _uo_rc="$SUCCESS"
    _uo_name="$1"
    if ! _valid_skill_name "$_uo_name"; then
        print_error "Invalid skill name: '${_uo_name}'"
        _uo_rc="$FAILURE"
    else
        _uo_dst="${USER_SKILLS_D}/${_uo_name}"
        if [ ! -e "$_uo_dst" ] && [ ! -L "$_uo_dst" ]; then
            print_error "Skill '${_uo_name}' is not equipped."
            _uo_rc="$FAILURE"
        elif [ "$FORCE" -eq 0 ] && ! _is_managed "$_uo_dst"; then
            print_error "'${_uo_dst}' is not managed by ${PRJ_ID}. \
Use --force to remove it anyway."
            _uo_rc="$FAILURE"
        elif ! _drop_equipped "$_uo_dst"; then
            print_error "Cannot remove '${_uo_dst}'."
            _uo_rc="$FAILURE"
        else
            print_info "[OK] Skill '${_uo_name}' removed from your \
enclave."
        fi
    fi
    return "$_uo_rc"
}

# ==============
# Main functions
# --------------

###
# Read the configuration file, only the whitelisted keys are honoured
# GLOBALS:
#   read : CONF_P
#   write: AGENTS_D, EXTRA_SKILLS_DIRS, LINK_MODE
# OUTPUTS:
#   fd 3 : the ignored keys and the error messages
# RETURNS:
#   SUCCESS, FAILURE when the configuration file is not readable
###
parse_conf() {
    _pc_rc="$SUCCESS"
    if [ ! -r "$CONF_P" ]; then
        print_error "Configuration file not readable: ${CONF_P}"
        _pc_rc="$FAILURE"
    else
        while IFS= read -r _pc_line || [ -n "$_pc_line" ]; do
            # Only 'KEY=value' lines are meaningful, '#' starts a comment.
            case "$_pc_line" in
                ''|'#'*) continue ;;
                *=*) : ;;
                *) continue ;;
            esac
            _pc_key="${_pc_line%%=*}"
            _pc_val="${_pc_line#*=}"
            # Trim the blanks and the optional surrounding quotes.
            _pc_key=$(printf '%s' "$_pc_key" | sed 's/[[:space:]]//g')
            _pc_val=$(printf '%s' "$_pc_val" | \
                sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                    -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/")
            case "$_pc_key" in
                AGENTS_D)          AGENTS_D="$_pc_val"          ;;
                EXTRA_SKILLS_DIRS) EXTRA_SKILLS_DIRS="$_pc_val" ;;
                LINK_MODE)         LINK_MODE="$_pc_val"         ;;
                *)
                    print_warning "Ignored configuration key: ${_pc_key}"
                    ;;
            esac
        done < "$CONF_P"
        print_debug "Configuration read from ${CONF_P}"
    fi
    return "$_pc_rc"
}

###
# Compute the system and the user skill directories, run after the parsing
# GLOBALS:
#   read : AGENTS_D, DATA_D, EXTRA_SKILLS_DIRS, SKILLS_D_NAME
#   write: SKILLS_PATH, USER_SKILLS_D
# OUTPUTS:
#   fd 3 : the resolved paths and the error messages
# RETURNS:
#   SUCCESS, FAILURE when the agents directory is empty
###
resolve_paths() {
    _rp_rc="$SUCCESS"
    if [ -z "$AGENTS_D" ]; then
        print_error "Empty agents directory, cannot continue."
        _rp_rc="$FAILURE"
    else
        SKILLS_PATH="${DATA_D}/${SKILLS_D_NAME}"
        USER_SKILLS_D="${AGENTS_D}/${SKILLS_D_NAME}"
        if [ -n "$EXTRA_SKILLS_DIRS" ]; then
            SKILLS_PATH="${SKILLS_PATH} ${EXTRA_SKILLS_DIRS}"
        fi
        print_debug "System skills path: ${SKILLS_PATH}"
        print_debug "User skills dir   : ${USER_SKILLS_D}"
    fi
    return "$_rp_rc"
}

###
# Print the version information
# GLOBALS:
#   read: PRJ_ID, VERSION
# OUTPUTS:
#   stdout : the version line
# RETURNS:
#   SUCCESS
###
print_version() {
    _pv_rc="$SUCCESS"
    printf "%s version: %s\n" "${PRJ_ID}" "$VERSION"
    return "$_pv_rc"
}

###
# Print the usage information
# GLOBALS:
#   read: AGENTS_D_DEFAULT, DATA_D_DEFAULT, PRJ_ID, SKILLS_D_NAME
# OUTPUTS:
#   stdout : the usage block
# RETURNS:
#   SUCCESS
###
usage() {
    _usage_rc="$SUCCESS"
    _usage_str="Usage: ${PRJ_ID} [-q|-v|-h] <action> [skill...] [options]
  -q, --quiet     Suppress all output except errors
  -v, --verbose   Enable verbose output
  -vv             Enable verbose and debug output
  --version       Show version information and exit
  -h, --help      Show this help message and exit

Actions:
  list            List the skills available system wide
  install         Forge the given skills into your agent enclave
  remove          Remove the given skills from your agent enclave
  status          Show the skills currently equipped in your enclave

Options:
  -a, --all       Apply the action to every skill
  -f, --force     Overwrite or remove entries not managed by ${PRJ_ID}
  --copy          Copy the skill tree instead of symlinking it
  --link          Symlink the skill tree, the default
  --target <dir>  Agent enclave directory, default '${AGENTS_D_DEFAULT}'
  --claude        Use Claude agent dir: ${CLAUDE_AGENT_D}
  --gemini        Use Gemini agent dir: ${GEMINI_AGENT_D}
  --opencode      Use Opencode agent dir: ${OPENCODE_AGENT_D}
  --copilot       Use Copilot agent dir: ${COPILOT_AGENT_D}
  --conf <file>   Configuration file to read. See Notes.

  Notes:
  - System skills are read from '${DATA_D_DEFAULT}/${SKILLS_D_NAME}' and are
    equipped into '<target>/${SKILLS_D_NAME}'.
  - ${PRJ_ID} never needs root privileges, it only writes in your own
    enclave directory.
  - The log messages are written on the file descriptor 3, the standard
    error by default. Set PRINTER_SINK to 'tty', or to 'file' along with
    PRINTER_FILE, to send them elsewhere.
  - The configuration file is a list of 'KEY=value' lines, '#' starts a
    comment. Recognised keys:
      AGENTS_D            Agent enclave directory
      EXTRA_SKILLS_DIRS   Additional system skill directories, space
                          separated
      LINK_MODE           'link' or 'copy'
"
    printf "%s\n" "$_usage_str"
    return "$_usage_rc"
}

# =================
# Actions functions
# -----------------

###
# List the skills available in the system wide repositories
# GLOBALS:
#   read: SKILLS_PATH
# OUTPUTS:
#   fd 3   : the skipped directories and the warnings
#   stdout : the report of the available skills
# RETURNS:
#   SUCCESS, FAILURE when a repository cannot be listed
###
list() {
    _list_rc="$SUCCESS"
    _list_found=0
    for _list_d in $SKILLS_PATH; do
        if [ ! -d "$_list_d" ]; then
            print_debug "Skipped missing directory: ${_list_d}"
        else
            printf "Available system skills (%s/):\n" "$_list_d"
            _list_names=$(_list_dir_skills "$_list_d") || _list_rc="$FAILURE"
            for _list_name in $_list_names; do
                _list_ver=$(_skill_field "${_list_d}/${_list_name}" \
                    "version" "n/a") || _list_rc="$FAILURE"
                _list_desc=$(_skill_field "${_list_d}/${_list_name}" \
                    "description" "no description") || _list_rc="$FAILURE"
                printf "  - %-16s (v%s) - %s\n" "$_list_name" \
                    "$_list_ver" "$_list_desc"
                _list_found=$((_list_found + 1))
            done
        fi
    done
    if [ "$_list_found" -eq 0 ]; then
        print_warning "No system skill found in: ${SKILLS_PATH}"
    fi
    return "$_list_rc"
}

###
# Forge the requested skills into the user enclave
# GLOBALS:
#   read : ALL, PRJ_ID
#   write: SKILLS
# OUTPUTS:
#   fd 3 : the progress and the error messages
# RETURNS:
#   SUCCESS, FAILURE when at least one skill cannot be forged
###
install() {
    _install_rc="$SUCCESS"
    if [ "$ALL" -eq 1 ]; then
        SKILLS=$(_collect_sys_skills) || _install_rc="$FAILURE"
    fi
    if [ -z "$SKILLS" ]; then
        print_error "No skill given. See '${PRJ_ID} list' or use --all."
        _install_rc="$FAILURE"
    elif ! _mkdir_user_skills_d; then
        _install_rc="$FAILURE"
    else
        for _install_name in $SKILLS; do
            _equip_one "$_install_name" || _install_rc="$FAILURE"
        done
    fi
    return "$_install_rc"
}

###
# Remove the requested skills from the user enclave
# GLOBALS:
#   read : ALL, PRJ_ID
#   write: SKILLS
# OUTPUTS:
#   fd 3 : the progress and the error messages
# RETURNS:
#   SUCCESS, FAILURE when at least one skill cannot be removed
###
remove() {
    _remove_rc="$SUCCESS"
    if [ "$ALL" -eq 1 ]; then
        SKILLS=$(_collect_user_skills) || _remove_rc="$FAILURE"
    fi
    if [ -z "$SKILLS" ]; then
        print_error "No skill given. See '${PRJ_ID} status' or use --all."
        _remove_rc="$FAILURE"
    else
        for _remove_name in $SKILLS; do
            _unequip_one "$_remove_name" || _remove_rc="$FAILURE"
        done
    fi
    return "$_remove_rc"
}

###
# Show the skills currently equipped in the user enclave
# GLOBALS:
#   read: PRJ_ID, USER_SKILLS_D
# OUTPUTS:
#   stdout : the report of the equipped skills
# RETURNS:
#   SUCCESS, FAILURE when the enclave cannot be listed
###
status() {
    _status_rc="$SUCCESS"
    printf "Equipped skills in %s/:\n" "$USER_SKILLS_D"
    _status_skills=$(_collect_user_skills) || _status_rc="$FAILURE"
    if [ -z "$_status_skills" ]; then
        printf "  (none)\n"
    else
        for _status_name in $_status_skills; do
            _status_p="${USER_SKILLS_D}/${_status_name}"
            if _status_src=$(_equipped_src "$_status_p"); then
                if _is_managed "$_status_p"; then
                    printf "  - %s -> %s\n" "$_status_name" "$_status_src"
                else
                    printf "  - %s -> %s (foreign)\n" "$_status_name" \
                        "$_status_src"
                fi
            else
                printf "  - %s (local, not managed by %s)\n" \
                    "$_status_name" "$PRJ_ID"
            fi
        done
    fi
    return "$_status_rc"
}

# ===========
# Entry point
# -----------

_check_tools_needed || {
    print_error "Please install the missing tools and try again. Aborting."
    exit "$FAILURE"
}

# The default configuration file is read first so the command line wins.
if [ -r "$CONF_P" ]; then
    parse_conf || exit "$FAILURE"
fi

while [ $# -gt 0 ]; do
    case "$1" in
        help|--help|-h)             usage;              exit 0  ;;
        verbose|--verbose|-v)       VERBOSE=1;          shift 1 ;;
        -vv)                        VERBOSE=1; DEBUG=1; shift 1 ;;
        quiet|--quiet|-q)           QUIET=1;            shift 1 ;;
        version|--version)          print_version;      exit 0  ;;
        list|install|remove|status) ACTION="$1";        shift 1 ;;
        all|--all|-a)               ALL=1;              shift 1 ;;
        force|--force|-f)           FORCE=1;            shift 1 ;;
        copy|--copy)                LINK_MODE="copy";   shift 1 ;;
        link|--link)                LINK_MODE="link";   shift 1 ;;
        --target|-t)
            if [ -z "$2" ]; then
                print_error "Error: $1 requires an argument."
                exit "$FAILURE"
            fi
            AGENTS_D="$2"
            shift 2
            ;;
        --claude)                   AGENTS_D="${CLAUDE_AGENT_D}";   shift 1 ;;
        --gemini)                   AGENTS_D="${GEMINI_AGENT_D}";   shift 1 ;;
        --opencode)                 AGENTS_D="${OPENCODE_AGENT_D}"; shift 1 ;;
        --copilot)                  AGENTS_D="${COPILOT_AGENT_D}";  shift 1 ;;
        --conf)
            if [ -z "$2" ]; then
                print_error "Error: $1 requires an argument."
                exit "$FAILURE"
            fi
            CONF_P="$2"
            if ! parse_conf; then
                print_error "Failed to parse configuration file: $CONF_P"
                exit "$FAILURE"
            fi
            shift 2
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit "$FAILURE"
            ;;
        *)
            SKILLS="${SKILLS} ${1}"
            shift 1
            ;;
    esac
done

if [ -z "$ACTION" ]; then
    print_error "No action given."
    usage
    exit "$FAILURE"
fi

case "$LINK_MODE" in
    link|copy) : ;;
    *)
        print_error "Invalid link mode: '${LINK_MODE}'. Use 'link' or 'copy'."
        exit "$FAILURE"
        ;;
esac

resolve_paths || exit "$FAILURE"

# Trim the leading separator left by the arguments parsing.
SKILLS="${SKILLS# }"

if [ -n "$SKILLS" ] && [ "$ACTION" = "list" ]; then
    print_warning "Action 'list' takes no skill argument, ignoring: ${SKILLS}"
fi

[ "$DEBUG" -eq 1 ] && set -x

_action_rc="$SUCCESS"
case "$ACTION" in
    list)    list    || _action_rc="$FAILURE" ;;
    install) install || _action_rc="$FAILURE" ;;
    remove)  remove  || _action_rc="$FAILURE" ;;
    status)  status  || _action_rc="$FAILURE" ;;
esac

if [ "$_action_rc" -ne "$SUCCESS" ]; then
    print_error "[✗] Action '$ACTION' failed."
    exit "$FAILURE"
else
    print_info "[✓] Done."
fi

exit "$SUCCESS"
