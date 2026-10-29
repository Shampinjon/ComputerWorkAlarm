@echo off
rem ComputerWorkAlarm - предупреждает за 30 минут до 4 часов работы и ровно через 4 часа.
rem   WorkAlarm.bat            - запустить слежение
rem   WorkAlarm.bat install    - добавить в автозагрузку
rem   WorkAlarm.bat uninstall  - убрать из автозагрузки
rem Вся логика написана на PowerShell ниже; cmd выполняет только эти строки.
set "WA_SELF=%~f0"
set "WA_MODE=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:WA_SELF,[Text.Encoding]::UTF8); Invoke-Expression $t.Substring($t.IndexOf('#'+'PS-CODE')+8)"
exit /b %errorlevel%

#PS-CODE
# ---- Настройки ----------------------------------------------
$LimitMin       = 240      # лимит работы, минут
$WarnBeforeMin  = 30       # за сколько минут предупреждать
$CheckSec       = 30       # как часто проверять, секунд
# Откуда считать время:
#   'session' - с запуска скрипта (при автозагрузке = с входа в систему)
#   'boot'    - с момента загрузки Windows
$CountFrom      = 'session'
# -------------------------------------------------------------

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = 'ComputerWorkAlarm'

$shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'ComputerWorkAlarm.lnk'

if ($env:WA_MODE -eq 'install') {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
    $s.TargetPath = $env:WA_SELF
    $s.WorkingDirectory = Split-Path $env:WA_SELF
    $s.WindowStyle = 7   # свёрнутое окно
    $s.Save()
    Write-Host 'Добавлено в автозагрузку: скрипт будет запускаться при входе в Windows.'
    Read-Host 'Нажмите Enter'
    return
}
if ($env:WA_MODE -eq 'uninstall') {
    Remove-Item $shortcut -ErrorAction SilentlyContinue
    Write-Host 'Удалено из автозагрузки.'
    Read-Host 'Нажмите Enter'
    return
}

# Не запускать вторую копию
$created = $false
$mutex = New-Object Threading.Mutex($true, 'Local\ComputerWorkAlarm', [ref]$created)
if (-not $created) {
    Write-Host 'ComputerWorkAlarm уже запущен.'
    Start-Sleep 3
    return
}

Add-Type -AssemblyName System.Windows.Forms

function Show-Alert([string]$Text, [string]$Icon) {
    Write-Host ''
    Write-Host ('*' * 60)
    Write-Host "  $Text"
    Write-Host ('*' * 60)
    [Media.SystemSounds]::Exclamation.Play()
    # TopMost-владелец, чтобы окно появилось поверх остальных
    $owner = New-Object Windows.Forms.Form -Property @{ TopMost = $true }
    [void][Windows.Forms.MessageBox]::Show($owner, $Text, 'ComputerWorkAlarm', 'OK', $Icon)
    $owner.Dispose()
}

if ($CountFrom -eq 'boot') {
    $start = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
} else {
    $start = Get-Date
}

$warnAt = $LimitMin - $WarnBeforeMin
Write-Host "ComputerWorkAlarm запущен. Отсчёт: $CountFrom, с $($start.ToString('HH:mm:ss'))."
Write-Host "Предупреждение на $warnAt-й минуте, сигнал на $LimitMin-й. Окно можно свернуть, но не закрывайте."

$warned = $false
while ($true) {
    $elapsed = [int][Math]::Floor(((Get-Date) - $start).TotalMinutes)
    Write-Host ("[{0:HH:mm:ss}] Работает: {1} ч {2} мин" -f (Get-Date), [Math]::Floor($elapsed / 60), ($elapsed % 60))

    if ($elapsed -ge $LimitMin) {
        Show-Alert 'Компьютер работает уже 4 часа! Сделайте перерыв.' 'Exclamation'
        break
    }
    if (-not $warned -and $elapsed -ge $warnAt) {
        $warned = $true
        Show-Alert "Через $($LimitMin - $elapsed) мин компьютер проработает 4 часа. Готовьтесь к перерыву." 'Warning'
    }
    Start-Sleep -Seconds $CheckSec
}
