@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title ComputerWorkAlarm

rem ============================================================
rem  ComputerWorkAlarm
rem  Следит за временем работы компьютера и предупреждает:
rem    - за 30 минут до 4 часов работы (через 3 ч 30 мин);
rem    - когда компьютер проработал 4 часа.
rem
rem  Запуск:
rem    WorkAlarm.bat            - запустить слежение
rem    WorkAlarm.bat install    - добавить в автозагрузку Windows
rem    WorkAlarm.bat uninstall  - убрать из автозагрузки
rem ============================================================

rem ---- Настройки (в минутах) ---------------------------------
set "LIMIT_MIN=240"
set "WARN_BEFORE_MIN=30"
rem Интервал проверки в секундах
set "CHECK_SEC=60"
rem Откуда считать время работы:
rem   session - с момента запуска скрипта (надёжно при "быстром запуске" Windows,
rem             при запуске из автозагрузки = с момента входа в систему)
rem   boot    - с момента последней загрузки Windows
set "COUNT_FROM=session"
rem ------------------------------------------------------------

set "SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ComputerWorkAlarm.lnk"

if /i "%~1"=="install" goto :install
if /i "%~1"=="uninstall" goto :uninstall

set /a WARN_AT_MIN=LIMIT_MIN-WARN_BEFORE_MIN

rem Запоминаем точку отсчёта (Unix-время в секундах)
if /i "%COUNT_FROM%"=="boot" (
    for /f %%i in ('powershell -NoProfile -Command "[DateTimeOffset]::new((Get-CimInstance Win32_OperatingSystem).LastBootUpTime).ToUnixTimeSeconds()"') do set "START=%%i"
) else (
    for /f %%i in ('powershell -NoProfile -Command "[DateTimeOffset]::Now.ToUnixTimeSeconds()"') do set "START=%%i"
)

if not defined START (
    echo Не удалось определить время начала работы.
    pause
    exit /b 1
)

set "WARNED=0"
set "ALERTED=0"

echo ComputerWorkAlarm запущен. Режим отсчёта: %COUNT_FROM%
echo Предупреждение через %WARN_AT_MIN% мин, сигнал через %LIMIT_MIN% мин работы.
echo Не закрывайте это окно (его можно свернуть).
echo.

:loop
for /f %%i in ('powershell -NoProfile -Command "[int](([DateTimeOffset]::Now.ToUnixTimeSeconds() - %START%) / 60)"') do set "ELAPSED=%%i"
if not defined ELAPSED set "ELAPSED=0"

set /a H=ELAPSED/60, M=ELAPSED%%60
echo [%time:~0,8%] Компьютер работает: !H! ч !M! мин

if "!WARNED!"=="0" if !ELAPSED! GEQ %WARN_AT_MIN% if !ELAPSED! LSS %LIMIT_MIN% (
    set "WARNED=1"
    call :notify "Через %WARN_BEFORE_MIN% минут компьютер проработает 4 часа. Пора закругляться и готовиться к перерыву." "Предупреждение" "Warning"
)

if "!ALERTED!"=="0" if !ELAPSED! GEQ %LIMIT_MIN% (
    set "WARNED=1"
    set "ALERTED=1"
    call :notify "Компьютер работает уже 4 часа! Сделайте перерыв." "Время вышло" "Exclamation"
    echo Компьютер достиг 4 часов работы.
    goto :done
)

timeout /t %CHECK_SEC% /nobreak >nul
goto :loop

:done
echo Слежение завершено.
timeout /t 10 >nul
exit /b 0

rem ---- Уведомление: звуковой сигнал + окно сообщения ----------
rem %1 - текст, %2 - заголовок, %3 - значок (Warning / Exclamation / Information)
:notify
echo.
echo ************************************************************
echo   %~1
echo ************************************************************
echo.
start "" powershell -NoProfile -WindowStyle Hidden -Command "[System.Media.SystemSounds]::%~3.Play(); Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('%~1', 'ComputerWorkAlarm: %~2', 'OK', '%~3', 'Button1', 'ServiceNotification') | Out-Null"
exit /b 0

rem ---- Автозагрузка -------------------------------------------
:install
powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT%'); $s.TargetPath='%~f0'; $s.WorkingDirectory='%~dp0'; $s.WindowStyle=7; $s.Save()"
if exist "%SHORTCUT%" (
    echo ComputerWorkAlarm добавлен в автозагрузку и будет запускаться при входе в Windows.
) else (
    echo Не удалось добавить в автозагрузку.
)
pause
exit /b 0

:uninstall
if exist "%SHORTCUT%" del "%SHORTCUT%"
echo ComputerWorkAlarm удалён из автозагрузки.
pause
exit /b 0
