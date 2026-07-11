@echo off
rem Builds the vendored Box3D C library into a static archive that dub links.
rem Invoked by dub via preBuildCommands. Safe to run repeatedly (incremental).
setlocal
set DIR=%~dp0
set SRC=%DIR%box3d
set BUILD=%SRC%\build

where cmake >nul 2>nul
if errorlevel 1 (
    echo box3d.d: cmake is required to build the vendored Box3D library. 1>&2
    echo          Install cmake, or use the "system" configuration to link a system Box3D. 1>&2
    exit /b 1
)

cmake -S "%SRC%" -B "%BUILD%" -DCMAKE_BUILD_TYPE=Release >nul || exit /b 1
cmake --build "%BUILD%" --config Release >nul || exit /b 1

rem Locate the built import/static library across generator layouts.
if exist "%BUILD%\Release\box3d.lib" (
    copy /y "%BUILD%\Release\box3d.lib" "%DIR%box3d.lib" >nul
) else if exist "%BUILD%\box3d.lib" (
    copy /y "%BUILD%\box3d.lib" "%DIR%box3d.lib" >nul
) else (
    echo box3d.d: failed to locate built box3d.lib under %BUILD% 1>&2
    exit /b 1
)
