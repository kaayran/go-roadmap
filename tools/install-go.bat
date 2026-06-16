@echo off
setlocal EnableDelayedExpansion

echo checking for winget...
where winget >nul 2>&1
if errorlevel 1 (
    echo error: winget not found. install it from the Microsoft Store or update Windows.
    exit /b 1
)

echo.
echo this will install:
echo   - Go (via winget)
echo   - gopls, goimports, dlv, golangci-lint, govulncheck
echo.
set /p CONFIRM=continue? (y/n):
if /i not "!CONFIRM!"=="y" ( echo cancelled. & exit /b 0 )
echo.

echo installing Go...
winget install --id GoLang.Go --silent --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo error: Go installation failed.
    exit /b 1
)

echo refreshing PATH...
for /f "tokens=*" %%i in ('powershell -Command "[System.Environment]::GetEnvironmentVariable(\"PATH\", \"Machine\")"') do set PATH=%%i;%PATH%
set PATH=%PATH%;%USERPROFILE%\go\bin

echo.
echo installing global tools...
go install golang.org/x/tools/gopls@latest
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

echo.
echo done.
echo.
echo   restart your terminal, then run: go version

endlocal
