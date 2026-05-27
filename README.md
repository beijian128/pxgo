# px-go

Windows 平台 Go 语言调用 PhysX 3.4 物理引擎的示例项目。

## 特性

- 使用 Go `syscall` 动态加载 DLL，绕过 cgo 编译兼容性问题
- C++ Wrapper DLL 提供简洁的 C 接口
- 完整演示：创建地面平面 + 下落的动态盒子

## 快速开始

### 环境要求

- Windows 11 x64
- Visual Studio 2017 (MSVC)
- Go 1.21+
- PhysX 3.4 源代码编译（使用 VS2017）

### 构建

```powershell
# 1. 克隆项目
git clone https://github.com/beijian128/pxgo.git
cd pxgo

# 2. 修改 build.bat 中的 PhysX 路径
# set "PHYSX_ROOT=E:\PhysX-3.4-master"

# 3. 运行构建脚本
.\build.bat
```

### 运行

```powershell
.\px_demo.exe
```

预期输出：

```
=== PhysX 3.4 CGO Demo (syscall) ===
[OK] Foundation created
[OK] Physics created
[OK] Scene created
[OK] Material created
[OK] Static plane added
[OK] Dynamic box created at (0, 10, 0)

--- Starting Simulation ---
Frame   0: box position = (0.000, 9.997, 0.000)
Frame  30: box position = (0.000, 8.648, 0.000)
Frame  60: box position = (0.000, 4.847, 0.000)
Frame  80: box position = (0.000, 0.950, 0.000)

Box hit the ground, stopping simulation.

--- Simulation Finished ---
[OK] PhysX shutdown complete
```

## 项目结构

```
px-go/
├── main.go                    # Go 主程序
├── physx_wrapper.h            # C 接口头文件
├── wrapper/
│   └── physx_wrapper.cpp     # C++ wrapper 实现
├── build.bat                  # 构建脚本
├── go.mod                     # Go 模块
└── README.md
```

## 技术原理

由于 PhysX 3.4 是 C++ 库，而 Go cgo 在 Windows 上与 MSVC 存在兼容性问题，采用三层架构：

```
Go (syscall) → C Wrapper DLL (MSVC) → PhysX C++ API
```

### 关键实现点

1. **DLL 导出**: 使用 `__declspec(dllexport)` + `extern "C"`
2. **浮点参数**: Windows x64 syscall 无法处理浮点寄存器，所有浮点参数通过指针传递
3. **版本匹配**: `PxCreateFoundation` 使用 `PX_FOUNDATION_VERSION`

## 依赖文件

运行需要以下 DLL（构建脚本会自动复制）：

- `physx_wrapper.dll` - 自定义包装
- `PxFoundationCHECKED_x64.dll` - 基础库
- `PhysX3CommonCHECKED_x64.dll` - 公共几何
- `PhysX3CHECKED_x64.dll` - 物理核心
- `PhysX3CookingCHECKED_x64.dll` - 烘焙工具

## 文档

详细说明请参考 [WINDOWS_CGO_PHYSX34_GUIDE.md](WINDOWS_CGO_PHYSX34_GUIDE.md)

## License

MIT
