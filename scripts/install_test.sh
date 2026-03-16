#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Agent Teams Lite — Install Script Tests
# Run: bash scripts/install_test.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

# ============================================================================
# Test state
# ============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# All 12 expected skills
EXPECTED_SKILLS=(
    sdd-apply
    sdd-archive
    sdd-design
    sdd-explore
    sdd-init
    sdd-propose
    sdd-spec
    sdd-tasks
    sdd-verify
    skill-registry
    branch-pr
    issue-creation
)

# ============================================================================
# Test helpers
# ============================================================================

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export HOME="$TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # Fake Windows-style env vars for cross-platform path tests
    export USERPROFILE="$TEST_TMPDIR/home"
    export APPDATA="$TEST_TMPDIR/appdata"
    mkdir -p "$APPDATA"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    if [[ "$expected" == "$actual" ]]; then
        return 0
    fi
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    [[ -n "$msg" ]] && echo "  Message:  $msg"
    return 1
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    fi
    echo "  File not found: $file"
    return 1
}

assert_dir_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    fi
    echo "  Directory not found: $dir"
    return 1
}

assert_file_not_empty() {
    local file="$1"
    local min_bytes="${2:-100}"
    if [[ ! -f "$file" ]]; then
        echo "  File not found: $file"
        return 1
    fi
    local size
    size=$(wc -c < "$file" | tr -d ' ')
    if [[ "$size" -lt "$min_bytes" ]]; then
        echo "  File too small: $file ($size bytes, expected >= $min_bytes)"
        return 1
    fi
    return 0
}

assert_all_skills_installed() {
    local base_dir="$1"
    for skill in "${EXPECTED_SKILLS[@]}"; do
        assert_dir_exists "$base_dir/$skill" || return 1
        assert_file_exists "$base_dir/$skill/SKILL.md" || return 1
        assert_file_not_empty "$base_dir/$skill/SKILL.md" || return 1
    done
    return 0
}

run_test() {
    local name="$1"
    local func="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    echo -n "  $name ... "
    local output
    if output=$($func 2>&1); then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        if [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/    /'
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILURES="$FAILURES\n  - $name"
    fi
    teardown
}

# ============================================================================
# Tests — Help & Error Handling
# ============================================================================

test_help_flag() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1)
    echo "$output" | grep -q "Usage:" || { echo "Help output missing 'Usage:'"; return 1; }
    echo "$output" | grep -q "claude-code" || { echo "Help output missing 'claude-code'"; return 1; }
    echo "$output" | grep -q "opencode" || { echo "Help output missing 'opencode'"; return 1; }
    echo "$output" | grep -q "all-global" || { echo "Help output missing 'all-global'"; return 1; }
    echo "$output" | grep -q "\-\-agent" || { echo "Help output missing '--agent'"; return 1; }
    echo "$output" | grep -q "\-\-path" || { echo "Help output missing '--path'"; return 1; }
}

test_help_exits_zero() {
    bash "$INSTALL_SCRIPT" --help > /dev/null 2>&1
    # If we get here, exit code was 0
    return 0
}

test_invalid_agent() {
    if bash "$INSTALL_SCRIPT" --agent nonexistent > /dev/null 2>&1; then
        echo "Expected non-zero exit for invalid agent, but got 0"
        return 1
    fi
    return 0
}

test_invalid_option() {
    if bash "$INSTALL_SCRIPT" --bogus-flag > /dev/null 2>&1; then
        echo "Expected non-zero exit for unknown option, but got 0"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — Claude Code
# ============================================================================

test_install_claude_code() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.claude/skills"
}

test_claude_code_skill_count() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local count
    count=$(find "$HOME/.claude/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for Claude Code"
}

# ============================================================================
# Tests — OpenCode
# ============================================================================

test_install_opencode() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.config/opencode/skills"
}

test_opencode_skill_count() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    local count
    count=$(find "$HOME/.config/opencode/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for OpenCode"
}

test_opencode_commands() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    local commands_dir="$HOME/.config/opencode/commands"
    assert_dir_exists "$commands_dir" || return 1
    assert_file_exists "$commands_dir/sdd-init.md" || return 1
    assert_file_exists "$commands_dir/sdd-apply.md" || return 1
    assert_file_exists "$commands_dir/sdd-explore.md" || return 1
    assert_file_exists "$commands_dir/sdd-verify.md" || return 1
    assert_file_exists "$commands_dir/sdd-archive.md" || return 1
    assert_file_exists "$commands_dir/sdd-new.md" || return 1
    assert_file_exists "$commands_dir/sdd-ff.md" || return 1
    assert_file_exists "$commands_dir/sdd-continue.md" || return 1
    local count
    count=$(find "$commands_dir" -name "sdd-*.md" | wc -l | tr -d ' ')
    assert_eq "8" "$count" "Expected exactly 8 OpenCode commands"
}

