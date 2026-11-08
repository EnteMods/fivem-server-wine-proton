/*
* This file is part of the Cfx project - https://cfx.re/
 *
 * See LICENSE in the root of the source tree for information
 * regarding licensing.
 */

#include "StdInc.h"
#include "UvLoopTimer.h"

namespace fx::nodejs
{
void UvLoopTimer::Initialize()
{
	m_runtimes.reserve(32);
	m_loop = Instance<net::UvLoopManager>::Get()->GetOrCreate("svMain");
	auto holder = m_loop;
	(void)holder->TryEnqueueCallback([this, holder]()
	{
		if (m_shutdownRequested.load(std::memory_order_acquire) || m_initialized)
		{
			return;
		}
		m_timer = std::make_unique<UvHandleContainer<uv_timer_t>>();
		uv_timer_init(holder->GetLoop(), m_timer->get());
		uv_timer_start(m_timer->get(), UvPersistentCallback(m_timer->get(), [this](uv_timer_t*)
		{
			for (const auto rt : m_runtimes)
			{
				rt->TickFast();
			}
		}), 0, 1);
		m_initialized = true;
		holder->RegisterShutdownCallback([this]()
		{
			if (m_timer)
			{
				uv_timer_stop(m_timer->get());
				m_timer.reset();
			}
			m_initialized = false;
		});
	});
}

void UvLoopTimer::Shutdown()
{
	m_shutdownRequested.store(true, std::memory_order_release);
	if (m_loop.GetRef())
	{
		(void)m_loop->TryEnqueueCallback([this]()
		{
			if (m_initialized)
			{
				uv_timer_stop(m_timer->get());
			}
		});
	}
}

void UvLoopTimer::AddRuntime(NodeScriptRuntime* rt)
{
	m_runtimes.push_back(rt);
}

void UvLoopTimer::RemoveRuntime(NodeScriptRuntime* rt)
{
	m_runtimes.erase(std::find(m_runtimes.begin(), m_runtimes.end(), rt));
}
}
