@echo off
:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with Administrator privileges...
) else (
    echo.
    echo ERROR: Please right-click this file and select "Run as administrator".
    echo.
    pause
    exit /b
)

echo Enabling Premiere Pro Debug Mode for local extensions...

:: Write HKEY_CURRENT_USER keys
REG ADD "HKCU\Software\Adobe\CSXS.9" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKCU\Software\Adobe\CSXS.10" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKCU\Software\Adobe\CSXS.11" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKCU\Software\Adobe\CSXS.12" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKCU\Software\Adobe\CSXS.13" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKCU\Software\Adobe\CSXS.14" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKCU\Software\Adobe\CSXS.15" /v PlayerDebugMode /t REG_SZ /d 1 /f

:: Write HKEY_LOCAL_MACHINE keys
REG ADD "HKLM\Software\Adobe\CSXS.9" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Adobe\CSXS.10" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Adobe\CSXS.11" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Adobe\CSXS.12" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Adobe\CSXS.13" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Adobe\CSXS.14" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Adobe\CSXS.15" /v PlayerDebugMode /t REG_SZ /d 1 /f

:: Write HKEY_LOCAL_MACHINE Wow6432Node keys
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.9" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.10" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.11" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.12" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.13" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.14" /v PlayerDebugMode /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Wow6432Node\Adobe\CSXS.15" /v PlayerDebugMode /t REG_SZ /d 1 /f

echo.
echo Success! Debug mode has been enabled. Restart Premiere Pro.
echo.
pause
