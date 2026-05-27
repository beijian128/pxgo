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

PHYSX_WRAPPER_API void pxSceneAddActor(PxHandle scene, PxHandle actor);

PHYSX_WRAPPER_API void pxSceneSimulate(PxHandle scene, float* dt);

PHYSX_WRAPPER_API int  pxSceneFetchResults(PxHandle scene, int* block);

PHYSX_WRAPPER_API void pxActorGetPosition(PxHandle actor, float* outX, float* outY, float* outZ);

PHYSX_WRAPPER_API void pxRelease(PxHandle obj);

PHYSX_WRAPPER_API void pxShutdownPhysics(PxHandle physics, PxHandle foundation);

#ifdef __cplusplus
}
#endif

#endif