# ============================================================================
# Tests — Gemini CLI
# ============================================================================

test_install_gemini_cli() {
    bash "$INSTALL_SCRIPT" --agent gemini-cli > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.gemini/skills"
}

test_gemini_cli_skill_count() {
    bash "$INSTALL_SCRIPT" --agent gemini-cli > /dev/null 2>&1
    local count
    count=$(find "$HOME/.gemini/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for Gemini CLI"
}

# ============================================================================
# Tests — Codex
# ============================================================================

test_install_codex() {
    bash "$INSTALL_SCRIPT" --agent codex > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.codex/skills"
}

test_codex_skill_count() {
    bash "$INSTALL_SCRIPT" --agent codex > /dev/null 2>&1
    local count
    count=$(find "$HOME/.codex/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for Codex"
}

# ============================================================================
# Tests — VS Code (project-local .vscode/)
# ============================================================================

test_install_vscode() {
    local project="$TEST_TMPDIR/vscode-project"
    mkdir -p "$project"
    (cd "$project" && bash "$INSTALL_SCRIPT" --agent vscode > /dev/null 2>&1)
    assert_all_skills_installed "$project/.vscode/skills"
}

test_vscode_skill_count() {
    local project="$TEST_TMPDIR/vscode-project"
    mkdir -p "$project"
    (cd "$project" && bash "$INSTALL_SCRIPT" --agent vscode > /dev/null 2>&1)
    local count
    count=$(find "$project/.vscode/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for VS Code"
}

# ============================================================================
# Tests — Antigravity (~/.gemini/antigravity/skills/)
# ============================================================================

test_install_antigravity() {
    bash "$INSTALL_SCRIPT" --agent antigravity > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.gemini/antigravity/skills"
}

test_antigravity_skill_count() {
    bash "$INSTALL_SCRIPT" --agent antigravity > /dev/null 2>&1
    local count
    count=$(find "$HOME/.gemini/antigravity/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for Antigravity"
}

# ============================================================================
# Tests — Cursor
# ============================================================================

test_install_cursor() {
    bash "$INSTALL_SCRIPT" --agent cursor > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.cursor/skills"
}

test_cursor_skill_count() {
    bash "$INSTALL_SCRIPT" --agent cursor > /dev/null 2>&1
    local count
    count=$(find "$HOME/.cursor/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for Cursor"
}

# ============================================================================
# Tests — Project-local
# ============================================================================

test_install_project_local() {
    local project="$TEST_TMPDIR/local-project"
    mkdir -p "$project"
    (cd "$project" && bash "$INSTALL_SCRIPT" --agent project-local > /dev/null 2>&1)
    assert_all_skills_installed "$project/skills"
}

test_project_local_skill_count() {
    local project="$TEST_TMPDIR/local-project"
    mkdir -p "$project"
    (cd "$project" && bash "$INSTALL_SCRIPT" --agent project-local > /dev/null 2>&1)
    local count
    count=$(find "$project/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for project-local"
}

# ============================================================================
# Tests — Custom path
# ============================================================================

test_custom_path() {
    local custom="$TEST_TMPDIR/custom-skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$custom" > /dev/null 2>&1
    assert_all_skills_installed "$custom"
}

test_custom_path_skill_count() {
    local custom="$TEST_TMPDIR/custom-skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$custom" > /dev/null 2>&1
    local count
    count=$(find "$custom" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills for custom path"
}

# ============================================================================
# Tests — All-global
# ============================================================================

test_all_global() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    # Claude Code
    assert_all_skills_installed "$HOME/.claude/skills" || return 1
    # OpenCode
    assert_all_skills_installed "$HOME/.config/opencode/skills" || return 1
    # Gemini CLI
    assert_all_skills_installed "$HOME/.gemini/skills" || return 1
    # Codex
    assert_all_skills_installed "$HOME/.codex/skills" || return 1
    # Cursor
    assert_all_skills_installed "$HOME/.cursor/skills" || return 1
}

test_all_global_total_skill_count() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    # 5 targets × 12 skills = 60 SKILL.md files
    local total=0
    for dir in \
        "$HOME/.claude/skills" \
        "$HOME/.config/opencode/skills" \
        "$HOME/.gemini/skills" \
        "$HOME/.codex/skills" \
        "$HOME/.cursor/skills"; do
        local count
        count=$(find "$dir" -name "SKILL.md" | wc -l | tr -d ' ')
        assert_eq "12" "$count" "Expected 12 skills in $dir" || return 1
        total=$((total + count))
    done
    assert_eq "60" "$total" "Expected 60 total SKILL.md files across all targets"
}

test_all_global_opencode_commands() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    local commands_dir="$HOME/.config/opencode/commands"
    assert_dir_exists "$commands_dir" || return 1
    local count
    count=$(find "$commands_dir" -name "sdd-*.md" | wc -l | tr -d ' ')
    assert_eq "8" "$count" "Expected 8 OpenCode commands with all-global"
}

# ============================================================================
# Tests — Idempotency
# ============================================================================

test_idempotent_claude_code() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.claude/skills"
    local count
    count=$(find "$HOME/.claude/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$count" "Expected exactly 12 skills after double install"
}

test_idempotent_opencode() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.config/opencode/skills" || return 1
    local skill_count
    skill_count=$(find "$HOME/.config/opencode/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "12" "$skill_count" "Expected exactly 12 skills after double install" || return 1
    local cmd_count
    cmd_count=$(find "$HOME/.config/opencode/commands" -name "sdd-*.md" | wc -l | tr -d ' ')
    assert_eq "8" "$cmd_count" "Expected exactly 8 commands after double install"
}

test_idempotent_all_global() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    for dir in \
        "$HOME/.claude/skills" \
        "$HOME/.config/opencode/skills" \
        "$HOME/.gemini/skills" \
        "$HOME/.codex/skills" \
        "$HOME/.cursor/skills"; do
        local count
        count=$(find "$dir" -name "SKILL.md" | wc -l | tr -d ' ')
        assert_eq "12" "$count" "Expected 12 skills in $dir after double install" || return 1
    done
}

# ============================================================================
# Tests — Content integrity
# ============================================================================

test_skill_content_matches_source() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local source_dir="$REPO_DIR/skills"
    for skill in "${EXPECTED_SKILLS[@]}"; do
        local src="$source_dir/$skill/SKILL.md"
        local dst="$HOME/.claude/skills/$skill/SKILL.md"
        if ! diff -q "$src" "$dst" > /dev/null 2>&1; then
            echo "Content mismatch: $skill/SKILL.md"
            echo "  Source: $src"
            echo "  Dest:   $dst"
            return 1
        fi
    done
    return 0
}

test_opencode_command_content_matches_source() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    local source_dir="$REPO_DIR/examples/opencode/commands"
    local target_dir="$HOME/.config/opencode/commands"
    for cmd_file in "$source_dir"/sdd-*.md; do
        local name
        name=$(basename "$cmd_file")
        if ! diff -q "$cmd_file" "$target_dir/$name" > /dev/null 2>&1; then
            echo "Content mismatch: commands/$name"
            return 1
        fi
    done
    return 0
}

# ============================================================================
# Tests — Output verification
# ============================================================================

test_output_shows_skill_names() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    for skill in "${EXPECTED_SKILLS[@]}"; do
        echo "$output" | grep -q "$skill" || {
            echo "Output missing skill name: $skill"
            return 1
        }
    done
    return 0
}

