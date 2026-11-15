# 编译 pdbsym（DIA PDB 符号解析工具）
$ErrorActionPreference='Continue'
$msvc='E:\Softwares\VS2022BuildTools\VC\Tools\MSVC\14.44.35207'
$cl=Join-Path $msvc 'bin\Hostx64\x64\cl.exe'
$sdkRoot='C:\Program Files (x86)\Windows Kits\10\Include'
$sdkVer=(Get-ChildItem $sdkRoot -Directory | Sort-Object Name | Select-Object -Last 1).Name
$sdkLib='C:\Program Files (x86)\Windows Kits\10\Lib'
$sdkLibVer=(Get-ChildItem $sdkLib -Directory | Sort-Object Name | Select-Object -Last 1).Name
$inc=@("/I`"$msvc\include`"", "/I`"$sdkRoot\$sdkVer\ucrt`"", "/I`"$sdkRoot\$sdkVer\um`"", "/I`"$sdkRoot\$sdkVer\shared`"", '/I"E:\Softwares\VS2022BuildTools\DIA SDK\include"')
$libs=@('/LIBPATH:"E:\Softwares\VS2022BuildTools\DIA SDK\lib\amd64"','diaguids.lib','ole32.lib','oleaut32.lib','advapi32.lib',"/LIBPATH:`"$msvc\lib\x64`"", "/LIBPATH:`"$sdkLib\$sdkLibVer\ucrt\x64`"", "/LIBPATH:`"$sdkLib\$sdkLibVer\um\x64`"")
$out='E:\PCGame\Haizeiwang\tools\pdbsym\pdbsym.exe'
& $cl /nologo /EHsc /std:c++17 $inc 'E:\PCGame\Haizeiwang\tools\pdbsym\pdbsym.cpp' /Fe:"$out" /Fo:"E:\PCGame\Haizeiwang\tools\pdbsym\pdbsym.obj" /link $libs
if (Test-Path $out) { "BUILT: $out" } else { "BUILD FAILED" }
