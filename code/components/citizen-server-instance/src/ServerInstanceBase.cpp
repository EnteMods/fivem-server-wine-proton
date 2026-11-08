/*
 * This file is part of the Cfx project - https://cfx.re/
 *
 * See LICENSE in the root of the source tree for information
 * regarding licensing.
 */

#include "StdInc.h"
#include <ServerInstanceBase.h>

fwEvent<fx::ServerInstanceBase*> fx::ServerInstanceBase::OnServerCreate;

#include <ServerShutdownLifecycle.h>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace
{
struct ServerShutdownState
{
	fx::ServerShutdownPhase phase = fx::ServerShutdownPhase::Running;
	std::vector<std::function<void()>> callbacks;
};

struct ServerShutdownRegistry
{
	std::mutex mutex;
	std::unordered_map<fx::ServerInstanceBase*, ServerShutdownState> instances;
};

ServerShutdownRegistry& ShutdownRegistry()
{
	static ServerShutdownRegistry registry;
	return registry;
}
}

bool fx::BeginServerShutdownLifecycle(ServerInstanceBase* instance)
{
	if (!instance) return false;
	auto& registry = ShutdownRegistry();
	std::lock_guard<std::mutex> lock(registry.mutex);
	auto it = registry.instances.find(instance);
	if (it != registry.instances.end() && it->second.phase != ServerShutdownPhase::Finalized) return false;
	registry.instances[instance] = ServerShutdownState{};
	return true;
}

fx::ServerShutdownPhase fx::GetServerShutdownPhase(ServerInstanceBase* instance)
{
	if (!instance) return ServerShutdownPhase::Unavailable;
	auto& registry = ShutdownRegistry();
	std::lock_guard<std::mutex> lock(registry.mutex);
	auto it = registry.instances.find(instance);
	return it == registry.instances.end() ? ServerShutdownPhase::Unavailable : it->second.phase;
}

bool fx::RegisterServerStoppedCallback(ServerInstanceBase* instance, const std::function<void()>& callback)
{
	if (!instance) return false;
	auto& registry = ShutdownRegistry();
	std::lock_guard<std::mutex> lock(registry.mutex);
	auto it = registry.instances.find(instance);
	if (it == registry.instances.end() || it->second.phase != ServerShutdownPhase::Running) return false;
	it->second.callbacks.push_back(callback);
	return true;
}

bool fx::FinalizeServerShutdownLifecycle(ServerInstanceBase* instance)
{
	if (!instance) return false;
	std::vector<std::function<void()>> callbacks;
	{
		auto& registry = ShutdownRegistry();
		std::lock_guard<std::mutex> lock(registry.mutex);
		auto it = registry.instances.find(instance);
		if (it == registry.instances.end() || it->second.phase != ServerShutdownPhase::Running) return false;
		it->second.phase = ServerShutdownPhase::Finalizing;
		callbacks.swap(it->second.callbacks);
	}
	for (const auto& callback : callbacks) callback();
	{
		auto& registry = ShutdownRegistry();
		std::lock_guard<std::mutex> lock(registry.mutex);
		registry.instances.at(instance).phase = ServerShutdownPhase::Finalized;
	}
	return true;
}