test_output_shows_done_message() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Done!" || {
        echo "Output missing 'Done!' message"
        return 1
    }
}

test_output_shows_install_count() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "12 skills installed" || {
        echo "Output missing '12 skills installed' message"
        return 1
    }
}

test_output_shows_next_step() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Next step" || {
        echo "Output missing 'Next step' guidance"
        return 1
    }
}

test_output_shows_engram_note() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Engram" || {
        echo "Output missing Engram recommendation"
        return 1
    }
}

# ============================================================================
# Tests — OS detection (limited — we can only test the current OS)
# ============================================================================

test_os_detection_runs() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1 || true)
    [[ -n "$output" ]] || { echo "No output from --help"; return 1; }
}

test_header_shows_detected_os() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Detected:" || {
        echo "Output missing 'Detected:' OS label"
        return 1
    }
}

# ============================================================================
# Tests — Edge cases
# ============================================================================

test_pre_existing_dir_not_clobbered() {
    # Create a pre-existing file that should NOT be deleted
    mkdir -p "$HOME/.claude/skills/my-custom-skill"
    echo "custom content" > "$HOME/.claude/skills/my-custom-skill/SKILL.md"
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    # SDD skills should be installed
    assert_all_skills_installed "$HOME/.claude/skills" || return 1
    # Custom skill should still exist
    assert_file_exists "$HOME/.claude/skills/my-custom-skill/SKILL.md" || return 1
    local content
    content=$(cat "$HOME/.claude/skills/my-custom-skill/SKILL.md")
    assert_eq "custom content" "$content" "Custom skill content should be preserved"
}

test_overwrite_stale_skill() {
    # Pre-create a stale SKILL.md
    mkdir -p "$HOME/.claude/skills/sdd-apply"
    echo "stale" > "$HOME/.claude/skills/sdd-apply/SKILL.md"
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    # Should be replaced with actual content (not "stale")
    local content
    content=$(head -c 5 "$HOME/.claude/skills/sdd-apply/SKILL.md")
    if [[ "$content" == "stale" ]]; then
        echo "SKILL.md was NOT overwritten — still contains stale data"
        return 1
    fi
    assert_file_not_empty "$HOME/.claude/skills/sdd-apply/SKILL.md"
}

