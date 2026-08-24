@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3 builder.py
) else (
    where python >nul 2>nul
    if %errorlevel%==0 (
        python builder.py
    ) else (
        echo.
        echo ERROR: Python 3 is not installed or is not in PATH.
        echo Install Python 3 or run builder.py with Python manually.
        echo.
        pause
        exit /b 1
    )
)

set "BUILD_RESULT=%errorlevel%"
echo.
if not "%BUILD_RESULT%"=="0" (
    echo Build failed.
) else (
    echo Build finished successfully.
)
pause
exit /b %BUILD_RESULT%
