#pragma once

#include <atomic>
#include <cerrno>
#include <chrono>
#include <fcntl.h>
#include <exception>
#include <functional>
#include <memory>
#include <mutex>
#include <poll.h>
#include <stdexcept>
#include <string>
#include <system_error>
#include <thread>
#include <unistd.h>

namespace fx
{
// POSIX implementation; the server selects it only for Linux non-TTY input.
class InterruptibleNonTtyInput
{
public:
	enum class Result { Line, EndOfFile, Stopped, Error };

private:
	int m_input;
	int m_wakeup[2] = { -1, -1 };
	std::atomic<bool> m_stopped{ false };
	std::string m_pending;
	bool m_eof = false;

	static bool SetPrivateFlags(int fd)
	{
		int flags = fcntl(fd, F_GETFL);
		int descriptorFlags = fcntl(fd, F_GETFD);
		return flags != -1 && descriptorFlags != -1
			&& fcntl(fd, F_SETFL, flags | O_NONBLOCK) != -1
			&& fcntl(fd, F_SETFD, descriptorFlags | FD_CLOEXEC) != -1;
	}

public:
	explicit InterruptibleNonTtyInput(int input) : m_input(input)
	{
		if (fcntl(m_input, F_GETFD) == -1)
		{
			if (errno == EBADF)
			{
				m_eof = true;
				return;
			}
			throw std::system_error(errno, std::generic_category(), "console input descriptor");
		}
		if (::pipe(m_wakeup) == -1)
		{
			throw std::system_error(errno, std::generic_category(), "console wakeup pipe");
		}
		// pipe() may use closed standard descriptors. Keep our ends above 2.
		for (auto& descriptor : m_wakeup)
		{
			if (descriptor < 3)
			{
				int replacement = fcntl(descriptor, F_DUPFD_CLOEXEC, 3);
				if (replacement == -1)
				{
					int error = errno;
					::close(m_wakeup[0]);
					::close(m_wakeup[1]);
					throw std::system_error(error, std::generic_category(), "console wakeup descriptor");
				}
				::close(descriptor);
				descriptor = replacement;
			}
		}
		if (!SetPrivateFlags(m_wakeup[0]) || !SetPrivateFlags(m_wakeup[1]))
		{
			int error = errno;
			::close(m_wakeup[0]);
			::close(m_wakeup[1]);
			throw std::system_error(error, std::generic_category(), "console wakeup flags");
		}
	}

	~InterruptibleNonTtyInput()
	{
		if (m_wakeup[0] != -1) ::close(m_wakeup[0]);
		if (m_wakeup[1] != -1) ::close(m_wakeup[1]);
	}

	InterruptibleNonTtyInput(const InterruptibleNonTtyInput&) = delete;
	InterruptibleNonTtyInput& operator=(const InterruptibleNonTtyInput&) = delete;

	bool IsStopped() const noexcept { return m_stopped.load(std::memory_order_acquire); }

	void RequestStop() noexcept
	{
		int savedError = errno;
		if (!m_stopped.exchange(true, std::memory_order_acq_rel) && m_wakeup[1] != -1)
		{
			char wake = 1;
			while (::write(m_wakeup[1], &wake, 1) == -1 && errno == EINTR) {}
		}
		errno = savedError;
	}

	bool WaitForStop(int milliseconds) const
	{
		if (m_wakeup[0] == -1)
		{
			// No input existed at construction. Disabled reads still stop promptly.
			while (!IsStopped() && milliseconds > 0)
			{
				int slice = milliseconds < 25 ? milliseconds : 25;
				::poll(nullptr, 0, slice);
				milliseconds -= slice;
			}
			return IsStopped();
		}
		pollfd wake{ m_wakeup[0], POLLIN, 0 };
		while (!IsStopped())
		{
			int status = ::poll(&wake, 1, milliseconds);
			if (status >= 0) return IsStopped();
			if (errno != EINTR) return IsStopped();
		}
		return true;
	}

	Result ReadLine(std::string& line)
	{
		for (;;)
		{
			if (IsStopped()) return Result::Stopped;
			auto newline = m_pending.find('\n');
			if (newline != std::string::npos || (m_eof && !m_pending.empty()))
			{
				line = m_pending.substr(0, newline);
				m_pending.erase(0, newline == std::string::npos ? m_pending.size() : newline + 1);
				while (!line.empty() && line.back() == '\r') line.pop_back();
				return Result::Line;
			}
			if (m_eof) return Result::EndOfFile;
			pollfd inputs[2] = { { m_wakeup[0], POLLIN, 0 }, { m_input, POLLIN, 0 } };
			int status = ::poll(inputs, 2, -1);
			if (status == -1)
			{
				if (errno == EINTR) continue;
				return Result::Error;
			}
			if (IsStopped() || inputs[0].revents) return Result::Stopped;
			if (inputs[1].revents & POLLNVAL) return Result::Error;
			if (inputs[1].revents & (POLLIN | POLLHUP | POLLERR))
			{
				char data[4096];
				ssize_t count = ::read(m_input, data, sizeof(data));
				if (count > 0) m_pending.append(data, static_cast<size_t>(count));
				else if (count == 0) m_eof = true;
				else if (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK) return Result::Error;
			}
		}
	}
};

class NonTtyInputWorker
{
private:
	std::shared_ptr<InterruptibleNonTtyInput> m_input;
	std::thread m_thread;
	std::mutex m_joinMutex;
	bool m_started = false;

public:
	explicit NonTtyInputWorker(int input) : m_input(std::make_shared<InterruptibleNonTtyInput>(input)) {}
	~NonTtyInputWorker()
	{
		if (!StopAndJoin()) std::terminate();
	}

	void Start(const std::function<void(InterruptibleNonTtyInput&)>& work)
	{
		std::lock_guard<std::mutex> lock(m_joinMutex);
		if (m_started) throw std::logic_error("console reader already started");
		if (!m_input->IsStopped())
		{
			auto input = m_input;
			m_thread = std::thread([input, work]() { work(*input); });
		}
		m_started = true;
	}

	void RequestStop() noexcept { m_input->RequestStop(); }

	bool StopAndJoin()
	{
		RequestStop();
		std::lock_guard<std::mutex> lock(m_joinMutex);
		if (m_thread.joinable())
		{
			if (m_thread.get_id() == std::this_thread::get_id()) return false;
			m_thread.join();
		}
		return true;
	}
};
}
