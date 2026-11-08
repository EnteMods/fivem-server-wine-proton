#pragma once

#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <uvw.hpp>

namespace fx
{
class SvMainCallbackQueue : public std::enable_shared_from_this<SvMainCallbackQueue>
{
private:
	std::mutex m_mutex;
	bool m_accepting = true;
	std::thread::id m_owner;
	std::deque<std::function<void()>> m_callbacks;
	std::shared_ptr<uvw::AsyncHandle> m_async;

public:
	void InitializeOnOwner(const std::shared_ptr<uvw::Loop>& loop)
	{
		std::lock_guard<std::mutex> lock(m_mutex);
		if (m_async || m_owner != std::thread::id{})
		{
			throw std::logic_error("svMain callback queue initialized twice");
		}
		m_owner = std::this_thread::get_id();
		m_async = loop->resource<uvw::AsyncHandle>();
		auto weak = weak_from_this();
		m_async->on<uvw::AsyncEvent>([weak](const uvw::AsyncEvent&, uvw::AsyncHandle&)
		{
			if (auto self = weak.lock())
			{
				self->RunOnOwner();
			}
		});
		if (!m_callbacks.empty())
		{
			m_async->send();
		}
	}

	bool TryAdd(const std::function<void()>& fn, bool force = false)
	{
		bool runInline;
		{
			std::lock_guard<std::mutex> lock(m_mutex);
			if (!m_accepting)
			{
				return false;
			}
			runInline = m_owner == std::this_thread::get_id() && !force;
			if (!runInline)
			{
				m_callbacks.push_back(fn);
				if (m_async)
				{
					// Acceptance, send, and the later close share this same lock.
					m_async->send();
				}
			}
		}
		if (runInline)
		{
			fn();
		}
		return true;
	}

	bool Dispatch(const std::function<void()>& fn, const std::function<void()>& cancelled, bool force = false)
	{
		if (TryAdd(fn, force))
		{
			return true;
		}
		cancelled();
		return false;
	}

	void RunOnOwner()
	{
		std::deque<std::function<void()>> batch;
		{
			std::lock_guard<std::mutex> lock(m_mutex);
			if (m_owner != std::this_thread::get_id())
			{
				throw std::logic_error("svMain callbacks dispatched by another thread");
			}
			// A finite batch lets the holder's stop async run under producer load.
			batch.swap(m_callbacks);
		}
		for (const auto& fn : batch)
		{
			fn();
		}
	}

	void ShutdownOnOwner()
	{
		{
			std::lock_guard<std::mutex> lock(m_mutex);
			if (m_owner != std::this_thread::get_id())
			{
				throw std::logic_error("svMain callback queue closed by another thread");
			}
			m_accepting = false;
		}
		RunOnOwner();
		std::lock_guard<std::mutex> lock(m_mutex);
		if (m_async && !m_async->closing())
		{
			m_async->close();
		}
	}
};
}
