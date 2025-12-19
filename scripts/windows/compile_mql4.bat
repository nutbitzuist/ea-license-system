@echo off
REM ============================================
REM Compile ALL MQL4 Expert Advisors to EX4
REM ============================================
REM 
REM SETUP INSTRUCTIONS:
REM 1. Edit the MT4_PATH below to match YOUR MetaTrader 4 installation path
REM 2. Place this script in: C:\MyAlgoStack\
REM 3. Place your MQL4 folder at: C:\MyAlgoStack\MQL4\
REM 4. Run this script as Administrator (right-click > Run as administrator)
REM

SET MT4_PATH=C:\Program Files (x86)\MetaTrader 4
SET COMPILER="%MT4_PATH%\metaeditor.exe"
SET SOURCE_DIR=C:\MyAlgoStack\MQL4\Experts
SET LOG_FILE=C:\MyAlgoStack\compile_mql4_log.txt

echo ========================================== > %LOG_FILE%
echo MQL4 Compilation Started: %DATE% %TIME% >> %LOG_FILE%
echo ========================================== >> %LOG_FILE%

echo.
echo ============================================
echo   My Algo Stack - MQL4 Compiler
echo ============================================
echo.
echo MetaEditor Path: %COMPILER%
echo Source Directory: %SOURCE_DIR%
echo.

REM Check if MetaEditor exists
if not exist %COMPILER% (
    echo ERROR: MetaEditor not found at %COMPILER%
    echo Please edit this script and set the correct MT4_PATH
    echo ERROR: MetaEditor not found >> %LOG_FILE%
    pause
    exit /b 1
)

REM Check if source directory exists
if not exist "%SOURCE_DIR%" (
    echo ERROR: Source directory not found at %SOURCE_DIR%
    echo Please create the folder and copy your MQL4 files there
    echo ERROR: Source directory not found >> %LOG_FILE%
    pause
    exit /b 1
)

echo Compiling MQL4 files...
echo.

SET /A SUCCESS_COUNT=0
SET /A FAIL_COUNT=0

FOR %%F IN ("%SOURCE_DIR%\*.mq4") DO (
    echo Compiling: %%~nxF
    echo Compiling: %%~nxF >> %LOG_FILE%
    
    %COMPILER% /compile:"%%F" /log
    
    REM Check if EX4 file was created
    if exist "%%~dpnF.ex4" (
        echo   SUCCESS: %%~nF.ex4 created
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
