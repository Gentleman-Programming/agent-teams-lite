#Requires -Version 5.1

<#
.SYNOPSIS
    Agent Teams Lite installer for Windows
.DESCRIPTION
    Copies SDD skills to your AI coding assistant's skill directory.
.PARAMETER Agent
    Install for a specific agent (non-interactive).
    Valid values: claude-code, opencode, gemini-cli, codex, vscode, antigravity, cursor, project-local, all-global, custom
.PARAMETER Path
    Custom install path (use with -Agent custom)
.PARAMETER Help
    Show help
.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -Agent claude-code
.EXAMPLE
    .\install.ps1 -Agent custom -Path C:\my\skills
#>

[CmdletBinding()]
param(
    [ValidateSet('claude-code', 'opencode', 'gemini-cli', 'codex', 'vscode',
                 'antigravity', 'cursor', 'windsurf', 'project-local', 'all-global', 'custom')]
    [string]$Agent,
    [string]$Path,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# Path Resolution
# ============================================================================

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoDir = Split-Path -Parent $ScriptRoot
$SkillsSrc = Join-Path $RepoDir 'skills'

$ToolPaths = @{
    'claude-code'        = Join-Path $env:USERPROFILE '.claude\skills'
    'opencode'           = Join-Path $env:USERPROFILE '.config\opencode\skills'
    'opencode-commands'  = Join-Path $env:USERPROFILE '.config\opencode\commands'
    'gemini-cli'         = Join-Path $env:USERPROFILE '.gemini\skills'
    'codex'              = Join-Path $env:USERPROFILE '.codex\skills'
    'vscode'             = Join-Path '.' '.vscode\skills'
    'antigravity'        = Join-Path $env:USERPROFILE '.gemini\antigravity\skills'
    'cursor'             = Join-Path $env:USERPROFILE '.cursor\skills'
    'windsurf'           = Join-Path $env:USERPROFILE '.agents\skills'
    'windsurf-workflows' = Join-Path '.' '.windsurf\workflows'
    'project-local'      = Join-Path '.' 'skills'
}

# ============================================================================
# Display Helpers
# ============================================================================

function Write-Header {
    Write-Host ''
    Write-Host ([char]0x2554 + ([string][char]0x2550 * 42) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ([char]0x2551 + '      Agent Teams Lite - Installer        ' + [char]0x2551) -ForegroundColor Cyan
    Write-Host ([char]0x2551 + '   Spec-Driven Development for AI Agents  ' + [char]0x2551) -ForegroundColor Cyan
    Write-Host ([char]0x255A + ([string][char]0x2550 * 42) + [char]0x255D) -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Detected: Windows (PowerShell $($PSVersionTable.PSVersion))" -ForegroundColor White
    Write-Host ''
}

function Write-Skill {
    param([string]$Name)
    Write-Host '  ' -NoNewline
    Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline
    Write-Host " $Name"
}

function Write-Warn {
    param([string]$Message)
    Write-Host '  ! ' -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host '  ' -NoNewline
    Write-Host ([char]0x2717) -ForegroundColor Red -NoNewline
    Write-Host " $Message"
}

function Write-NextStep {
    param(
        [string]$ConfigFile,
        [string]$ExampleFile
    )
    Write-Host ''
    Write-Host 'Next step: ' -ForegroundColor Yellow -NoNewline
    Write-Host "Add the orchestrator to your " -NoNewline
    Write-Host $ConfigFile -ForegroundColor White
    Write-Host "  See: " -NoNewline
    Write-Host $ExampleFile -ForegroundColor Cyan
}

function Write-EngramNote {
    Write-Host ''
    Write-Host 'Recommended persistence backend: ' -ForegroundColor Yellow -NoNewline
    Write-Host 'Engram' -ForegroundColor White
    Write-Host '  https://github.com/gentleman-programming/engram' -ForegroundColor Cyan
    Write-Host '  If Engram is available, it will be used automatically (recommended)'
    Write-Host '  If not, falls back to ' -NoNewline
    Write-Host 'none' -ForegroundColor White -NoNewline
    Write-Host ' - enable ' -NoNewline
    Write-Host 'engram' -ForegroundColor White -NoNewline
    Write-Host ' or ' -NoNewline
    Write-Host 'openspec' -ForegroundColor White -NoNewline
    Write-Host ' for better results'
}

function Show-Usage {
    Write-Host 'Usage: .\install.ps1 [OPTIONS]'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  -Agent NAME    Install for a specific agent (non-interactive)'
    Write-Host '  -Path DIR      Custom install path (use with -Agent custom)'
    Write-Host '  -Help          Show this help'
    Write-Host ''
    Write-Host 'Agents: claude-code, opencode, gemini-cli, codex, vscode, antigravity, cursor, windsurf, project-local, all-global'
}

# ============================================================================
# Install Functions
# ============================================================================

function Test-SourceTree {
    $missing = 0
    $skillDirs = Get-ChildItem -Path $SkillsSrc -Directory -Filter 'sdd-*'
    foreach ($skillDir in $skillDirs) {
        $skillFile = Join-Path $skillDir.FullName 'SKILL.md'
        if (-not (Test-Path $skillFile)) {
            Write-Err "Missing: $($skillDir.Name)/SKILL.md"
            $missing++
        }
    }
    if (-not (Test-Path (Join-Path $SkillsSrc '_shared'))) {
        Write-Err 'Missing: _shared/ directory'
        $missing++
    }
    if ($missing -gt 0) {
        Write-Host ''
        Write-Host 'Source validation failed. Is this a complete clone of the repository?' -ForegroundColor Red
        Write-Host "  Try: git clone https://github.com/Gentleman-Programming/agent-teams-lite.git" -ForegroundColor Cyan
        Write-Host ''
        exit 1
    }
}

function Install-Skills {
    param(
        [string]$TargetDir,
        [string]$ToolName
    )

    Write-Host ''
    Write-Host "Installing skills for " -ForegroundColor Blue -NoNewline
    Write-Host "$ToolName" -ForegroundColor White -NoNewline
    Write-Host '...' -ForegroundColor Blue

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

    # Copy shared convention files (_shared/)
    $sharedSrc = Join-Path $SkillsSrc '_shared'
    $sharedTarget = Join-Path $TargetDir '_shared'

    if (Test-Path $sharedSrc) {
        New-Item -ItemType Directory -Path $sharedTarget -Force | Out-Null
        $sharedFiles = Get-ChildItem -Path $sharedSrc -Filter '*.md'
        $sharedCount = 0
        foreach ($file in $sharedFiles) {
            Copy-Item -Path $file.FullName -Destination $sharedTarget -Force
            $sharedCount++
        }
        if ($sharedCount -gt 0) {
            Write-Skill "_shared ($sharedCount convention files)"
        } else {
            Write-Warn "_shared directory found but no .md files to copy"
        }
    }

    $count = 0
    $skillDirs = Get-ChildItem -Path $SkillsSrc -Directory -Filter 'sdd-*'

    foreach ($skillDir in $skillDirs) {
        $skillName = $skillDir.Name
        $skillFile = Join-Path $skillDir.FullName 'SKILL.md'

        if (-not (Test-Path $skillFile)) {
            Write-Warn "Skipping $skillName (SKILL.md not found in source)"
            continue
        }

        $targetSkillDir = Join-Path $TargetDir $skillName
        New-Item -ItemType Directory -Path $targetSkillDir -Force | Out-Null

        $targetFile = Join-Path $targetSkillDir 'SKILL.md'
        Copy-Item -Path $skillFile -Destination $targetFile -Force

        Write-Skill $skillName
        $count++
    }

    Write-Host ''
    Write-Host "  $count skills installed" -ForegroundColor Green -NoNewline
    Write-Host " -> $TargetDir"
}

function Install-OpenCodeCommands {
    $commandsSrc = Join-Path $RepoDir 'examples\opencode\commands'
    $commandsTarget = $ToolPaths['opencode-commands']

    Write-Host ''
    Write-Host 'Installing OpenCode commands...' -ForegroundColor Blue

    New-Item -ItemType Directory -Path $commandsTarget -Force | Out-Null

    $count = 0
    $cmdFiles = Get-ChildItem -Path $commandsSrc -File -Filter 'sdd-*.md'

    foreach ($cmdFile in $cmdFiles) {
        $cmdName = $cmdFile.BaseName
        Copy-Item -Path $cmdFile.FullName -Destination (Join-Path $commandsTarget $cmdFile.Name) -Force

        Write-Skill $cmdName
        $count++
    }

    Write-Host ''
    Write-Host "  $count commands installed" -ForegroundColor Green -NoNewline
    Write-Host " -> $commandsTarget"
}

function Install-WindsurfWorkflows {
    $workflowsSrc = Join-Path $RepoDir 'examples\windsurf\.windsurf\workflows'
    $workflowsTarget = $ToolPaths['windsurf-workflows']

    Write-Host ''
    Write-Host 'Installing Windsurf workflows...' -ForegroundColor Blue

    New-Item -ItemType Directory -Path $workflowsTarget -Force | Out-Null

    $count = 0
    $workflowFiles = Get-ChildItem -Path $workflowsSrc -File -Filter 'sdd-*.md'

    foreach ($workflowFile in $workflowFiles) {
        $workflowName = $workflowFile.BaseName
        Copy-Item -Path $workflowFile.FullName -Destination (Join-Path $workflowsTarget $workflowFile.Name) -Force

        Write-Skill $workflowName
        $count++
    }

    Write-Host ''
    Write-Host "  $count workflows installed" -ForegroundColor Green -NoNewline
    Write-Host " -> $workflowsTarget"
}

# ============================================================================
# Agent Install Dispatcher
# ============================================================================

function Install-ForAgent {
    param([string]$AgentName)

    switch ($AgentName) {
        'claude-code' {
            Install-Skills -TargetDir $ToolPaths['claude-code'] -ToolName 'Claude Code'
            Write-NextStep '~\.claude\CLAUDE.md' 'examples\claude-code\CLAUDE.md'
        }
        'opencode' {
            Install-Skills -TargetDir $ToolPaths['opencode'] -ToolName 'OpenCode'
            Install-OpenCodeCommands
            Write-Host ''
            Write-Host ([char]0x2554 + ([string][char]0x2550 * 62) + [char]0x2557) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '  ACTION REQUIRED: Add the sdd-orchestrator agent config     ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '                                                              ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '  Copy the agent block from:                                  ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '    examples\opencode\opencode.json                           ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '  Into your:                                                  ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + "    $env:APPDATA\opencode\opencode.json                       " + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '                                                              ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x2551 + '  Without this, /sdd-* commands will not find the agent.      ' + [char]0x2551) -ForegroundColor Yellow
            Write-Host ([char]0x255A + ([string][char]0x2550 * 62) + [char]0x255D) -ForegroundColor Yellow
        }
        'gemini-cli' {
            Install-Skills -TargetDir $ToolPaths['gemini-cli'] -ToolName 'Gemini CLI'
            Write-NextStep '~\.gemini\GEMINI.md' 'examples\gemini-cli\GEMINI.md'
        }
        'codex' {
            Install-Skills -TargetDir $ToolPaths['codex'] -ToolName 'Codex'
            Write-NextStep 'Codex instructions file' 'examples\codex\agents.md'
        }
        'vscode' {
            Install-Skills -TargetDir $ToolPaths['vscode'] -ToolName 'VS Code (Copilot)'
            Write-NextStep '.github\copilot-instructions.md' 'examples\vscode\copilot-instructions.md'
            Write-Warn 'Skills installed in current project (.vscode\skills\)'
        }
        'antigravity' {
            Install-Skills -TargetDir $ToolPaths['antigravity'] -ToolName 'Antigravity'
            Write-NextStep '~\.gemini\GEMINI.md or .agent\rules\' 'examples\antigravity\sdd-orchestrator.md'
        }
        'cursor' {
            Install-Skills -TargetDir $ToolPaths['cursor'] -ToolName 'Cursor'
            Write-NextStep '.cursorrules' 'examples\cursor\.cursorrules'
        }
        'windsurf' {
            Install-Skills -TargetDir $ToolPaths['windsurf'] -ToolName 'Windsurf'
            Install-WindsurfWorkflows
            Write-Host ''
            Write-Host 'Note: ' -ForegroundColor Yellow -NoNewline
            Write-Host "Skills installed to " -NoNewline
            Write-Host "~\.agents\skills\" -ForegroundColor White
            Write-Host '       Workflows installed to ' -NoNewline
            Write-Host '.windsurf\workflows\ ' -ForegroundColor White -NoNewline
            Write-Host '(project-local)'
            Write-Host ''
            Write-Host 'How to use:' -ForegroundColor Yellow
            Write-Host '  • Open Windsurf in your project'
            Write-Host '  • Workflows are auto-discovered from .windsurf/workflows/'
            Write-Host '  • Use slash commands: ' -NoNewline
            Write-Host '/sdd-init' -ForegroundColor Cyan -NoNewline
            Write-Host ', ' -NoNewline
            Write-Host '/sdd-new <name>' -ForegroundColor Cyan -NoNewline
            Write-Host ', ' -NoNewline
            Write-Host '/sdd-apply' -ForegroundColor Cyan -NoNewline
            Write-Host ', etc.'
        }
        'project-local' {
            Install-Skills -TargetDir $ToolPaths['project-local'] -ToolName 'Project-local'
            Write-Host ''
            Write-Warn "Skills installed in .\skills\ - relative to this project"
        }
        'all-global' {
            Install-Skills -TargetDir $ToolPaths['claude-code'] -ToolName 'Claude Code'
            Install-Skills -TargetDir $ToolPaths['opencode'] -ToolName 'OpenCode'
            Install-OpenCodeCommands
            Install-Skills -TargetDir $ToolPaths['gemini-cli'] -ToolName 'Gemini CLI'
            Install-Skills -TargetDir $ToolPaths['codex'] -ToolName 'Codex'
            Install-Skills -TargetDir $ToolPaths['cursor'] -ToolName 'Cursor'
            Install-Skills -TargetDir $ToolPaths['windsurf'] -ToolName 'Windsurf'
            Install-WindsurfWorkflows
            Write-Host ''
            Write-Host 'Next steps:' -ForegroundColor Yellow
            Write-Host '  1. Add orchestrator to ' -NoNewline
            Write-Host '~\.claude\CLAUDE.md' -ForegroundColor White
            Write-Host '  2. ' -NoNewline
            Write-Host '[REQUIRED] ' -ForegroundColor Yellow -NoNewline
            Write-Host 'Add orchestrator agent to ' -NoNewline
            Write-Host "$env:APPDATA\opencode\opencode.json" -ForegroundColor White
            Write-Host '     See: examples\opencode\opencode.json — without this, /sdd-* commands will not work' -ForegroundColor Yellow
            Write-Host '  3. Add orchestrator to ' -NoNewline
            Write-Host '~\.gemini\GEMINI.md' -ForegroundColor White
            Write-Host '  4. Add orchestrator to ' -NoNewline
            Write-Host 'Codex instructions file' -ForegroundColor White
            Write-Host '  5. Add SDD rules to ' -NoNewline
            Write-Host '.cursorrules' -ForegroundColor White
            Write-Host '  6. Windsurf workflows installed to ' -NoNewline
            Write-Host '.windsurf\workflows\' -ForegroundColor White -NoNewline
            Write-Host ' (auto-discovered)'
        }
        'custom' {
            $customPath = $Path
            if (-not $customPath) {
                $customPath = Read-Host 'Enter target path'
            }
            if (-not $customPath) {
                Write-Err 'No path provided'
                exit 1
            }
            Install-Skills -TargetDir $customPath -ToolName 'Custom'
        }
        default {
            Write-Err "Unknown agent: $AgentName"
            Write-Host ''
            Show-Usage
            exit 1
        }
    }
}

# ============================================================================
# Interactive Menu
# ============================================================================

function Show-Menu {
    Write-Host 'Select your AI coding assistant:' -ForegroundColor White
    Write-Host ''
    Write-Host "   1) Claude Code    ($($ToolPaths['claude-code']))"
    Write-Host "   2) OpenCode       ($($ToolPaths['opencode']))"
    Write-Host "   3) Gemini CLI     ($($ToolPaths['gemini-cli']))"
    Write-Host "   4) Codex          ($($ToolPaths['codex']))"
    Write-Host "   5) VS Code        ($($ToolPaths['vscode']))"
    Write-Host "   6) Antigravity    ($($ToolPaths['antigravity']))"
    Write-Host "   7) Cursor         ($($ToolPaths['cursor']))"
    Write-Host "   8) Windsurf       ($($ToolPaths['windsurf']) + .windsurf\workflows\)"
    Write-Host "   9) Project-local  ($($ToolPaths['project-local']))"
    Write-Host '  10) All global     (Claude Code + OpenCode + Gemini CLI + Codex + Cursor + Windsurf)'
    Write-Host '  11) Custom path'
    Write-Host ''

    $choice = Read-Host 'Choice [1-11]'

    $agentMap = @{
        '1'  = 'claude-code'
        '2'  = 'opencode'
        '3'  = 'gemini-cli'
        '4'  = 'codex'
        '5'  = 'vscode'
        '6'  = 'antigravity'
        '7'  = 'cursor'
        '8'  = 'windsurf'
        '9'  = 'project-local'
        '10' = 'all-global'
        '11' = 'custom'
    }

    if ($agentMap.ContainsKey($choice)) {
        Install-ForAgent $agentMap[$choice]
    }
    else {
        Write-Err 'Invalid choice'
        exit 1
    }
}

# ============================================================================
# Main
# ============================================================================

try {
    if ($Help) {
        Show-Usage
        exit 0
    }

    Write-Header
    Test-SourceTree

    if ($Agent) {
        Install-ForAgent $Agent
    }
    else {
        Show-Menu
    }

    Write-Host ''
    Write-Host 'Done!' -ForegroundColor Green -NoNewline
    Write-Host ' Start using SDD with: ' -NoNewline
    Write-Host '/sdd-init' -ForegroundColor Cyan -NoNewline
    Write-Host ' in your project'

    Write-EngramNote
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Err "Installation failed: $_"
    Write-Host ''
    exit 1
}
