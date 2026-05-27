@echo off
setlocal enabledelayedexpansion
set "ARGS="
:loop
if "%~1"=="" goto run
set "arg=%~1"
if /i "!arg!"=="/Werror" goto next
if /i "!arg!"=="-Werror" goto next
set "ARGS=!ARGS! %~1"
:next
shift
goto loop
:run
cl.exe !ARGS!
exit /b %ERRORLEVEL%
