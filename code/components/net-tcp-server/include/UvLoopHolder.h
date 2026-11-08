/*
 * This file is part of the Cfx project - https://cfx.re/
 *
 * See LICENSE in the root of the source tree for information
 * regarding licensing.
 */

#pragma once

#include <atomic>
#include <mutex>
#include <stdexcept>
#include <vector>
#include <thread>

#include <uv.h>

#include <uvw.hpp>

#include <tbb/concurrent_queue.h>

#ifdef COMPILING_NET_TCP_SERVER
#define UV_LOOP_HOLDER_EXPORT DLL_EXPORT
#else
#define UV_LOOP_HOLDER_EXPORT DLL_IMPORT
#endif

namespace net
{
class UV_LOOP_HOLDER_EXPORT UvLoopHolder : public fwRefCountable
{
private:
	std::shared_ptr<uvw::Loop> m_loop;

	std::shared_ptr<uvw::AsyncHandle> m_async;

	std::thread m_thread;

	std::thread::id m_loopThreadId;

	std::atomic<bool> m_shouldExit;

	std::atomic<bool> m_shutdownComplete{ false };

	bool m_shutdownStarted = false;

	std::vector<std::function<void()>> m_shutdownCallbacks;

	std::mutex m_enqueueMutex;

	std::mutex m_joinMutex;

	std::string m_loopTag;

	tbb::concurrent_queue<std::function<void()>> m_functionQueue;

public:
	UvLoopHolder(const std::string& loopTag);

	virtual ~UvLoopHolder();

	// Returns false for self-join or handles left open by an unregistered owner.
	bool RequestStopAndJoin();

	// Runs after accepted work drains, on the loop thread. Owners must close
	// their own handles and retain callback state until close completion.
	void RegisterShutdownCallback(const std::function<void()>& fn);

	void AssertThread();

	inline uv_loop_t* GetLoop()
	{
		return m_loop->raw();
	}

	inline const std::shared_ptr<uvw::Loop>& Get()
	{
		return m_loop;
	}

	inline const std::string& GetLoopTag() const
	{
		return m_loopTag;
	}

	inline bool TryEnqueueCallback(const std::function<void()>& fn)
	{
		std::lock_guard<std::mutex> lock(m_enqueueMutex);
		if (m_shouldExit.load(std::memory_order_acquire))
		{
			return false;
		}

		m_functionQueue.push(fn);
		m_async->send();
		return true;
	}

	// Compatibility only: waitable work needs TryEnqueueCallback and cancellation.
	inline void EnqueueCallback(const std::function<void()>& fn)
	{
		(void)TryEnqueueCallback(fn);
	}
};
}
