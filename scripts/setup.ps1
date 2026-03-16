#Requires -Version 5.1

<#
.SYNOPSIS
    Agent Teams Lite — Full Setup Script for Windows
.DESCRIPTION
    Detects installed agents, copies skills, and configures orchestrator prompts.
    Idempotent: safe to run multiple times (uses markers to avoid duplication).
.PARAMETER Agent
    Install for a specific agent.
    Valid values: claude-code, opencode, gemini-cli, cursor, vscode, codex
.PARAMETER All
    Auto-detect and install for all found agents.
.PARAMETER OpenCodeMode
    OpenCode agent mode: 'single' (default) or 'multi' (one agent per phase with its own model).
.PARAMETER NonInteractive
    No prompts (for external installers like gentle-ai).
.EXAMPLE
    .\setup.ps1
.EXAMPLE
    .\setup.ps1 -All
.EXAMPLE
    .\setup.ps1 -Agent opencode -OpenCodeMode multi
.EXAMPLE
    .\setup.ps1 -NonInteractive
#>

[CmdletBinding()]
param(
    [ValidateSet('claude-code', 'opencode', 'gemini-cli', 'cursor', 'vscode', 'codex')]
    [string]$Agent,
    [ValidateSet('single', 'multi')]
    [string]$OpenCodeMode,
    [switch]$All,
    [switch]$NonInteractive,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# Paths
# ============================================================================

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoDir = Split-Path -Parent $ScriptRoot
$SkillsSrc = Join-Path $RepoDir 'skills'
$ExamplesDir = Join-Path $RepoDir 'examples'

$MarkerBegin = '<!-- BEGIN:agent-teams-lite -->'
$MarkerEnd = '<!-- END:agent-teams-lite -->'

# gentle-ai-installer markers (detect to avoid duplication)
$GaiMarkerBegin = '<!-- gentle-ai:sdd-orchestrator -->'
$GaiMarkerEnd = '<!-- /gentle-ai:sdd-orchestrator -->'

# Content headings that indicate orchestrator is already present
$OrchestratorHeadings = @(
    '## Agent Teams Orchestrator',
    '## Spec-Driven Development (SDD) Orchestrator',
    '## Spec-Driven Development (SDD)'
)

$SkillsPaths = @{
    'claude-code' = Join-Path $env:USERPROFILE '.claude\skills'
    'opencode'    = Join-Path $env:USERPROFILE '.config\opencode\skills'
    'gemini-cli'  = Join-Path $env:USERPROFILE '.gemini\skills'
    'cursor'      = Join-Path $env:USERPROFILE '.cursor\skills'
    'vscode'      = Join-Path $env:USERPROFILE '.copilot\skills'
    'codex'       = Join-Path $env:USERPROFILE '.codex\skills'
}

$PromptPaths = @{
    'claude-code' = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
    'opencode'    = Join-Path $env:USERPROFILE '.config\opencode\AGENTS.md'
    'gemini-cli'  = Join-Path $env:USERPROFILE '.gemini\GEMINI.md'
    'cursor'      = Join-Path $env:USERPROFILE '.cursor\rules\agent-teams-lite.mdc'
    'vscode'      = Join-Path $env:APPDATA 'Code\User\prompts\agent-teams-lite.instructions.md'
    'codex'       = Join-Path $env:USERPROFILE '.codex\agents.md'
}

$ExampleFiles = @{
    'claude-code' = Join-Path $ExamplesDir 'claude-code\CLAUDE.md'
    'gemini-cli'  = Join-Path $ExamplesDir 'gemini-cli\GEMINI.md'
    'cursor'      = Join-Path $ExamplesDir 'cursor\.cursorrules'
    'vscode'      = Join-Path $ExamplesDir 'vscode\copilot-instructions.md'
    'codex'       = Join-Path $ExamplesDir 'codex\agents.md'
}

$AgentBinaries = @{
    'claude-code' = 'claude'
    'opencode'    = 'opencode'
    'gemini-cli'  = 'gemini'
    'cursor'      = 'cursor'
    'vscode'      = 'code'
    'codex'       = 'codex'
}

# ============================================================================
# Display Helpers
# ============================================================================

function Write-Ok    { param([string]$Msg) Write-Host '  ' -NoNewline; Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline; Write-Host " $Msg" }
function Write-Warn  { param([string]$Msg) Write-Host '  ! ' -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Fail  { param([string]$Msg) Write-Host '  ' -NoNewline; Write-Host ([char]0x2717) -ForegroundColor Red -NoNewline; Write-Host " $Msg" }
function Write-Info  { param([string]$Msg) Write-Host '  ' -NoNewline; Write-Host ([char]0x2192) -ForegroundColor Blue -NoNewline; Write-Host " $Msg" }
function Write-Head  { param([string]$Msg) Write-Host ''; Write-Host $Msg -ForegroundColor Cyan }

# ============================================================================
# Agent Detection
# ============================================================================

function Find-Agents {
    Write-Head 'Detecting installed agents...'

    $found = @()
    foreach ($agent in $AgentBinaries.Keys | Sort-Object) {
        $binary = $AgentBinaries[$agent]
        $cmd = Get-Command $binary -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Ok "$agent ($binary found in PATH)"
            $found += $agent
        }
    }

    Write-Host ''
    if ($found.Count -eq 0) {
        Write-Warn 'No agents detected in PATH'
        Write-Info 'You can still install manually with: .\install.ps1'
    } else {
        Write-Host "  $($found.Count) agent(s) detected" -ForegroundColor Green
    }

    return $found
}

# ============================================================================
# Install Skills
# ============================================================================

function Install-Skills {
    param([string]$TargetDir, [string]$AgentName)

    Write-Info "Installing skills -> $TargetDir"
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

    # Copy _shared
    $sharedSrc = Join-Path $SkillsSrc '_shared'
    $sharedTarget = Join-Path $TargetDir '_shared'
    if (Test-Path $sharedSrc) {
        New-Item -ItemType Directory -Path $sharedTarget -Force | Out-Null
        Copy-Item -Path (Join-Path $sharedSrc '*.md') -Destination $sharedTarget -Force
        Write-Ok '_shared conventions'
    }

    # Copy sdd-* + skill-registry
    $count = 0
    $skillDirs = @(Get-ChildItem -Path $SkillsSrc -Directory -Filter 'sdd-*')
    $registryDir = Join-Path $SkillsSrc 'skill-registry'
    if (Test-Path $registryDir) {
        $skillDirs += Get-Item $registryDir
    }

    foreach ($skillDir in $skillDirs) {
        $skillFile = Join-Path $skillDir.FullName 'SKILL.md'
        if (-not (Test-Path $skillFile)) { continue }

        $targetSkillDir = Join-Path $TargetDir $skillDir.Name
        New-Item -ItemType Directory -Path $targetSkillDir -Force | Out-Null
        Copy-Item -Path $skillFile -Destination (Join-Path $targetSkillDir 'SKILL.md') -Force
        $count++
    }

    Write-Ok "$count skills installed"
}

# ============================================================================
# Setup Orchestrator Prompt (idempotent with markers)
# ============================================================================

function Set-Orchestrator {
    param([string]$PromptPath, [string]$ExampleFile, [string]$AgentName)

    if (-not $ExampleFile -or -not (Test-Path $ExampleFile)) { return }

    $promptDir = Split-Path -Parent $PromptPath
    New-Item -ItemType Directory -Path $promptDir -Force | Out-Null

    # Strip preamble (human-readable header) — only inject from "## Agent Teams" onward
    $rawContent = Get-Content -Path $ExampleFile -Raw
    if ($rawContent -match '(?s)(## Agent Teams.*)') {
        $content = $Matches[1]
    } else {
        $content = $rawContent
    }

    if (Test-Path $PromptPath) {
        $existing = Get-Content -Path $PromptPath -Raw
        if ($existing -match [regex]::Escape($MarkerBegin)) {
            # Our markers exist — replace content between them
            $pattern = "(?s)$([regex]::Escape($MarkerBegin)).*?$([regex]::Escape($MarkerEnd))"
            $replacement = "$MarkerBegin`n$content`n$MarkerEnd"
            $updated = [regex]::Replace($existing, $pattern, $replacement)
            Set-Content -Path $PromptPath -Value $updated -NoNewline
            Write-Ok "Orchestrator updated in $PromptPath"
        } elseif ($existing -match [regex]::Escape($GaiMarkerBegin)) {
            # gentle-ai markers exist — replace with ours
            $pattern = "(?s)$([regex]::Escape($GaiMarkerBegin)).*?$([regex]::Escape($GaiMarkerEnd))"
            $replacement = "$MarkerBegin`n$content`n$MarkerEnd"
            $updated = [regex]::Replace($existing, $pattern, $replacement)
            Set-Content -Path $PromptPath -Value $updated -NoNewline
            Write-Ok "Orchestrator updated in $PromptPath (replaced gentle-ai section)"
        } else {
            # Check if orchestrator content already exists (no markers)
            $alreadyPresent = $false
            foreach ($heading in $OrchestratorHeadings) {
                if ($existing.Contains($heading)) {
                    $alreadyPresent = $true
                    break
                }
            }

            if ($alreadyPresent) {
                Write-Warn "Orchestrator already present in $PromptPath (no markers found)"
                Write-Info "To enable auto-updates, wrap the SDD section with:"
                Write-Info "  $MarkerBegin"
                Write-Info "  $MarkerEnd"
            } else {
                # No existing content — append with markers
                $appendContent = "`n`n$MarkerBegin`n$content`n$MarkerEnd"
                Add-Content -Path $PromptPath -Value $appendContent
                Write-Ok "Orchestrator appended to $PromptPath"
            }
        }
    } else {
        # Create new file
        $newContent = "$MarkerBegin`n$content`n$MarkerEnd"
        Set-Content -Path $PromptPath -Value $newContent
        Write-Ok "Orchestrator created at $PromptPath"
    }
}

# ============================================================================
# OpenCode Special Handling
# ============================================================================

function Ask-OpenCodeMode {
    # If already set via parameter, skip
    if ($script:OpenCodeMode) { return }

    # Non-interactive defaults to single
    if ($NonInteractive) {
        $script:OpenCodeMode = 'single'
        return
    }

    Write-Host ''
    Write-Host '  OpenCode agent mode:' -ForegroundColor White
    Write-Host ''
    Write-Host '  1) Single model  - one agent handles all phases (simple, recommended)'
    Write-Host '  2) Multi-model   - one agent per phase, each with its own model'
    Write-Host ''
    $choice = Read-Host '  Choice [1]'
    if (-not $choice) { $choice = '1' }

    switch ($choice) {
        { $_ -eq '2' -or $_ -eq 'multi' } { $script:OpenCodeMode = 'multi' }
        default { $script:OpenCodeMode = 'single' }
    }
}

function Set-OpenCode {
    $commandsSrc = Join-Path $ExamplesDir 'opencode\commands'
    $commandsTarget = Join-Path $env:USERPROFILE '.config\opencode\commands'
    $configFile = Join-Path $env:USERPROFILE '.config\opencode\opencode.json'

    # Determine mode and pick the right config template
    Ask-OpenCodeMode
    $exampleConfig = Join-Path $ExamplesDir "opencode\opencode.$($script:OpenCodeMode).json"
    Write-Info "OpenCode mode: $($script:OpenCodeMode)"

    # Install commands
    if (Test-Path $commandsSrc) {
        New-Item -ItemType Directory -Path $commandsTarget -Force | Out-Null
        $count = 0
        Get-ChildItem -Path $commandsSrc -Filter 'sdd-*.md' | ForEach-Object {
            $cmdName = $_.BaseName
            $content = Get-Content -Path $_.FullName -Raw

            if ($script:OpenCodeMode -eq 'multi' -and $content -match '(?m)^subtask:') {
                # Multi mode: subtask commands point to their dedicated subagent
                $modified = $content -replace '(?m)^agent: sdd-orchestrator', "agent: $cmdName"
                Set-Content -Path (Join-Path $commandsTarget $_.Name) -Value $modified -NoNewline
            } else {
                Copy-Item -Path $_.FullName -Destination (Join-Path $commandsTarget $_.Name) -Force
            }
            $count++
        }
        Write-Ok "$count OpenCode commands installed ($($script:OpenCodeMode) mode)"
    }

    # Merge opencode.json
    if (Test-Path $exampleConfig) {
        if (Test-Path $configFile) {
            try {
                $existing = Get-Content -Path $configFile -Raw | ConvertFrom-Json
                $example = Get-Content -Path $exampleConfig -Raw | ConvertFrom-Json

                # Merge agent config (OpenCode uses "agent" singular)
                # Strategy: replace all sdd-* agents with template, preserve user model choices
                if ($example.PSObject.Properties['agent']) {
                    if (-not $existing.PSObject.Properties['agent']) {
                        $existing | Add-Member -NotePropertyName 'agent' -NotePropertyValue ([PSCustomObject]@{})
                    }

                    # 1. Save existing model fields from sdd-* agents
                    $savedModels = @{}
                    foreach ($prop in @($existing.agent.PSObject.Properties)) {
                        if ($prop.Name -like 'sdd-*' -and $prop.Value.PSObject.Properties['model']) {
                            $savedModels[$prop.Name] = $prop.Value.model
                        }
                    }

                    # 2. Remove all existing sdd-* agents (clean slate)
                    foreach ($prop in @($existing.agent.PSObject.Properties)) {
                        if ($prop.Name -like 'sdd-*') {
                            $existing.agent.PSObject.Properties.Remove($prop.Name)
                        }
                    }

                    # 3. Add new agents from template
                    foreach ($prop in $example.agent.PSObject.Properties) {
                        $existing.agent | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                    }

                    # 4. Restore user model choices
                    foreach ($name in $savedModels.Keys) {
                        if ($existing.agent.PSObject.Properties[$name]) {
                            $existing.agent.$name | Add-Member -NotePropertyName 'model' -NotePropertyValue $savedModels[$name] -Force
                        }
                    }
                }

                # Clean up stale "agents" (plural) key from older script versions
                if ($existing.PSObject.Properties['agents']) {
                    $existing.PSObject.Properties.Remove('agents')
                }

                $existing | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile
                Write-Ok "Agent config merged into $configFile ($($script:OpenCodeMode) mode)"
            }
            catch {
                Write-Warn "Could not merge opencode.json: $_"
                Write-Info "Merge manually from examples\opencode\opencode.$($script:OpenCodeMode).json"
            }
        } else {
            $configDir = Split-Path -Parent $configFile
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            Copy-Item -Path $exampleConfig -Destination $configFile
            Write-Ok "Config created at $configFile ($($script:OpenCodeMode) mode)"
        }
    }

    # Install background-agents plugin
    $pluginsDir = Join-Path $env:USERPROFILE '.config\opencode\plugins'
    $pluginSrc = Join-Path $ScriptRoot '..\examples\opencode\plugins\background-agents.ts'
    New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
    Copy-Item -Path $pluginSrc -Destination (Join-Path $pluginsDir 'background-agents.ts') -Force
    Write-Ok "background-agents plugin installed -> $pluginsDir"
    Write-Info "Installing npm dependency: unique-names-generator"
    Push-Location (Join-Path $env:USERPROFILE '.config\opencode')
    try {
        npm install unique-names-generator
        Write-Ok "unique-names-generator installed"
    } finally {
        Pop-Location
    }
}

# ============================================================================
# Full Setup for One Agent
# ============================================================================

function Set-Agent {
    param([string]$AgentName)

    Write-Head "Setting up $AgentName"

    $skillsPath = $SkillsPaths[$AgentName]
    Install-Skills -TargetDir $skillsPath -AgentName $AgentName

    if ($AgentName -eq 'opencode') {
        Set-OpenCode
    } else {
        $promptPath = $PromptPaths[$AgentName]
        $exampleFile = $ExampleFiles[$AgentName]
        if ($exampleFile) {
            Set-Orchestrator -PromptPath $promptPath -ExampleFile $exampleFile -AgentName $AgentName
        }
    }
}

# ============================================================================
# Main
# ============================================================================

try {
    if ($Help) {
        Write-Host 'Usage: .\setup.ps1 [OPTIONS]'
        Write-Host ''
        Write-Host 'Options:'
        Write-Host '  -All               Auto-detect and install for all found agents'
        Write-Host '  -Agent NAME        Install for a specific agent'
        Write-Host '  -OpenCodeMode M    OpenCode agent mode: single or multi (per-phase models)'
        Write-Host '  -NonInteractive    No prompts (for external installers)'
        Write-Host '  -Help              Show this help'
        Write-Host ''
        Write-Host 'Agents: claude-code, opencode, gemini-cli, cursor, vscode, codex'
        exit 0
    }

    Write-Host ''
    Write-Host ([char]0x2554 + ([string][char]0x2550 * 42) + [char]0x2557) -ForegroundColor Cyan
    Write-Host ([char]0x2551 + '    Agent Teams Lite - Full Setup          ' + [char]0x2551) -ForegroundColor Cyan
    Write-Host ([char]0x2551 + '   Detect - Install - Configure            ' + [char]0x2551) -ForegroundColor Cyan
    Write-Host ([char]0x255A + ([string][char]0x2550 * 42) + [char]0x255D) -ForegroundColor Cyan

    # Validate source
    $skillDirs = Get-ChildItem -Path $SkillsSrc -Directory -Filter 'sdd-*'
    foreach ($dir in $skillDirs) {
        if (-not (Test-Path (Join-Path $dir.FullName 'SKILL.md'))) {
            Write-Fail "Missing: $($dir.Name)/SKILL.md"
            Write-Fail 'Is this a complete clone? git clone https://github.com/Gentleman-Programming/agent-teams-lite.git'
            exit 1
        }
    }

    $installedAgents = @()

    if ($Agent) {
        Set-Agent -AgentName $Agent
        $installedAgents += $Agent
    }
    elseif ($All -or $NonInteractive) {
        $detected = Find-Agents
        foreach ($a in $detected) {
            Set-Agent -AgentName $a
            $installedAgents += $a
        }
    }
    else {
        $detected = Find-Agents
        if ($detected.Count -eq 0) {
            Write-Host ''
            Write-Warn 'No agents detected. Use .\install.ps1 for manual installation.'
            exit 0
        }

        Write-Host ''
        $answer = Read-Host 'Set up all detected agents? [Y/n]'
        if (-not $answer -or $answer -match '^[Yy]') {
            foreach ($a in $detected) {
                Set-Agent -AgentName $a
                $installedAgents += $a
            }
        } else {
            Write-Host ''
            Write-Host 'Select agents to set up (space-separated numbers):' -ForegroundColor White
            Write-Host ''
            $i = 1
            foreach ($a in $detected) {
                Write-Host "  $i) $a"
                $i++
            }
            Write-Host ''
            $choices = (Read-Host 'Choice') -split '\s+'
            foreach ($c in $choices) {
                $idx = [int]$c - 1
                if ($idx -ge 0 -and $idx -lt $detected.Count) {
                    Set-Agent -AgentName $detected[$idx]
                    $installedAgents += $detected[$idx]
                }
            }
        }
    }

    # Summary
    if ($installedAgents.Count -gt 0) {
        Write-Head 'Setup Complete'
        Write-Host ''
        foreach ($a in $installedAgents) {
            Write-Host '  ' -NoNewline
            Write-Host ([char]0x2713) -ForegroundColor Green -NoNewline
            Write-Host " $a" -ForegroundColor White
            Write-Host "    Skills: $($SkillsPaths[$a])"
            Write-Host "    Prompt: $($PromptPaths[$a])"
        }
        Write-Host ''
        Write-Host 'Done!' -ForegroundColor Green -NoNewline
        Write-Host ' Start using SDD: open any project and type ' -NoNewline
        Write-Host '/sdd-init' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Recommended: ' -ForegroundColor Yellow -NoNewline
        Write-Host 'Install Engram for cross-session persistence'
        Write-Host '  https://github.com/gentleman-programming/engram' -ForegroundColor Cyan
        Write-Host ''
    } else {
        Write-Host ''
        Write-Warn 'No agents were set up.'
    }
}
catch {
    Write-Host ''
    Write-Fail "Setup failed: $_"
    Write-Host ''
    exit 1
}
