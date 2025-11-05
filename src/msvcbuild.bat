@rem Script to build LuaJIT with MSVC.
@rem Copyright (C) 2005-2022 Mike Pall. See Copyright Notice in luajit.h
@rem
@rem Open a "Visual Studio Command Prompt" (either x86 or x64).
@rem Then cd to this directory and run this script. Use the following
@rem options (in order), if needed. The default is a dynamic release build.
@rem
@rem   nogc64   disable LJ_GC64 mode for x64
@rem   debug    emit debug symbols
@rem   amalg    amalgamated build
@rem   static   static linkage

@if not defined INCLUDE goto :FAIL

@setlocal
@set SRCDIR=%~dp0
@pushd "%SRCDIR%.."
@set BUILDDIR=%CD%\build
@popd
@if not exist "%BUILDDIR%" mkdir "%BUILDDIR%"
@rem Add more debug flags here, e.g. DEBUGCFLAGS=/DLUA_USE_APICHECK
@set DEBUGCFLAGS=
@set LJCOMPILE=cl /nologo /c /O2 /W3 /D_CRT_SECURE_NO_DEPRECATE /D_CRT_STDIO_INLINE=__declspec(dllexport)__inline
@set LJLINK=link /nologo
@set LJMT=mt /nologo
@set LJLIB=lib /nologo /nodefaultlib
@set DASMDIR=..\dynasm
@set DASM=%DASMDIR%\dynasm.lua
@set DASC=vm_x64.dasc
@set BUILDTYPE=release
@set ALL_LIB=lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c lib_buffer.c

@if /i "%1"=="clean" goto CLEAN

if /i "%1"=="force" (
	set FORCE_REBUILD=1 & shift
)

if not "%FORCE_REBUILD%"=="1" (
  if exist "%BUILDDIR%\lua51.dll" (
	echo [LuaJIT] Up-to-date
    echo [LuaJIT] Up-to-date: "%BUILDDIR%\lua51.dll" skip
    goto :END
  )
)

%LJCOMPILE% /Fo"%BUILDDIR%\\" host\minilua.c
@if errorlevel 1 goto :BAD
%LJLINK% /out:"%BUILDDIR%\minilua.exe" "%BUILDDIR%\minilua.obj"
@if errorlevel 1 goto :BAD
if exist "%BUILDDIR%\minilua.exe.manifest"^
  %LJMT% -manifest "%BUILDDIR%\minilua.exe.manifest" -outputresource:"%BUILDDIR%\minilua.exe"

@set DASMFLAGS=-D WIN -D JIT -D FFI -D P64
@set LJARCH=x64
@"%BUILDDIR%\minilua"
@if errorlevel 8 goto :X64
@set DASC=vm_x86.dasc
@set DASMFLAGS=-D WIN -D JIT -D FFI
@set LJARCH=x86
@set LJCOMPILE=%LJCOMPILE% /arch:SSE2
:X64
@if "%1" neq "nogc64" goto :GC64
@shift
@set DASC=vm_x86.dasc
@set LJCOMPILE=%LJCOMPILE% /DLUAJIT_DISABLE_GC64
:GC64
"%BUILDDIR%\minilua" %DASM% -LN %DASMFLAGS% -o "%BUILDDIR%\buildvm_arch.h" %DASC%
@if errorlevel 1 goto :BAD

%LJCOMPILE% /I "." /I %DASMDIR% /I "%BUILDDIR%" /Fo"%BUILDDIR%\\" host\buildvm*.c
@if errorlevel 1 goto :BAD
%LJLINK% /out:"%BUILDDIR%\buildvm.exe" %BUILDDIR%\buildvm*.obj
@if errorlevel 1 goto :BAD
if exist "%BUILDDIR%\buildvm.exe.manifest"^
  %LJMT% -manifest "%BUILDDIR%\buildvm.exe.manifest" -outputresource:"%BUILDDIR%\buildvm.exe"

