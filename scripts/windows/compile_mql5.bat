@echo off
REM ============================================
REM Compile ALL MQL5 Expert Advisors to EX5
REM ============================================
REM 
REM SETUP INSTRUCTIONS:
REM 1. Edit the MT5_PATH below to match YOUR MetaTrader 5 installation path
REM 2. Place this script in: C:\MyAlgoStack\
REM 3. Place your MQL5 folder at: C:\MyAlgoStack\MQL5\
REM 4. Run this script as Administrator (right-click > Run as administrator)
REM

SET MT5_PATH=C:\Program Files\MetaTrader 5
SET COMPILER="%MT5_PATH%\metaeditor64.exe"
SET SOURCE_DIR=C:\MyAlgoStack\MQL5\Experts
SET INCLUDE_DIR=C:\MyAlgoStack\MQL5\Include
SET LOG_FILE=C:\MyAlgoStack\compile_mql5_log.txt

echo ========================================== > %LOG_FILE%
echo MQL5 Compilation Started: %DATE% %TIME% >> %LOG_FILE%
echo ========================================== >> %LOG_FILE%

echo.
echo ============================================
echo   My Algo Stack - MQL5 Compiler
echo ============================================
echo.
echo MetaEditor Path: %COMPILER%
echo Source Directory: %SOURCE_DIR%
echo.

REM Check if MetaEditor exists
if not exist %COMPILER% (
    echo ERROR: MetaEditor64 not found at %COMPILER%
    echo Please edit this script and set the correct MT5_PATH
    echo ERROR: MetaEditor64 not found >> %LOG_FILE%
    pause
    exit /b 1
)

REM Check if source directory exists
if not exist "%SOURCE_DIR%" (
    echo ERROR: Source directory not found at %SOURCE_DIR%
    echo Please create the folder and copy your MQL5 files there
    echo ERROR: Source directory not found >> %LOG_FILE%
    pause
    exit /b 1
)

echo Compiling MQL5 files...
echo.

SET /A SUCCESS_COUNT=0
SET /A FAIL_COUNT=0

FOR %%F IN ("%SOURCE_DIR%\*.mq5") DO (
    echo Compiling: %%~nxF
    echo Compiling: %%~nxF >> %LOG_FILE%
    
    %COMPILER% /compile:"%%F" /inc:"%INCLUDE_DIR%" /log
    
    REM Check if EX5 file was created
    if exist "%%~dpnF.ex5" (
        echo   SUCCESS: %%~nF.ex5 created
        echo   SUCCESS >> %LOG_FILE%
        SET /A SUCCESS_COUNT+=1
    ) else (
        echo   FAILED: Could not compile %%~nxF
        echo   FAILED >> %LOG_FILE%
        SET /A FAIL_COUNT+=1
    )
)

echo.
echo ============================================
echo Compilation Complete!
echo SUCCESS: %SUCCESS_COUNT% files compiled
echo FAILED: %FAIL_COUNT% files
echo ============================================
echo.
echo Log saved to: %LOG_FILE%
echo.

echo ========================================== >> %LOG_FILE%
echo Compilation Finished: %DATE% %TIME% >> %LOG_FILE%
echo SUCCESS: %SUCCESS_COUNT% / FAILED: %FAIL_COUNT% >> %LOG_FILE%
echo ========================================== >> %LOG_FILE%

pause
