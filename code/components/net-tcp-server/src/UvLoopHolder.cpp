/*
 * This file is part of the Cfx project - https://cfx.re/
 *
 * See LICENSE in the root of the source tree for information
 * regarding licensing.
 */

#include "StdInc.h"
#include "UvLoopHolder.h"
#include "UvLoopManager.h"
#include "memdbgon.h"

#include <exception>

namespace net
{
UvLoopHolder::UvLoopHolder(const std::string& loopTag)
	: m_shouldExit(false), m_loopTag(loopTag)
{
	m_loop = uvw::Loop::create();
	m_loop->data(std::make_shared<void*>(this));
	m_async = m_loop->resource<uvw::AsyncHandle>();

	m_async->on<uvw::AsyncEvent>([this](const uvw::AsyncEvent&, uvw::AsyncHandle&)
	{
		std::function<void()> fn;
		while (m_functionQueue.try_pop(fn))
		{
			fn();
		}

		if (m_shouldExit.load(std::memory_order_acquire))
		{
			{
				std::lock_guard<std::mutex> lock(m_enqueueMutex);
				m_shutdownStarted = true;
			}
			for (const auto& shutdown : m_shutdownCallbacks)
			{
				shutdown();
			}
			m_async->close();
			m_loop->stop();
		}
	});

	m_thread = std::thread([=]()
	{
		SetThreadName(-1, const_cast<char*>(va(
#ifdef _WIN32
			"UV loop: %s"
#else
			"luv_%s"
#endif
			, m_loopTag.c_str())));
		Instance<UvLoopManager>::Get()->SetCurrent(this);

		// A stop before worker startup must still dispatch accepted work.
		do
		{
			m_loop->run<uvw::Loop::Mode::DEFAULT>();
			if (!m_shouldExit.load(std::memory_order_acquire))
			{
				std::this_thread::sleep_for(std::chrono::milliseconds(100));
			}
		} while (!m_shouldExit.load(std::memory_order_acquire));

		// Only owners close their handles. Unknown handles make shutdown fail.
		for (;;)
		{
			struct PendingHandles
			{
				bool any = false;
				bool open = false;
			} pending;
			uv_walk(m_loop->raw(), [](uv_handle_t* handle, void* state)
			{
				auto& handles = *static_cast<PendingHandles*>(state);
				handles.any = true;
				handles.open |= !uv_is_closing(handle);
			}, &pending);
			if (pending.open)
			{
				break;
			}
			if (!pending.any)
			{
				// Captured owner state survives through every close callback.
				m_shutdownCallbacks.clear();
				m_loop->close();
				m_shutdownComplete.store(m_loop->raw() == nullptr, std::memory_order_release);
				if (m_shutdownComplete.load(std::memory_order_acquire))
				{
					m_loop = {};
				}
				break;
			}
			// Recheck after close callbacks in case one created a new handle.
			m_loop->run<uvw::Loop::Mode::NOWAIT>();
		}
	});
	m_loopThreadId = m_thread.get_id();
}

UvLoopHolder::~UvLoopHolder()
{
	if (!RequestStopAndJoin())
	{
		// Failed shutdown leaves worker or owner-handle lifetimes unresolved.
		std::terminate();
	}
}

bool UvLoopHolder::RequestStopAndJoin()
{
	{
		std::lock_guard<std::mutex> lock(m_enqueueMutex);
		if (!m_shouldExit.exchange(true, std::memory_order_acq_rel))
		{
			m_async->send();
		}
	}
	if (std::this_thread::get_id() == m_loopThreadId)
	{
		return false;
	}
	std::lock_guard<std::mutex> lock(m_joinMutex);
	if (m_thread.joinable())
	{
		m_thread.join();
	}
	return m_shutdownComplete.load(std::memory_order_acquire);
}

void UvLoopHolder::RegisterShutdownCallback(const std::function<void()>& fn)
{
	std::lock_guard<std::mutex> lock(m_enqueueMutex);
	if (m_shutdownStarted)
	{
		throw std::runtime_error("UvLoopHolder owner registered after shutdown began");
	}
	m_shutdownCallbacks.push_back(fn);
}

void UvLoopHolder::AssertThread()
{
#if _DEBUG
	assert(std::this_thread::get_id() == m_thread.get_id());
#endif
}
}
