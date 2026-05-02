$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$EnvFile = Join-Path $RootDir ".env"
$FlutterBin = Join-Path $RootDir "flutter\bin\flutter.bat"

if (Test-Path $EnvFile) {
  Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) {
      return
    }

    $parts = $line.Split("=", 2)
    if ($parts.Length -eq 2) {
      [System.Environment]::SetEnvironmentVariable($parts[0], $parts[1], "Process")
    }
  }
}

if ([string]::IsNullOrWhiteSpace($env:AI_PROVIDER)) {
  $env:AI_PROVIDER = "local"
}

if ([string]::IsNullOrWhiteSpace($env:LOCAL_AI_BASE_URL)) {
  $env:LOCAL_AI_BASE_URL = "http://localhost:11434/v1"
}

if ([string]::IsNullOrWhiteSpace($env:LOCAL_AI_MODEL)) {
  $env:LOCAL_AI_MODEL = "llama3.2:3b"
}

if ([string]::IsNullOrWhiteSpace($env:LOCAL_AI_API_KEY)) {
  $env:LOCAL_AI_API_KEY = "local-ai"
}

& $FlutterBin @args `
  "--dart-define=AI_PROVIDER=$($env:AI_PROVIDER)" `
  "--dart-define=LOCAL_AI_BASE_URL=$($env:LOCAL_AI_BASE_URL)" `
  "--dart-define=LOCAL_AI_MODEL=$($env:LOCAL_AI_MODEL)" `
  "--dart-define=LOCAL_AI_API_KEY=$($env:LOCAL_AI_API_KEY)" `
  "--dart-define=GEMINI_API_KEY=$($env:GEMINI_API_KEY)"
exit $LASTEXITCODE
