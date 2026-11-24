$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
if (-not (Test-Path "windows")) {
  flutter create --org tz.co.kibo --project-name kibo_admin --no-pub --platforms windows .
  if ($LASTEXITCODE -ne 0) { throw "flutter create failed" }
}
Remove-Item -Force "test/widget_test.dart" -ErrorAction SilentlyContinue
Write-Host "Windows preparation done."
