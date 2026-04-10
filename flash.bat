@echo off
setlocal

rem ===== Config =====
set "PROJECT_DIR=C:\dev\EchoEar"
set "CONFIG_FILE=echoear1.0-full-animation.yaml"
set "PORT=COM3"

rem ESPHome path you asked to use
set "ESPHOME=C:\Users\Yoav\AppData\Local\Programs\Python\Python313\Scripts\esphome.exe"

rem Matching Python for esptool
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