test_nested_custom_path() {
    local deep="$TEST_TMPDIR/a/b/c/d/skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$deep" > /dev/null 2>&1
    assert_all_skills_installed "$deep"
}

# ============================================================================
# Run all tests
# ============================================================================

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║    Agent Teams Lite — Install Tests      ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}Help & Error Handling${NC}"
run_test "--help flag shows usage info" test_help_flag
run_test "--help exits with code 0" test_help_exits_zero
run_test "Invalid agent exits non-zero" test_invalid_agent
run_test "Unknown option exits non-zero" test_invalid_option
echo ""

echo -e "${BOLD}Claude Code${NC}"
run_test "Installs all 12 skills to ~/.claude/skills" test_install_claude_code
run_test "Exactly 12 SKILL.md files" test_claude_code_skill_count
echo ""

echo -e "${BOLD}OpenCode${NC}"
run_test "Installs all 12 skills to ~/.config/opencode/skills" test_install_opencode
run_test "Exactly 12 SKILL.md files" test_opencode_skill_count
run_test "Installs 8 command files" test_opencode_commands
echo ""

echo -e "${BOLD}Gemini CLI${NC}"
run_test "Installs all 12 skills to ~/.gemini/skills" test_install_gemini_cli
run_test "Exactly 12 SKILL.md files" test_gemini_cli_skill_count
echo ""

echo -e "${BOLD}Codex${NC}"
run_test "Installs all 12 skills to ~/.codex/skills" test_install_codex
run_test "Exactly 12 SKILL.md files" test_codex_skill_count
echo ""

echo -e "${BOLD}VS Code (project-local)${NC}"
run_test "Installs all 12 skills to .vscode/skills/" test_install_vscode
run_test "Exactly 12 SKILL.md files" test_vscode_skill_count
echo ""

echo -e "${BOLD}Antigravity${NC}"
run_test "Installs all 12 skills to ~/.gemini/antigravity/skills/" test_install_antigravity
run_test "Exactly 12 SKILL.md files" test_antigravity_skill_count
echo ""

echo -e "${BOLD}Cursor${NC}"
run_test "Installs all 12 skills to ~/.cursor/skills" test_install_cursor
run_test "Exactly 12 SKILL.md files" test_cursor_skill_count
echo ""

echo -e "${BOLD}Project-local${NC}"
run_test "Installs all 12 skills to ./skills/" test_install_project_local
run_test "Exactly 12 SKILL.md files" test_project_local_skill_count
echo ""

echo -e "${BOLD}Custom path${NC}"
run_test "Installs to arbitrary custom path" test_custom_path
run_test "Exactly 12 SKILL.md files" test_custom_path_skill_count
run_test "Handles deeply nested custom path" test_nested_custom_path
echo ""

echo -e "${BOLD}All-global${NC}"
run_test "Installs to all 5 global targets" test_all_global
run_test "60 total SKILL.md files (5×12)" test_all_global_total_skill_count
run_test "Also installs OpenCode commands" test_all_global_opencode_commands
echo ""

echo -e "${BOLD}Idempotency${NC}"
run_test "Claude Code: double install is safe" test_idempotent_claude_code
run_test "OpenCode: double install is safe" test_idempotent_opencode
run_test "All-global: double install is safe" test_idempotent_all_global
echo ""

echo -e "${BOLD}Content integrity${NC}"
run_test "Skills match source files exactly" test_skill_content_matches_source
run_test "Commands match source files exactly" test_opencode_command_content_matches_source
echo ""

echo -e "${BOLD}Output verification${NC}"
run_test "Output lists all skill names" test_output_shows_skill_names
run_test "Output shows Done! message" test_output_shows_done_message
run_test "Output shows install count" test_output_shows_install_count
run_test "Output shows next-step guidance" test_output_shows_next_step
run_test "Output recommends Engram" test_output_shows_engram_note
echo ""

echo -e "${BOLD}OS detection${NC}"
run_test "--help runs without error" test_os_detection_runs
run_test "Header shows detected OS" test_header_shows_detected_os
echo ""

echo -e "${BOLD}Edge cases${NC}"
run_test "Pre-existing custom skill not clobbered" test_pre_existing_dir_not_clobbered
run_test "Stale SKILL.md is overwritten" test_overwrite_stale_skill
echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}Results: $TESTS_PASSED/$TESTS_RUN passed${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}${BOLD}$TESTS_FAILED test(s) failed:${NC}${FAILURES}"
    exit 1
fi
echo -e "${GREEN}${BOLD}All tests passed!${NC}"
echo ""
