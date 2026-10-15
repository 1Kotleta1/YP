@echo off
chcp 65001 >nul
set "PATH=C:\Users\George\flutter\bin;C:\Program Files\Git\bin;%PATH%"
cd /d "%~dp0"

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter не найден. Проверьте, что существует C:\Users\George\flutter\bin
  pause
  exit /b 1
)

echo Зависимости...
call flutter pub get
if errorlevel 1 goto fail

echo.
echo Запуск в браузере (Edge). Порт 5555.
echo Остановка: q в этом окне или закройте вкладку браузера.
echo.

call flutter run -d edge --web-port=5555
if errorlevel 1 goto fail
exit /b 0

:fail
echo.
echo Ошибка запуска. Доступные устройства:
call flutter devices
echo.
echo Можно вручную: flutter run -d edge --web-port=5555
pause
exit /b 1
