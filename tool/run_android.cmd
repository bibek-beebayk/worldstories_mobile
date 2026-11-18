@echo off
setlocal
cd /d "%~dp0.."

if not exist config\local.json (
  echo Missing config\local.json. Copy config\local.example.json and add the Web OAuth client ID. 1>&2
  exit /b 1
)
findstr /c:"YOUR_WEB_CLIENT_ID" config\local.json >nul && (
  echo Replace the placeholder in config\local.json with your Web OAuth client ID. 1>&2
  exit /b 1
)

call flutter run --dart-define-from-file=config/local.json %*
