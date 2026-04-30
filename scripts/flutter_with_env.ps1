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

if ([string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) {
  Write-Error "Missing GEMINI_API_KEY. Add it to $EnvFile or export it in your shell."
}

& $FlutterBin @args "--dart-define=GEMINI_API_KEY=$($env:GEMINI_API_KEY)"
exit $LASTEXITCODE
