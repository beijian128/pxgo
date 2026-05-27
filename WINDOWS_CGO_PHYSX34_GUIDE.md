# Windows 平台使用 Go cgo 调用 PhysX 3.4 完整指南

## 目录

1. [架构设计](#架构设计)
2. [项目结构](#项目结构)
3. [关键代码实现](#关键代码实现)
4. [构建流程](#构建流程)
5. [依赖文件](#依赖文件)
6. [常见问题与解决方案](#常见问题与解决方案)
7. [技术细节](#技术细节)

---

## 架构设计

由于 PhysX 3.4 是 C++ 库，而 cgo 只能调用 C 函数，采用三层架构：

```
┌─────────────────────────────────────────────────────────────┐
│                      Go 程序 (main.go)                       │
│         syscall.LoadDLL() / syscall.Proc.Call()              │
└─────────────────────┬───────────────────────────────────────┘
                      │  cgo 无法直接调用
┌─────────────────────▼───────────────────────────────────────┐
│                C Wrapper DLL (physx_wrapper.dll)              │
│         #include "physx_wrapper.h" (extern "C")             │
│         MSVC 编译，/MT 静态 CRT                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                PhysX 3.4 静态库 + DLL                         │
│         PxFoundationCHECKED_x64.dll 等                        │
│         NVIDIA 官方预编译库                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 项目结构

```
px-go/
├── main.go                    # Go 主程序（使用 syscall 动态加载 DLL）
├── physx_wrapper.h            # C 接口头文件
├── wrapper/
│   └── physx_wrapper.cpp      # C++ wrapper 实现
├── go.mod                     # Go 模块
├── go.sum                     # Go 依赖
└── build.bat                  # 构建脚本
```

---

## 关键代码实现

### 1. C 接口头文件 (physx_wrapper.h)

```c
#ifndef PHYSX_WRAPPER_H
#define PHYSX_WRAPPER_H

#ifdef PHYSX_WRAPPER_EXPORTS
#define PHYSX_WRAPPER_API __declspec(dllexport)
#else
#define PHYSX_WRAPPER_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* PxHandle;

// 核心接口
PHYSX_WRAPPER_API PxHandle pxInitFoundation(void);
PHYSX_WRAPPER_API PxHandle pxCreatePhysics(PxHandle foundation);
PHYSX_WRAPPER_API PxHandle pxCreateScene(PxHandle physics, float* gravityY);
PHYSX_WRAPPER_API PxHandle pxCreateDefaultMaterial(PxHandle physics,
                                                    float* staticFriction,
                                                    float* dynamicFriction,
                                                    float* restitution);
PHYSX_WRAPPER_API PxHandle pxCreateStaticPlane(PxHandle physics, PxHandle material);
PHYSX_WRAPPER_API PxHandle pxCreateDynamicBox(PxHandle physics, PxHandle material,
                                               float* posX, float* posY, float* posZ,
                                               float* halfX, float* halfY, float* halfZ,
                                               float* density);
PHYSX_WRAPPER_API void   pxSceneAddActor(PxHandle scene, PxHandle actor);
PHYSX_WRAPPER_API void   pxSceneSimulate(PxHandle scene, float* dt);
PHYSX_WRAPPER_API int    pxSceneFetchResults(PxHandle scene, int* block);
PHYSX_WRAPPER_API void   pxActorGetPosition(PxHandle actor, float* outX, float* outY, float* outZ);
PHYSX_WRAPPER_API void   pxRelease(PxHandle obj);
PHYSX_WRAPPER_API void   pxShutdownPhysics(PxHandle physics, PxHandle foundation);

#ifdef __cplusplus
}
#endif

#endif
```

**要点**：
- 使用 `extern "C"` 确保 C++ 函数以 C ABI 导出
- 所有浮点参数使用**指针传递**（关键！Windows x64 syscall 无法正确处理浮点寄存器）
- `PxHandle` 作为 opaque 指针类型

### 2. C++ Wrapper 实现 (physx_wrapper.cpp)

```cpp
#include "physx_wrapper.h"
#include "PxPhysicsAPI.h"

using namespace physx;

// 全局状态
static PxDefaultErrorCallback  gErrorCallback;
static PxDefaultAllocator     gAllocator;
static PxFoundation*          gFoundation   = NULL;
static PxPhysics*             gPhysics      = NULL;
static PxCooking*             gCooking      = NULL;
static PxDefaultCpuDispatcher* gDispatcher   = NULL;

PHYSX_WRAPPER_API PxHandle pxInitFoundation(void)
{
    // 注意：使用 PX_FOUNDATION_VERSION，不是 PX_PHYSICS_VERSION
    gFoundation = PxCreateFoundation(PX_FOUNDATION_VERSION, gAllocator, gErrorCallback);
    return (PxHandle)gFoundation;
}

PHYSX_WRAPPER_API PxHandle pxCreatePhysics(PxHandle foundation)
{
    if (!foundation) return NULL;

    PxFoundation* f = (PxFoundation*)foundation;
    PxTolerancesScale scale;
    gPhysics = PxCreatePhysics(PX_PHYSICS_VERSION, *f, scale, true, NULL);
    if (!gPhysics) return NULL;

    gCooking = PxCreateCooking(PX_PHYSICS_VERSION, *f, PxCookingParams(scale));
    if (!gCooking) {
        gPhysics->release();
        return NULL;
    }

    PxInitExtensions(*gPhysics, NULL);
    return (PxHandle)gPhysics;
}

PHYSX_WRAPPER_API PxHandle pxCreateScene(PxHandle physics, float* gravityY)
{
    if (!gPhysics || !gravityY) return NULL;

    PxSceneDesc sceneDesc(gPhysics->getTolerancesScale());
    sceneDesc.gravity = PxVec3(0.0f, *gravityY, 0.0f);

    gDispatcher = PxDefaultCpuDispatcherCreate(1);
    if (!gDispatcher) return NULL;

    sceneDesc.cpuDispatcher = gDispatcher;
    sceneDesc.filterShader = PxDefaultSimulationFilterShader;

    PxScene* scene = gPhysics->createScene(sceneDesc);
    if (!scene) {
        gDispatcher->release();
        return NULL;
    }

    return (PxHandle)scene;
}

// ... 其他函数实现
```

**要点**：
- `PxCreateFoundation` 必须使用 `PX_FOUNDATION_VERSION`
- `PxCreatePhysics` 使用 `PX_PHYSICS_VERSION`
- 返回 `void*` 类型，C 接口中没有模板

### 3. Go 主程序 (main.go)

```go
package main

import (
    "fmt"
    "os"
    "path/filepath"
    "syscall"
    "unsafe"
)

var (
    dll                 *syscall.DLL
    pxInitFoundation    *syscall.Proc
    pxCreatePhysics     *syscall.Proc
    // ... 其他函数指针
)

func loadProc(name string) *syscall.Proc {
    return dll.MustFindProc(name)
}

func main() {
    exePath, _ := os.Executable()
    exeDir := filepath.Dir(exePath)

    // 设置 PATH 确保能找到 DLL
    os.Setenv("PATH", exeDir+";"+os.Getenv("PATH"))

    // 预加载依赖 DLL（按依赖顺序）
    deps := []string{
        "PxFoundationCHECKED_x64.dll",
        "PhysX3CommonCHECKED_x64.dll",
        "PhysX3CHECKED_x64.dll",
        "PhysX3CookingCHECKED_x64.dll",
    }
    for _, dep := range deps {
        syscall.LoadDLL(filepath.Join(exeDir, dep))
    }

    // 加载 wrapper DLL
    dll, _ = syscall.LoadDLL(filepath.Join(exeDir, "physx_wrapper.dll"))

    // 获取函数指针
    pxInitFoundation = loadProc("pxInitFoundation")
    // ... 其他函数

    // 调用示例
    foundation, _, _ := pxInitFoundation.Call()
    if foundation == 0 {
        fmt.Println("ERROR: pxInitFoundation failed")
        return
    }

    physics, _, _ := pxCreatePhysics.Call(foundation)

    // 注意：所有浮点参数使用指针
    gravity := float32(-9.81)
    scene, _, _ := pxCreateScene.Call(physics, uintptr(unsafe.Pointer(&gravity)))

    // 模拟循环
    timestep := float32(1.0 / 60.0)
    block := int32(1)
    for i := 0; i < 300; i++ {
        pxSceneSimulate.Call(scene, uintptr(unsafe.Pointer(&timestep)))
        pxSceneFetchResults.Call(scene, uintptr(unsafe.Pointer(&block)))

        var x, y, z float32
        pxActorGetPosition.Call(box,
            uintptr(unsafe.Pointer(&x)),
            uintptr(unsafe.Pointer(&y)),
            uintptr(unsafe.Pointer(&z)),
        )
        fmt.Printf("Frame %3d: (%.3f, %.3f, %.3f)\n", i, x, y, z)
    }
}
```

---

## 构建流程

### 构建脚本 (build.bat)

```batch
@echo off
setlocal

set "PHYSX_ROOT=E:\PhysX-3.4-master"
set "PHYSX_INC=%PHYSX_ROOT%\PhysX_3.4\Include"
set "PXSHARED_INC=%PHYSX_ROOT%\PxShared\include"
set "PHYSX_LIB=%PHYSX_ROOT%\PhysX_3.4\Lib\vc14win64"
set "PXSHARED_LIB=%PHYSX_ROOT%\PxShared\lib\vc14win64"
set "PHYSX_BIN=%PHYSX_ROOT%\PhysX_3.4\Bin\vc14win64"
set "PXSHARED_BIN=%PHYSX_ROOT%\PxShared\bin\vc14win64"

REM --- Step 1: 编译 C++ Wrapper 为 DLL ---
call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x64

cl /nologo /LD /EHsc /MT /D NDEBUG /D PHYSX_WRAPPER_EXPORTS ^
    /I"%PHYSX_INC%" /I"%PXSHARED_INC%" /I. ^
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
    /OUT:physx_wrapper.dll /IMPLIB:physx_wrapper.lib

REM --- Step 2: 复制运行时 DLL ---
copy /y "%PHYSX_BIN%\PhysX3CHECKED_x64.dll" .
copy /y "%PHYSX_BIN%\PhysX3CommonCHECKED_x64.dll" .
copy /y "%PHYSX_BIN%\PhysX3CookingCHECKED_x64.dll" .
copy /y "%PHYSX_BIN%\PhysX3CharacterKinematicCHECKED_x64.dll" .
copy /y "%PXSHARED_BIN%\PxFoundationCHECKED_x64.dll" .
copy /y "%PXSHARED_BIN%\PxPvdSDKCHECKED_x64.dll" .

REM --- Step 3: 编译 Go 程序 ---
set CGO_ENABLED=0
go build -o px_demo.exe .

endlocal
```

**关键编译选项**：
- `/LD`: 生成 DLL
- `/MT`: 静态 CRT（必须与 PhysX 静态库匹配）
- `/D PHYSX_WRAPPER_EXPORTS`: 导出 DLL 函数
- `/D NDEBUG`: 匹配 PhysX CHECKED 配置

---

## 依赖文件

### 运行所需的 DLL

| DLL 文件 | 位置 | 说明 |
|---------|------|------|
| `physx_wrapper.dll` | 项目目录 | 自定义 wrapper DLL |
| `PxFoundationCHECKED_x64.dll` | `PxShared\bin\vc14win64\` | 基础库 |
| `PhysX3CommonCHECKED_x64.dll` | `PhysX_3.4\Bin\vc14win64\` | 公共几何 |
| `PhysX3CHECKED_x64.dll` | `PhysX_3.4\Bin\vc14win64\` | 物理核心 |
| `PhysX3CookingCHECKED_x64.dll` | `PhysX_3.4\Bin\vc14win64\` | 烘焙工具 |

### 编译所需的 LIB

| LIB 文件 | 位置 |
|---------|------|
| `PxFoundationCHECKED_x64.lib` | `PxShared\lib\vc14win64\` |
| `PhysX3CHECKED_x64.lib` | `PhysX_3.4\Lib\vc14win64\` |
| `PhysX3CommonCHECKED_x64.lib` | `PhysX_3.4\Lib\vc14win64\` |
| `PhysX3CookingCHECKED_x64.lib` | `PhysX_3.4\Lib\vc14win64\` |
| `PhysX3ExtensionsCHECKED.lib` | `PhysX_3.4\Lib\vc14win64\` |

---

## 常见问题与解决方案

### 问题 1: 编译错误 - CRT 不匹配

```
error LNK2038: 检测到"RuntimeLibrary"的不匹配项: 值"MT_StaticRelease"不匹配值"MD_DynamicRelease"
```

**原因**: PhysX 静态库使用 `/MT`（静态 CRT），但编译时使用了 `/MD`（动态 CRT）。

**解决**: 使用 `/MT` 编译选项。

### 问题 2: DLL 加载失败 (错误码 126)

```
ERROR: Cannot load physx_wrapper.dll: The specified module could not be found.
```

**原因**: 缺少依赖的 DLL 文件。

**解决**: 检查并复制所有 PhysX 运行时 DLL 到运行目录：
```powershell
# 检查 DLL 依赖
dumpbin /imports physx_wrapper.dll
```

### 问题 3: 版本不匹配

```
Wrong version: foundation version is 0x01000000, tried to create 0x03040200
```

**原因**: `PxCreateFoundation` 使用了错误的版本号。

**解决**: 使用 `PX_FOUNDATION_VERSION` 而不是 `PX_PHYSICS_VERSION`：
```cpp
// 错误
gFoundation = PxCreateFoundation(PX_PHYSICS_VERSION, ...);

// 正确
gFoundation = PxCreateFoundation(PX_FOUNDATION_VERSION, ...);
```

### 问题 4: 浮点参数传递错误

位置值始终为 0 或垃圾数据。

**原因**: Windows x64 的 syscall 无法正确处理浮点参数（通过 XMM 寄存器传递）。

**解决**: 所有浮点参数使用指针传递：
```go
// 错误
scene, _, _ := pxCreateScene.Call(physics, uintptr(float32(-9.81)))

// 正确
gravity := float32(-9.81)
scene, _, _ := pxCreateScene.Call(physics, uintptr(unsafe.Pointer(&gravity)))
```

### 问题 5: 程序结束时崩溃 (堆损坏)

```
Exception 0xc0000005
PC=...
exit code: -1073740940 (0xC0000374)
```

**原因**: PhysX 资源释放顺序问题或 CRT 冲突。

**解决**: 
- 简化清理逻辑，让操作系统处理资源释放
- 或确保正确的释放顺序：Cooking → Physics → Dispatcher → Pvd → Foundation

---

## 技术细节

### 为什么选择 syscall 而非 cgo?

| 方案 | 优点 | 缺点 |
|------|------|------|
| **syscall (推荐)** | 构建简单，无编译冲突 | 需要手动管理 DLL |
| **cgo + MSVC** | 原生集成 | Go 添加的 `/Werror` 与 MSVC 不兼容 |
| **cgo + MinGW** | 构建简单 | 无法链接 MSVC 编译的 PhysX 库 |

### Windows x64 调用约定

Windows x64 使用以下调用约定：

1. **整数参数**: RCX, RDX, R8, R9（寄存器），然后栈
2. **浮点参数**: XMM0-XMM3（寄存器）
3. **返回值**: RAX（整数），XMM0（浮点）

`syscall.Proc.Call()` 在 Windows x64 上只能正确传递整数参数，无法处理浮点寄存器。

### PhysX 版本号

```c
// PxFoundationVersion.h
#define PX_FOUNDATION_VERSION_MAJOR 1
#define PX_FOUNDATION_VERSION_MINOR 0
#define PX_FOUNDATION_VERSION_BUGFIX 0
// 实际值: 0x01000000

// PxPhysicsVersion.h
#define PX_PHYSICS_VERSION_MAJOR 3
#define PX_PHYSICS_VERSION_MINOR 4
#define PX_PHYSICS_VERSION_BUGFIX 2
// 实际值: 0x03040200
```

---

## 参考链接

- [PhysX 3.4 官方文档](https://docs.nvidia.com/gameworks/content/gameworkslibrary/physx/guide/Manual/index.html)
- [Go syscall 包文档](https://pkg.go.dev/syscall)
- [Windows x64 ABI](https://docs.microsoft.com/en-us/cpp/build/x64-software-conventions)
