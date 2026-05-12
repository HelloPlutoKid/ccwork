# PostToolUse hook
# src/**/*.{ts,tsx} 가 Edit/Write/MultiEdit 으로 변경되면 reminder 를 stdout 으로 출력한다.
# - exit 0 으로만 종료 (도구 호출을 차단하지 않음)
# - 매칭이 아니거나 입력 파싱 실패 시 무음
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try {
  $j = $payload | ConvertFrom-Json
} catch {
  exit 0
}

# Claude Code 의 PostToolUse 입력은 tool_input.file_path 에 대상 경로를 담는다.
# 환경에 따라 키가 다를 수 있어 두 표기를 모두 시도.
$path = $null
if ($j.tool_input -and $j.tool_input.file_path) { $path = [string]$j.tool_input.file_path }
elseif ($j.toolInput -and $j.toolInput.file_path) { $path = [string]$j.toolInput.file_path }

if ($path -and $path -match 'src[\\/].+\.tsx?$') {
  Write-Output "[arch] src/ change detected ($path). The architecture diagram may be stale -- run /mermaid-diagram to refresh docs/architecture/index.html."
}

exit 0
