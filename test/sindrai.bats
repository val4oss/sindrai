#!/usr/bin/env bats

# =================
# Usefull TEST vars
# -----------------
SINDRAI_TEST_SKILL_NAME="skill-tester"
SINDRAI_TEST_SKILL_VERSION="1.2.3"

# ==============
# Bats functions
# --------------

# Run once before all the tests of this file.
# Two rules here: the standard output is swallowed unless the test fails, use
# '>&3' to see it, and the variables must be exported to reach the tests, as
# setup_file() runs in its own process.
setup_file() {
    SINDRAI_TEST_D="$(mktemp -d)"
    export SINDRAI_TEST_D
    SINDRAI_TEST_EXTRA_D="${SINDRAI_TEST_D}/extra"
    export SINDRAI_TEST_EXTRA_D
    mkdir -p "${SINDRAI_TEST_EXTRA_D}"
    SINDRAI_TEST_AGENT_D="${SINDRAI_TEST_D}/agents"
    export SINDRAI_TEST_AGENT_D
    mkdir -p "${SINDRAI_TEST_AGENT_D}/skills"
    SINDRAI_TEST_CONF="${SINDRAI_TEST_D}/sindrai.conf"
    export SINDRAI_TEST_CONF
    {
        echo "AGENTS_D=${SINDRAI_TEST_AGENT_D}"
        echo "EXTRA_SKILLS_DIRS=\"${SINDRAI_TEST_EXTRA_D}\""
    } &> "${SINDRAI_TEST_CONF}"
}

# Run once after all the tests of this file
teardown_file() {
    rm -rf "$SINDRAI_TEST_D"
}

# Run before each test. The libraries have to be loaded here: a 'load' done in
# setup_file() would not define its functions in the process of the tests.
setup() {
    load 'test_helper/common-setup'
    _common_setup
}

# Run after each test
teardown() {
    #Remove any generated files
    :
}

# ==========
# Unit tests
# ----------

# Test the basic command
@test "can run version" {
    run "$SINDRAI" version
    assert_success
    assert_output --partial "sindrai version:"
}

# Test if the helper prints
@test "can print the helper" {
    run "$SINDRAI" help
    assert_success
    assert_output --partial "Usage: sindrai"
}

# Test if the default user agent dir is used
@test "read correct default agentdir" {
    _ag_d="$HOME/.agents/skills"
    run "$SINDRAI" status
    assert_success
    assert_output --partial "${_ag_d}"
}

# Test if values AGENTS, EXTRA_SKILLS_DIRS can be override:
# 1. conf file
# 2. cli arguments
@test "can dynamically update agents and extra dirs" {
    # Using conf file
    run "${SINDRAI}" --conf "${SINDRAI_TEST_CONF}" status
    assert_success
    assert_output --partial "${SINDRAI_TEST_AGENT_D}/skills"
    run "${SINDRAI}" -q --conf "${SINDRAI_TEST_CONF}" list
    assert_success
    assert_output --partial "Available system skills (${SINDRAI_TEST_EXTRA_D}/):"
    # Using Argument
    run "${SINDRAI}" --target "${SINDRAI_TEST_AGENT_D}" status
    assert_success
    assert_output --partial "${SINDRAI_TEST_AGENT_D}/skills"
}

# Test installing skills
@test "can install skill" {
    if ! _create_good_skill "${SINDRAI_TEST_EXTRA_D}" \
           "${SINDRAI_TEST_SKILL_NAME}" "${SINDRAI_TEST_SKILL_VERSION}"; then
        skip "_create_good_skill: Failed to create a skill"
    fi
    # Test the list if well
    run "${SINDRAI}" --conf "${SINDRAI_TEST_CONF}" list
    assert_success
    assert_output --partial "  - ${SINDRAI_TEST_SKILL_NAME}"
    assert_output --partial "(v${SINDRAI_TEST_SKILL_VERSION})"

    # Install the skill
    run "${SINDRAI}" --conf "${SINDRAI_TEST_CONF}" install "${SINDRAI_TEST_SKILL_NAME}"
    assert_success
    _installed_skill_d="${SINDRAI_TEST_AGENT_D}/skills/${SINDRAI_TEST_SKILL_NAME}"
    [ -d "${_installed_skill_d}" ] || {
        echo "FAILED: skill test ${SINDRAI_TEST_SKILL_NAME} not correctly installed" >&3
        return 1
    }
    [ -L "${_installed_skill_d}" ] || {
        echo "FAILED: skill test ${_installed_skill_d} not a link" >&3
        return 1
    }
}

# Test the status
@test "can status the installed skill" {
    _installed_skill_d="${SINDRAI_TEST_AGENT_D}/skills/${SINDRAI_TEST_SKILL_NAME}"
    [ -d "${_installed_skill_d}" ] || {
        skip "Previous skill not created"
    }
    run "${SINDRAI}" --conf "${SINDRAI_TEST_CONF}" status
    assert_success
    assert_output --partial "Equipped skills in ${SINDRAI_TEST_AGENT_D}/skills/:"
    assert_output --partial "  - ${SINDRAI_TEST_SKILL_NAME} -> ${SINDRAI_TEST_EXTRA_D}/${SINDRAI_TEST_SKILL_NAME}"
}

# Test the remove
@test "can remove the installed skill" {
    _installed_skill_d="${SINDRAI_TEST_AGENT_D}/skills/${SINDRAI_TEST_SKILL_NAME}"
    [ -d "${_installed_skill_d}" ] || {
        skip "Previous skill not created"
    }
    run "${SINDRAI}" --conf "${SINDRAI_TEST_CONF}" remove "${SINDRAI_TEST_SKILL_NAME}"
    assert_success
    [ ! -d "${_installed_skill_d}" ] || {
        echo "FAILED: skill test ${SINDRAI_TEST_SKILL_NAME} isn't removed" >&3
        return 1
    }
}

# Test the install with copy
@test "can install by copying" {
    run "${SINDRAI}" --conf "${SINDRAI_TEST_CONF}" install --copy "${SINDRAI_TEST_SKILL_NAME}"
    assert_success
    _installed_skill_d="${SINDRAI_TEST_AGENT_D}/skills/${SINDRAI_TEST_SKILL_NAME}"
    [ -d "${_installed_skill_d}" ] || {
        echo "FAILED: skill test ${SINDRAI_TEST_SKILL_NAME} not correctly installed" >&3
        return 1
    }
    [ ! -L "${_installed_skill_d}" ] || {
        echo "FAILED: skill test ${_installed_skill_d} is a link" >&3
        return 1
    }

}
