@echo off
rem ---------------------------------------------------------------------------
rem  Haizeiwang 构建脚本
rem    build.bat            编译 Debug
rem    build.bat Release    编译 Release
rem    build.bat Debug clean 清理后重配
rem ---------------------------------------------------------------------------
setlocal
set ROOT=%~dp0
set CMAKE="E:\Softwares\VS2022BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set CFG=%1
if "%CFG%"=="" set CFG=Debug
set ACTION=%2

if /i "%ACTION%"=="clean" (
    if exist "%ROOT%build" rmdir /s /q "%ROOT%build"
)

if not exist "%ROOT%build\CMakeCache.txt" (
    %CMAKE% -S "%ROOT%." -B "%ROOT%build" -G "Visual Studio 17 2022" -A Win32 || exit /b 1
)

%CMAKE% --build "%ROOT%build" --config %CFG% --target Haizeiwang --parallel 8 -- /nodeReuse:false /nologo /v:m
if errorlevel 1 (
    echo.
    echo [FAILED] 详见 build 目录下的输出
    exit /b 1
)
echo.
echo [OK] %ROOT%build\%CFG%\Haizeiwang.exe
endlocal
