@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   PhysX 3.4 CGO Demo - Build Script
echo ============================================
echo.

set "PHYSX_ROOT=E:\PhysX-3.4-master"
set "PHYSX_INC=%PHYSX_ROOT%\PhysX_3.4\Include"
set "PXSHARED_INC=%PHYSX_ROOT%\PxShared\include"
set "PHYSX_LIB=%PHYSX_ROOT%\PhysX_3.4\Lib\vc14win64"
set "PXSHARED_LIB=%PHYSX_ROOT%\PxShared\lib\vc14win64"
set "PHYSX_BIN=%PHYSX_ROOT%\PhysX_3.4\Bin\vc14win64"
set "PXSHARED_BIN=%PHYSX_ROOT%\PxShared\bin\vc14win64"

echo PhysX Root: %PHYSX_ROOT%
echo.

REM --- Find Visual Studio 2017 ---
set "VCVARS="
if exist "E:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=E:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
)
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat"
)
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\VC\Auxiliary\Build\vcvarsall.bat"
)
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
)
if exist "C:\Program Files\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=C:\Program Files\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat"
)
if exist "C:\Program Files\Microsoft Visual Studio\2017\Professional\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=C:\Program Files\Microsoft Visual Studio\2017\Professional\VC\Auxiliary\Build\vcvarsall.bat"
)
if exist "C:\Program Files\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VCVARS=C:\Program Files\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
)

if "%VCVARS%"=="" (
    for /f "usebackq tokens=*" %%i in (`where vswhere.exe 2^>nul`) do (
        for /f "usebackq tokens=*" %%j in (`"%%i" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do (
            if exist "%%j\VC\Auxiliary\Build\vcvarsall.bat" (
                set "VCVARS=%%j\VC\Auxiliary\Build\vcvarsall.bat"
            )
        )
    )
)

if "%VCVARS%"=="" (
    echo [WARNING] VS2017 not found in standard locations.
    echo Please run vcvarsall.bat manually, then re-run this script.
    exit /b 1
)

echo Found VS2017: %VCVARS%
echo.

REM --- Save original PATH ---
set "SAVED_PATH=%PATH%"

REM --- Setup MSVC environment ---
call "%VCVARS%" x64
if %ERRORLEVEL% neq 0 (
    echo ERROR: vcvarsall.bat x64 failed
    exit /b 1
)
echo [OK] MSVC x64 environment configured
echo.

REM --- Step 1: Compile C++ wrapper to DLL with PhysX libs ---
echo [1/3] Compiling physx_wrapper.cpp to physx_wrapper.dll ...
cl /nologo /LD /EHsc /MT /D NDEBUG /D PHYSX_WRAPPER_EXPORTS ^
    /I"%PHYSX_INC%" ^
    /I"%PXSHARED_INC%" ^
    /I. ^
    wrapper\physx_wrapper.cpp ^
    /link ^
    "%PHYSX_LIB%\PhysX3CHECKED_x64.lib" ^
    "%PHYSX_LIB%\PhysX3CommonCHECKED_x64.lib" ^
    "%PHYSX_LIB%\PhysX3CookingCHECKED_x64.lib" ^
    "%PHYSX_LIB%\PhysX3CharacterKinematicCHECKED_x64.lib" ^
    "%PHYSX_LIB%\PhysX3ExtensionsCHECKED.lib" ^
    "%PHYSX_LIB%\PhysX3VehicleCHECKED.lib" ^
    "%PHYSX_LIB%\LowLevelCHECKED.lib" ^
    "%PHYSX_LIB%\LowLevelAABBCHECKED.lib" ^
    "%PHYSX_LIB%\LowLevelDynamicsCHECKED.lib" ^
    "%PHYSX_LIB%\LowLevelClothCHECKED.lib" ^
    "%PHYSX_LIB%\LowLevelParticlesCHECKED.lib" ^
    "%PHYSX_LIB%\SceneQueryCHECKED.lib" ^
    "%PHYSX_LIB%\SimulationControllerCHECKED.lib" ^
    "%PXSHARED_LIB%\PxFoundationCHECKED_x64.lib" ^
    "%PXSHARED_LIB%\PxPvdSDKCHECKED_x64.lib" ^
    "%PXSHARED_LIB%\PxTaskCHECKED_x64.lib" ^
    "%PXSHARED_LIB%\PsFastXmlCHECKED_x64.lib" ^
    /OUT:physx_wrapper.dll /IMPLIB:physx_wrapper.lib
if %ERRORLEVEL% neq 0 (
    echo ERROR: DLL compilation failed
    exit /b 1
)
echo [OK] physx_wrapper.dll + physx_wrapper.lib created
echo.

REM --- Step 2: Copy PhysX runtime DLLs ---
echo [2/3] Copying runtime DLLs ...
if exist "%PHYSX_BIN%\PhysX3CHECKED_x64.dll"       copy /y "%PHYSX_BIN%\PhysX3CHECKED_x64.dll"       . >nul
if exist "%PHYSX_BIN%\PhysX3CommonCHECKED_x64.dll"  copy /y "%PHYSX_BIN%\PhysX3CommonCHECKED_x64.dll"  . >nul
if exist "%PHYSX_BIN%\PhysX3CookingCHECKED_x64.dll"  copy /y "%PHYSX_BIN%\PhysX3CookingCHECKED_x64.dll"  . >nul
if exist "%PHYSX_BIN%\PhysX3CharacterKinematicCHECKED_x64.dll" copy /y "%PHYSX_BIN%\PhysX3CharacterKinematicCHECKED_x64.dll" . >nul
if exist "%PXSHARED_BIN%\PxFoundationCHECKED_x64.dll" copy /y "%PXSHARED_BIN%\PxFoundationCHECKED_x64.dll" . >nul
if exist "%PXSHARED_BIN%\PxPvdSDKCHECKED_x64.dll"      copy /y "%PXSHARED_BIN%\PxPvdSDKCHECKED_x64.dll"      . >nul
echo [OK] DLLs copied
echo.

REM --- Step 3: Build Go program ---
echo [3/3] Building Go program ...
set CGO_ENABLED=0

go build -o px_demo.exe .
if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: go build failed.
    exit /b 1
)

echo.
echo ============================================
echo   BUILD SUCCESSFUL!
echo   Run: px_demo.exe
echo ============================================

endlocal
