#pragma once

#include <functional>

#ifdef COMPILING_CITIZEN_SERVER_INSTANCE
#define SERVER_SHUTDOWN_EXPORT DLL_EXPORT
#else
#define SERVER_SHUTDOWN_EXPORT DLL_IMPORT
#endif

namespace fx
{
class ServerInstanceBase;
enum class ServerShutdownPhase { Unavailable, Running, Finalizing, Finalized };

SERVER_SHUTDOWN_EXPORT bool BeginServerShutdownLifecycle(ServerInstanceBase* instance);
SERVER_SHUTDOWN_EXPORT ServerShutdownPhase GetServerShutdownPhase(ServerInstanceBase* instance);
SERVER_SHUTDOWN_EXPORT bool RegisterServerStoppedCallback(ServerInstanceBase* instance, const std::function<void()>& callback);
SERVER_SHUTDOWN_EXPORT bool FinalizeServerShutdownLifecycle(ServerInstanceBase* instance);
}
