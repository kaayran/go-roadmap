@echo off
setlocal EnableDelayedExpansion

set TEMPLATE=%~dp0gitignore.template
if not exist "!TEMPLATE!" (
    echo error: template not found at !TEMPLATE!
    exit /b 1
)

if exist ".gitignore" (
    set /p OVERWRITE=.gitignore already exists. overwrite? (y/n):
    if /i not "!OVERWRITE!"=="y" ( echo cancelled. & exit /b 0 )
)

copy /y "!TEMPLATE!" ".gitignore" >nul
echo done: .gitignore created.

endlocal
