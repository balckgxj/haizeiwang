@echo off
rem ---------------------------------------------------------------------------
rem  Haizeiwang 构建脚本
rem    build.bat            编译 Debug
rem    build.bat Release    编译 Release
rem    build.bat Debug clean 清理后重配
rem ---------------------------------------------------------------------------
setlocal
rem MSBuild/CL.exe 会把大小写不同的同名环境变量视为重复键并报 MSB6001，
rem 因此构建前清掉代理变量（不影响系统/用户级设置）。
set "http_proxy="
set "https_proxy="
set "all_proxy="
set "no_proxy="
set "HTTP_PROXY="
set "HTTPS_PROXY="
set "ALL_PROXY="
set "NO_PROXY="
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
