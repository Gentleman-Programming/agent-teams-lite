#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Agent Teams Lite — Install Script
# Copies skills to your AI coding assistant's skill directory
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_SRC="$REPO_DIR/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      Agent Teams Lite — Installer        ║${NC}"
    echo -e "${CYAN}${BOLD}║   Spec-Driven Development for AI Agents  ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

print_skill() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_engram_note() {
    echo -e "\n${YELLOW}Recommended persistence backend:${NC} ${BOLD}Engram${NC}"
    echo -e "  ${CYAN}https://github.com/gentleman-programming/engram${NC}"
    echo -e "  If Engram is available, it will be used automatically (recommended)"
    echo -e "  If not, falls back to ${BOLD}none${NC} — enable ${BOLD}engram${NC} or ${BOLD}openspec${NC} for better results"
}

install_skills() {
    local target_dir="$1"
    local tool_name="$2"

    echo -e "\n${BLUE}Installing skills for ${BOLD}$tool_name${NC}${BLUE}...${NC}"

    mkdir -p "$target_dir"

    local count=0
    for skill_dir in "$SKILLS_SRC"/sdd-*/; do
        local skill_name
        skill_name=$(basename "$skill_dir")
        mkdir -p "$target_dir/$skill_name"
        cp "$skill_dir/SKILL.md" "$target_dir/$skill_name/SKILL.md"
        print_skill "$skill_name"
        count=$((count + 1))
    done

    echo -e "\n  ${GREEN}${BOLD}$count skills installed${NC} → $target_dir"
}

install_opencode_commands() {
    local commands_src="$REPO_DIR/examples/opencode/commands"
    local commands_target="$HOME/.config/opencode/commands"

    echo -e "\n${BLUE}Installing OpenCode commands...${NC}"

    mkdir -p "$commands_target"

    local count=0
    for cmd_file in "$commands_src"/sdd-*.md; do
        local cmd_name
        cmd_name=$(basename "$cmd_file")
        cp "$cmd_file" "$commands_target/$cmd_name"
        print_skill "${cmd_name%.md}"
        count=$((count + 1))
    done

    echo -e "\n  ${GREEN}${BOLD}$count commands installed${NC} → $commands_target"
}

# ============================================================================
# Main
# ============================================================================

print_header

echo -e "${BOLD}Select your AI coding assistant:${NC}\n"
echo "  1) Claude Code    (~/.claude/skills/)"
echo "  2) OpenCode       (~/.config/opencode/skill/)"
echo "  3) Cursor         (~/.cursor/skills/)"
echo "  4) Project-local  (./skills/ in current directory)"
echo "  5) All global     (Claude Code + OpenCode + Cursor)"
echo "  6) Custom path"
echo ""
read -rp "Choice [1-6]: " choice

case $choice in
    1)
        install_skills "$HOME/.claude/skills" "Claude Code"
        echo -e "\n${YELLOW}Next step:${NC} Add the orchestrator to your ${BOLD}~/.claude/CLAUDE.md${NC}"
        echo -e "  See: ${CYAN}examples/claude-code/CLAUDE.md${NC}"
        ;;
    2)
        install_skills "$HOME/.config/opencode/skill" "OpenCode"
        install_opencode_commands
        echo -e "\n${YELLOW}Next step:${NC} Add the orchestrator agent to your ${BOLD}~/.config/opencode/opencode.json${NC}"
        echo -e "  See: ${CYAN}examples/opencode/opencode.json${NC}"
        ;;
    3)
        install_skills "$HOME/.cursor/skills" "Cursor"
        echo -e "\n${YELLOW}Next step:${NC} Add SDD rules to your ${BOLD}.cursorrules${NC}"
        echo -e "  See: ${CYAN}examples/cursor/.cursorrules${NC}"
        ;;
    4)
        install_skills "./skills" "Project-local"
        echo -e "\n${YELLOW}Note:${NC} Skills installed in ${BOLD}./skills/${NC} — relative to this project"
        ;;
    5)
        install_skills "$HOME/.claude/skills" "Claude Code"
        install_skills "$HOME/.config/opencode/skill" "OpenCode"
        install_opencode_commands
        install_skills "$HOME/.cursor/skills" "Cursor"
        echo -e "\n${YELLOW}Next steps:${NC}"
        echo -e "  1. Add orchestrator to ${BOLD}~/.claude/CLAUDE.md${NC}"
        echo -e "  2. Add orchestrator agent to ${BOLD}~/.config/opencode/opencode.json${NC}"
        echo -e "  3. Add SDD rules to ${BOLD}.cursorrules${NC}"
        ;;
    6)
        read -rp "Enter target path: " custom_path
        install_skills "$custom_path" "Custom"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo -e "\n${GREEN}${BOLD}Done!${NC} Start using SDD with: ${CYAN}/sdd-init${NC} in your project\n"
print_engram_note
echo ""
