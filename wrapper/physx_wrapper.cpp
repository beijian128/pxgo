#include "physx_wrapper.h"

#include "PxPhysicsAPI.h"

using namespace physx;

static PxDefaultErrorCallback  gErrorCallback;
static PxDefaultAllocator      gAllocator;
static PxFoundation*           gFoundation   = NULL;
static PxPhysics*              gPhysics      = NULL;
static PxCooking*              gCooking      = NULL;
static PxDefaultCpuDispatcher* gDispatcher   = NULL;

PHYSX_WRAPPER_API PxHandle pxInitFoundation(void)
{
    gFoundation = PxCreateFoundation(PX_FOUNDATION_VERSION, gAllocator, gErrorCallback);
    return (PxHandle)gFoundation;
}

PHYSX_WRAPPER_API PxHandle pxCreatePhysics(PxHandle foundation)
{
    if (!foundation)
        return NULL;

    PxFoundation* f = (PxFoundation*)foundation;

    PxTolerancesScale scale;
    gPhysics = PxCreatePhysics(PX_PHYSICS_VERSION, *f, scale, true, NULL);
    if (!gPhysics)
        return NULL;

    gCooking = PxCreateCooking(PX_PHYSICS_VERSION, *f, PxCookingParams(scale));
    if (!gCooking)
    {
        gPhysics->release();
        gPhysics = NULL;
        return NULL;
    }

    PxInitExtensions(*gPhysics, NULL);

    return (PxHandle)gPhysics;
}

PHYSX_WRAPPER_API PxHandle pxCreateScene(PxHandle physics, float* gravityY)
{
    if (!gPhysics || !physics || !gravityY)
        return NULL;

    PxSceneDesc sceneDesc(gPhysics->getTolerancesScale());
    sceneDesc.gravity = PxVec3(0.0f, *gravityY, 0.0f);

    gDispatcher = PxDefaultCpuDispatcherCreate(1);
    if (!gDispatcher)
        return NULL;

    sceneDesc.cpuDispatcher = gDispatcher;
    sceneDesc.filterShader = PxDefaultSimulationFilterShader;

    PxScene* scene = gPhysics->createScene(sceneDesc);
    if (!scene)
    {
        gDispatcher->release();
        gDispatcher = NULL;
        return NULL;
    }

    return (PxHandle)scene;
}

PHYSX_WRAPPER_API PxHandle pxCreateDefaultMaterial(PxHandle physics,
                                                  float* staticFriction,
                                                  float* dynamicFriction,
                                                  float* restitution)
{
    if (!physics || !staticFriction || !dynamicFriction || !restitution)
        return NULL;

    PxPhysics* px = (PxPhysics*)physics;
    PxMaterial* mat = px->createMaterial(*staticFriction, *dynamicFriction, *restitution);
    return (PxHandle)mat;
}

PHYSX_WRAPPER_API PxHandle pxCreateStaticPlane(PxHandle physics, PxHandle material)
{
    PxPhysics* px = (PxPhysics*)physics;
    PxMaterial* mat = (PxMaterial*)material;
    if (!px || !mat)
        return NULL;

    PxRigidStatic* plane = PxCreatePlane(*px, PxPlane(PxVec3(0.0f, 1.0f, 0.0f), 0.0f), *mat);
    return (PxHandle)plane;
}

PHYSX_WRAPPER_API PxHandle pxCreateDynamicBox(PxHandle physics, PxHandle material,
                                             float* posX, float* posY, float* posZ,
                                             float* halfX, float* halfY, float* halfZ,
                                             float* density)
{
    if (!physics || !material || !posX || !posY || !posZ || !halfX || !halfY || !halfZ || !density)
        return NULL;

    PxPhysics* px = (PxPhysics*)physics;
    PxMaterial* mat = (PxMaterial*)material;

    PxTransform transform(PxVec3(*posX, *posY, *posZ));
    PxBoxGeometry geometry(*halfX, *halfY, *halfZ);

    PxRigidDynamic* body = PxCreateDynamic(*px, transform, geometry, *mat, *density);
    return (PxHandle)body;
}

PHYSX_WRAPPER_API void pxSceneAddActor(PxHandle scene, PxHandle actor)
{
    PxScene* s = (PxScene*)scene;
    PxActor* a = (PxActor*)actor;
    if (s && a)
        s->addActor(*a);
}

PHYSX_WRAPPER_API void pxSceneSimulate(PxHandle scene, float* dt)
{
    if (!scene || !dt)
        return;
    PxScene* s = (PxScene*)scene;
    s->simulate(*dt);
}

PHYSX_WRAPPER_API int pxSceneFetchResults(PxHandle scene, int* block)
{
    if (!scene || !block)
        return 0;
    PxScene* s = (PxScene*)scene;
    return s->fetchResults(*block != 0) ? 1 : 0;
}

PHYSX_WRAPPER_API void pxActorGetPosition(PxHandle actor, float* outX, float* outY, float* outZ)
{
    PxActor* a = (PxActor*)actor;
    if (!a || !outX || !outY || !outZ)
        return;

    PxRigidActor* rigid = a->is<PxRigidActor>();
    if (rigid)
    {
        PxVec3 pos = rigid->getGlobalPose().p;
        *outX = pos.x;
        *outY = pos.y;
        *outZ = pos.z;
    }
}

PHYSX_WRAPPER_API void pxRelease(PxHandle obj)
{
    if (!obj)
        return;
    PxBase* base = (PxBase*)obj;
    base->release();
}

PHYSX_WRAPPER_API void pxShutdownPhysics(PxHandle physics, PxHandle foundation)
{
    PxPhysics* px = (PxPhysics*)physics;
    PxFoundation* f = (PxFoundation*)foundation;

    if (gCooking)
    {
        gCooking->release();
        gCooking = NULL;
    }

    PxCloseExtensions();

    if (px)
    {
        px->release();
        gPhysics = NULL;
    }

    gDispatcher = NULL;

    if (f)
    {
        f->release();
        gFoundation = NULL;
    }
}