"%BUILDDIR%\buildvm" -m peobj -o "%BUILDDIR%\lj_vm.obj"
@if errorlevel 1 goto :BAD
"%BUILDDIR%\buildvm" -m bcdef -o "%BUILDDIR%\lj_bcdef.h" %ALL_LIB%
@if errorlevel 1 goto :BAD
"%BUILDDIR%\buildvm" -m ffdef -o "%BUILDDIR%\lj_ffdef.h" %ALL_LIB%
@if errorlevel 1 goto :BAD
"%BUILDDIR%\buildvm" -m libdef -o "%BUILDDIR%\lj_libdef.h" %ALL_LIB%
@if errorlevel 1 goto :BAD
"%BUILDDIR%\buildvm" -m recdef -o "%BUILDDIR%\lj_recdef.h" %ALL_LIB%
@if errorlevel 1 goto :BAD
"%BUILDDIR%\buildvm" -m vmdef -o "%BUILDDIR%\vmdef.lua" %ALL_LIB%
@if errorlevel 1 goto :BAD
"%BUILDDIR%\buildvm" -m folddef -o "%BUILDDIR%\lj_folddef.h" lj_opt_fold.c
@if errorlevel 1 goto :BAD

@if "%1" neq "debug" goto :NODEBUG
@shift
@set BUILDTYPE=debug
@set LJCOMPILE=%LJCOMPILE% /Zi %DEBUGCFLAGS%
@set LJLINK=%LJLINK% /opt:ref /opt:icf /incremental:no
:NODEBUG
@set LJLINK=%LJLINK% /%BUILDTYPE%
@set LJDLLNAME=%BUILDDIR%\lua51.dll
@set LJLIBNAME=%BUILDDIR%\lua51.lib
@set LJCOMPILE=%LJCOMPILE% /I "%BUILDDIR%" /Fo"%BUILDDIR%\\"
@if "%1"=="amalg" goto :AMALGDLL
@if "%1"=="static" goto :STATIC
%LJCOMPILE% /MD /DLUA_BUILD_AS_DLL lj_*.c lib_*.c
@if errorlevel 1 goto :BAD
%LJLINK% /DLL /out:"%LJDLLNAME%" %BUILDDIR%\lj_*.obj %BUILDDIR%\lib_*.obj
@if errorlevel 1 goto :BAD
@goto :MTDLL
:STATIC
%LJCOMPILE% lj_*.c lib_*.c
@if errorlevel 1 goto :BAD
%LJLIB% /OUT:%LJLIBNAME% %BUILDDIR%\lj_*.obj %BUILDDIR%\lib_*.obj
@if errorlevel 1 goto :BAD
@goto :MTDLL
:AMALGDLL
%LJCOMPILE% /MD /DLUA_BUILD_AS_DLL ljamalg.c
@if errorlevel 1 goto :BAD
%LJLINK% /DLL /out:"%LJDLLNAME%" %BUILDDIR%\ljamalg.obj %BUILDDIR%\lj_vm.obj
@if errorlevel 1 goto :BAD
:MTDLL
if exist "%LJDLLNAME%.manifest"^
  %LJMT% -manifest "%LJDLLNAME%.manifest" -outputresource:"%LJDLLNAME%";2

%LJCOMPILE% luajit.c
@if errorlevel 1 goto :BAD
%LJLINK% /out:"%BUILDDIR%\luajit.exe" %BUILDDIR%\luajit.obj "%LJLIBNAME%"
@if errorlevel 1 goto :BAD
if exist "%BUILDDIR%\luajit.exe.manifest"^
  %LJMT% -manifest "%BUILDDIR%\luajit.exe.manifest" -outputresource:"%BUILDDIR%\luajit.exe"

@rem Build outputs are kept under %BUILDDIR%.
@echo.
@echo === Successfully built LuaJIT for Windows/%LJARCH% ===

@goto :END
:CLEAN
@echo [LuaJIT] Cleaning build directory: %BUILDDIR%
@if exist "%BUILDDIR%" rmdir /s /q "%BUILDDIR%"
@echo [LuaJIT] Clean done.
@goto :END
:BAD
@echo.
@echo *******************************************************
@echo *** Build FAILED -- Please check the error messages ***
@echo *******************************************************
@goto :END
:FAIL
@echo You must open a "Visual Studio Command Prompt" to run this script
:END
