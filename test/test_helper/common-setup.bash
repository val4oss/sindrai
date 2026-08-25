#!/usr/bin/env bash

# SINDRAI and PRINTER are read by the test files, not by this helper.
# shellcheck disable=SC2034
_common_setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    # get the containing directory of this file. Use $BATS_TEST_FILENAME
    # instead of ${BASH_SOURCE[0]} or $0, as those point to the location of
    # the bats executable and to the preprocessed file respectively.
    PROJECT_ROOT="$(
        cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd
    )"

    SINDRAI="${SINDRAI:-${PROJECT_ROOT}/src/sindrai.sh}"

    # make the command under test visible to PATH
    PATH="$( dirname "$SINDRAI" ):$PATH"
}

###
# Create good skill
# ARGUMENTS:
#   1 - path : skills dir path
#   2 - name: Name of the skill
#   3 - version: Version of the skill (default: 1.0.0)
# RETURNS:
#   0 in success, 1 in failure
###
_create_good_skill() {
    [ -d "$1" ] || return 1
    [ -d "$2" ] && return 1
    version="$3"
    [ "$version" = "" ] && version="1.0.0"
    mkdir -p "$1/$2"
    {
        echo "---"
        echo "name: $2"
        echo "version: $version"
        echo "description: Nice description of $2"
        echo "---"
        echo ""
        echo "Content of the skill"
    } &> "$1/$2/SKILL.md"
    return 0
}
