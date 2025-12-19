@echo off
REM ============================================
REM Compile ALL MQL4 AND MQL5 Files
REM ============================================
REM 
REM This script runs both compile_mql4.bat and compile_mql5.bat
REM

echo.
echo ============================================
echo   My Algo Stack - Full Compilation
echo ============================================
echo.

echo Running MQL4 compilation...
call "%~dp0compile_mql4.bat"

echo.
echo Running MQL5 compilation...
call "%~dp0compile_mql5.bat"

echo.
echo ============================================
echo   ALL COMPILATIONS COMPLETE
echo ============================================
echo.
echo Check these files for results:
echo   - C:\MyAlgoStack\compile_mql4_log.txt
echo   - C:\MyAlgoStack\compile_mql5_log.txt
echo.

pause
