package main

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	dll            *syscall.DLL
	pxInitFoundation    *syscall.Proc
	pxCreatePhysics     *syscall.Proc
	pxCreateScene       *syscall.Proc
	pxCreateDefaultMaterial *syscall.Proc
	pxCreateStaticPlane *syscall.Proc
	pxCreateDynamicBox  *syscall.Proc
	pxSceneAddActor     *syscall.Proc
	pxSceneSimulate     *syscall.Proc
	pxSceneFetchResults *syscall.Proc
	pxActorGetPosition  *syscall.Proc
	pxRelease           *syscall.Proc
	pxShutdownPhysics   *syscall.Proc
)

func loadProc(name string) *syscall.Proc {
	p := dll.MustFindProc(name)
	return p
}

func main() {
	var err error

	exePath, _ := os.Executable()
	exeDir := filepath.Dir(exePath)
	dllPath := filepath.Join(exeDir, "physx_wrapper.dll")

	currentPath := os.Getenv("PATH")
	os.Setenv("PATH", exeDir+";"+currentPath)

	deps := []string{"PxFoundationCHECKED_x64.dll", "PhysX3CommonCHECKED_x64.dll", "PhysX3CHECKED_x64.dll", "PhysX3CookingCHECKED_x64.dll"}
	for _, dep := range deps {
		depPath := filepath.Join(exeDir, dep)
		_, err = syscall.LoadDLL(depPath)
		if err != nil {
			fmt.Printf("WARNING: Cannot pre-load %s: %v\n", dep, err)
		} else {
			fmt.Printf("[OK] Pre-loaded %s\n", dep)
		}
	}

	dll, err = syscall.LoadDLL(dllPath)
	if err != nil {
		fmt.Printf("ERROR: Cannot load physx_wrapper.dll: %v\n", err)
		return
	}

	pxInitFoundation = loadProc("pxInitFoundation")
	pxCreatePhysics = loadProc("pxCreatePhysics")
	pxCreateScene = loadProc("pxCreateScene")
	pxCreateDefaultMaterial = loadProc("pxCreateDefaultMaterial")
	pxCreateStaticPlane = loadProc("pxCreateStaticPlane")
	pxCreateDynamicBox = loadProc("pxCreateDynamicBox")
	pxSceneAddActor = loadProc("pxSceneAddActor")
	pxSceneSimulate = loadProc("pxSceneSimulate")
	pxSceneFetchResults = loadProc("pxSceneFetchResults")
	pxActorGetPosition = loadProc("pxActorGetPosition")
	pxRelease = loadProc("pxRelease")
	pxShutdownPhysics = loadProc("pxShutdownPhysics")

	fmt.Println("=== PhysX 3.4 CGO Demo (syscall) ===")

	foundation, _, _ := pxInitFoundation.Call()
	if foundation == 0 {
		fmt.Println("ERROR: pxInitFoundation failed")
		return
	}
	fmt.Println("[OK] Foundation created")

	physics, _, _ := pxCreatePhysics.Call(foundation)
	if physics == 0 {
		fmt.Println("ERROR: pxCreatePhysics failed")
		pxRelease.Call(foundation)
		return
	}
	fmt.Println("[OK] Physics created")

	gravityY := float32(-9.81)
	scene, _, _ := pxCreateScene.Call(physics, uintptr(unsafe.Pointer(&gravityY)))
	if scene == 0 {
		fmt.Println("ERROR: pxCreateScene failed")
		pxShutdownPhysics.Call(physics, foundation)
		return
	}
	fmt.Println("[OK] Scene created")

	staticFriction := float32(0.5)
	dynamicFriction := float32(0.5)
	restitution := float32(0.6)
	material, _, _ := pxCreateDefaultMaterial.Call(physics, uintptr(unsafe.Pointer(&staticFriction)), uintptr(unsafe.Pointer(&dynamicFriction)), uintptr(unsafe.Pointer(&restitution)))
	if material == 0 {
		fmt.Println("ERROR: pxCreateDefaultMaterial failed")
		pxRelease.Call(scene)
		pxShutdownPhysics.Call(physics, foundation)
		return
	}
	fmt.Println("[OK] Material created")

	plane, _, _ := pxCreateStaticPlane.Call(physics, material)
	if plane == 0 {
		fmt.Println("ERROR: pxCreateStaticPlane failed")
		pxRelease.Call(material)
		pxRelease.Call(scene)
		pxShutdownPhysics.Call(physics, foundation)
		return
	}
	pxSceneAddActor.Call(scene, plane)
	fmt.Println("[OK] Static plane added")

	boxPosX, boxPosY, boxPosZ := float32(0), float32(10), float32(0)
	boxHalfX, boxHalfY, boxHalfZ := float32(1), float32(1), float32(1)
	boxDensity := float32(1.0)
	box, _, _ := pxCreateDynamicBox.Call(physics, material,
		uintptr(unsafe.Pointer(&boxPosX)),
		uintptr(unsafe.Pointer(&boxPosY)),
		uintptr(unsafe.Pointer(&boxPosZ)),
		uintptr(unsafe.Pointer(&boxHalfX)),
		uintptr(unsafe.Pointer(&boxHalfY)),
		uintptr(unsafe.Pointer(&boxHalfZ)),
		uintptr(unsafe.Pointer(&boxDensity)),
	)
	if box == 0 {
		fmt.Println("ERROR: pxCreateDynamicBox failed")
		pxRelease.Call(plane)
		pxRelease.Call(material)
		pxRelease.Call(scene)
		pxShutdownPhysics.Call(physics, foundation)
		return
	}
	pxSceneAddActor.Call(scene, box)
	fmt.Println("[OK] Dynamic box created at (0, 10, 0)")

	fmt.Println("\n--- Starting Simulation ---")

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

		if i%30 == 0 || y <= 1.1 {
			fmt.Printf("Frame %3d: box position = (%.3f, %.3f, %.3f)\n", i, x, y, z)
		}

		if y <= 1.0 {
			fmt.Println("\nBox hit the ground, stopping simulation.")
			break
		}
	}

	fmt.Println("\n--- Simulation Finished ---")
	fmt.Println("[OK] PhysX shutdown complete")
}

func newFloat32(v float32) *float32 {
	return &v
}
