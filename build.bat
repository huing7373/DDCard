@echo off
setlocal enabledelayedexpansion

:: Demon Lord Build Script
:: Creates distributable packages for Love2D game

set GAME_NAME=DemonLord
set BUILD_DIR=build
set LOVE_DIR=C:\Program Files\LOVE

echo ========================================
echo   Demon Lord Build Script
echo ========================================
echo.

:: Create build directory
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: Clean old builds
if exist "%BUILD_DIR%\%GAME_NAME%.love" del "%BUILD_DIR%\%GAME_NAME%.love"
if exist "%BUILD_DIR%\%GAME_NAME%.exe" del "%BUILD_DIR%\%GAME_NAME%.exe"
if exist "%BUILD_DIR%\%GAME_NAME%-win" rmdir /s /q "%BUILD_DIR%\%GAME_NAME%-win"

echo [1/3] Creating .love file...

:: Create .love file (zip archive)
cd /d "%~dp0"
powershell -Command "Compress-Archive -Path 'main.lua','conf.lua','config.lua','utils.lua','ui.lua','combat.lua','grid.lua','card.lua','ai.lua','levels.lua','progression.lua','skills.lua','roguelike.lua','globals.lua','game.lua','engine','entities','systems','resources' -DestinationPath '%BUILD_DIR%\%GAME_NAME%.zip' -Force"
move "%BUILD_DIR%\%GAME_NAME%.zip" "%BUILD_DIR%\%GAME_NAME%.love" >nul

if exist "%BUILD_DIR%\%GAME_NAME%.love" (
    echo    [OK] %GAME_NAME%.love created
) else (
    echo    [ERROR] Failed to create .love file
    goto :error
)

echo.
echo [2/3] Creating standalone Windows executable...

:: Check if Love2D is installed
if not exist "%LOVE_DIR%\love.exe" (
    echo    [SKIP] Love2D not found at %LOVE_DIR%
    echo    Only .love file will be created.
    goto :done
)

:: Create Windows distribution folder
mkdir "%BUILD_DIR%\%GAME_NAME%-win"

:: Combine love.exe with .love file to create standalone exe
copy /b "%LOVE_DIR%\love.exe"+"%BUILD_DIR%\%GAME_NAME%.love" "%BUILD_DIR%\%GAME_NAME%-win\%GAME_NAME%.exe" >nul

:: Copy required DLLs
for %%f in (
    "SDL2.dll"
    "OpenAL32.dll"
    "lua51.dll"
    "mpg123.dll"
    "msvcp120.dll"
    "msvcr120.dll"
    "love.dll"
) do (
    if exist "%LOVE_DIR%\%%~f" (
        copy "%LOVE_DIR%\%%~f" "%BUILD_DIR%\%GAME_NAME%-win\" >nul
    )
)

:: Copy license
if exist "%LOVE_DIR%\license.txt" (
    copy "%LOVE_DIR%\license.txt" "%BUILD_DIR%\%GAME_NAME%-win\" >nul
)

echo    [OK] Windows executable created

echo.
echo [3/3] Creating distribution zip...

:: Create final zip for distribution
powershell -Command "Compress-Archive -Path '%BUILD_DIR%\%GAME_NAME%-win\*' -DestinationPath '%BUILD_DIR%\%GAME_NAME%-win.zip' -Force"

if exist "%BUILD_DIR%\%GAME_NAME%-win.zip" (
    echo    [OK] %GAME_NAME%-win.zip created
) else (
    echo    [WARN] Failed to create distribution zip
)

:done
echo.
echo ========================================
echo   Build Complete!
echo ========================================
echo.
echo Output files in '%BUILD_DIR%' folder:
echo.
if exist "%BUILD_DIR%\%GAME_NAME%.love" (
    echo   - %GAME_NAME%.love
    echo     ^(Requires Love2D installed to run^)
)
if exist "%BUILD_DIR%\%GAME_NAME%-win.zip" (
    echo.
    echo   - %GAME_NAME%-win.zip
    echo     ^(Standalone Windows version - send this to friends!^)
)
echo.
goto :eof

:error
echo.
echo Build failed!
exit /b 1
