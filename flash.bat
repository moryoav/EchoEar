@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===== Config =====
set "PROJECT_DIR=C:\dev\EchoEar"
set "CONFIG_FILE=echoear1.0-full-animation.yaml"
set "PORT=COM3"

rem ESPHome path
set "ESPHOME=C:\Users\Yoav\AppData\Local\Programs\Python\Python313\Scripts\esphome.exe"

rem Matching Python
set "PYTHON=C:\Users\Yoav\AppData\Local\Programs\Python\Python313\python.exe"

rem Exact factory bin path from your current build output
set "FACTORY_BIN=C:\dev\EchoEar\.esphome\build\esphome-web-cca284\.pioenvs\esphome-web-cca284\firmware.factory.bin"

cd /d "%PROJECT_DIR%" || (
  echo ERROR: Failed to change directory to "%PROJECT_DIR%"
  exit /b 1
)

if not exist "%ESPHOME%" (
  echo ERROR: ESPHome executable not found:
  echo %ESPHOME%
  exit /b 1
)

if not exist "%PYTHON%" (
  echo ERROR: Python executable not found:
  echo %PYTHON%
  exit /b 1
)

if not exist "%CONFIG_FILE%" (
  echo ERROR: Config file not found:
  echo %PROJECT_DIR%\%CONFIG_FILE%
  exit /b 1
)

echo.
echo =========================================
echo STEP 0: Checking ESPHome version
echo =========================================
echo.

for /f "tokens=2 delims= " %%A in ('"%ESPHOME%" --version') do set "CURRENT_ESPHOME=%%A"

if "%CURRENT_ESPHOME%"=="" (
  echo WARNING: Could not detect current ESPHome version.
  echo Continuing without update check.
  goto build
)

echo Current ESPHome version: %CURRENT_ESPHOME%

rem Get latest ESPHome version from PyPI using a temp Python file.
rem This avoids Windows batch quoting problems with python -c commands.
set "LATEST_ESPHOME="
set "TEMP_VERSION_SCRIPT=%TEMP%\check_esphome_latest.py"

> "%TEMP_VERSION_SCRIPT%" echo import json, urllib.request
>> "%TEMP_VERSION_SCRIPT%" echo data = json.load(urllib.request.urlopen("https://pypi.org/pypi/esphome/json", timeout=10^)^)
>> "%TEMP_VERSION_SCRIPT%" echo print(data["info"]["version"])

for /f "usebackq delims=" %%A in (`"%PYTHON%" "%TEMP_VERSION_SCRIPT%" 2^>nul`) do set "LATEST_ESPHOME=%%A"

del "%TEMP_VERSION_SCRIPT%" >nul 2>nul

if "%LATEST_ESPHOME%"=="" (
  echo WARNING: Could not check latest ESPHome version online.
  echo Continuing with installed version %CURRENT_ESPHOME%.
  goto build
)

echo Latest ESPHome version:  %LATEST_ESPHOME%

rem Compare versions using pip's vendored packaging module.
set "UPDATE_AVAILABLE="

> "%TEMP%\compare_esphome_versions.py" echo from pip._vendor.packaging.version import parse
>> "%TEMP%\compare_esphome_versions.py" echo current = "%CURRENT_ESPHOME%"
>> "%TEMP%\compare_esphome_versions.py" echo latest = "%LATEST_ESPHOME%"
>> "%TEMP%\compare_esphome_versions.py" echo print("YES" if parse(latest^) ^> parse(current^) else "NO"^)

for /f "usebackq delims=" %%A in (`"%PYTHON%" "%TEMP%\compare_esphome_versions.py" 2^>nul`) do set "UPDATE_AVAILABLE=%%A"

del "%TEMP%\compare_esphome_versions.py" >nul 2>nul

if /i not "%UPDATE_AVAILABLE%"=="YES" (
  echo ESPHome is already up to date.
  goto build
)

echo.
echo ESPHome update available: %CURRENT_ESPHOME% ^> %LATEST_ESPHOME%
choice /C YN /N /M "Update ESPHome now? [Y/N] "

if errorlevel 2 (
  echo Skipping ESPHome update.
  goto build
)

echo.
echo Updating ESPHome to %LATEST_ESPHOME%...
echo.

"%PYTHON%" -m pip install --upgrade "esphome==%LATEST_ESPHOME%"
if errorlevel 1 (
  echo.
  echo ERROR: ESPHome update failed.
  exit /b 1
)

echo.
echo Verifying ESPHome version...
"%ESPHOME%" --version
if errorlevel 1 (
  echo.
  echo ERROR: ESPHome did not run correctly after update.
  exit /b 1
)

:build
echo.
echo =========================================
echo STEP 1: Building firmware
echo =========================================
echo.

"%ESPHOME%" compile "%CONFIG_FILE%"
if errorlevel 1 (
  echo.
  echo ERROR: Build failed.
  exit /b 1
)

if not exist "%FACTORY_BIN%" (
  echo.
  echo ERROR: firmware.factory.bin was not found here:
  echo %FACTORY_BIN%
  exit /b 1
)

echo.
echo =========================================
echo STEP 2: Flashing firmware.factory.bin to %PORT%
echo =========================================
echo.

"%PYTHON%" -m esptool --port %PORT% write_flash 0x0 "%FACTORY_BIN%"
if errorlevel 1 (
  echo.
  echo ERROR: Flash failed.
  exit /b 1
)

echo.
echo =========================================
echo Done. Build and flash completed successfully.
echo =========================================
echo.

endlocal
pause