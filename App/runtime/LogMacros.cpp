// #ifndef DISABLE_TP
// #include "core/LogMacros.h"
// #include "core/GlobalConfig.h"
// #else 
// #include "LogMacros.h"
// #endif
#include "LogMacros.h"
#include <spdlog/spdlog.h>
#include <spdlog/cfg/env.h>
#include <spdlog/fmt/ostr.h>
#include <spdlog/stopwatch.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <QTime>

#ifdef _WIN32
#include <Windows.h>
#endif
using namespace ragis;
namespace
{
	struct ConsoleAppender {
#ifdef _WIN32
		typedef unsigned int _ColorTy;
		const _ColorTy& COLOR_RED = 0x0004 | 0x0008;
		const _ColorTy& COLOR_GREEN = 0x0002 | 0x0008;
		const _ColorTy& COLOR_BLUE = 0x0001 | 0x0008;
		const _ColorTy& COLOR_YELLOW = COLOR_RED | COLOR_GREEN;
		const _ColorTy& COLOR_WHITE = COLOR_RED | COLOR_GREEN | COLOR_BLUE;

		const _ColorTy& COLOR_TRACE = (~0x0008) & COLOR_WHITE;
		const _ColorTy& COLOR_FATAL = COLOR_RED | 0x0030;
#else
		typedef std::string _ColorTy;
		const _ColorTy& COLOR_RED = ("\033[31m");
		const _ColorTy& COLOR_GREEN = ("\033[32m");
		const _ColorTy& COLOR_BLUE = ("\033[34m");
		const _ColorTy& COLOR_YELLOW = ("\033[33m");
		const _ColorTy& COLOR_WHITE = ("\033[37m");

		const _ColorTy& COLOR_TRACE = COLOR_WHITE;
		const _ColorTy& COLOR_FATAL = COLOR_RED;
#endif

#ifdef _WIN32
		WORD m_oldColor = COLOR_WHITE;
		HANDLE m_console = INVALID_HANDLE_VALUE;
#endif
		inline void setLevelColor(int level) {
			switch (level) {
			default:
			case _Log_Debug: return setColor(COLOR_WHITE); break;
			case _Log_Info: return setColor(COLOR_GREEN); break;
			case _Log_Warn: return setColor(COLOR_YELLOW); break;
			case _Log_Err: return setColor(COLOR_RED); break;
			case _Log_Fatal: return setColor(COLOR_FATAL); break;
			}
		}
		inline void setColor(const _ColorTy& color) {
#ifdef _WIN32
			m_console = GetStdHandle(STD_OUTPUT_HANDLE);
			if (m_console != INVALID_HANDLE_VALUE) {
				CONSOLE_SCREEN_BUFFER_INFO csbiInfo;
				if (GetConsoleScreenBufferInfo(m_console, &csbiInfo)) {
					m_oldColor = csbiInfo.wAttributes;
					SetConsoleTextAttribute(m_console, color);
				}
			}
#endif
		}

		QString getLogLevelStr(int level)
		{
			switch (level) {
			default:
			case _Log_Debug: return QStringLiteral("Debug"); break;
			case _Log_Info: return QStringLiteral("Info "); break;
			case _Log_Warn: return QStringLiteral("Warn "); break;
			case _Log_Err: return QStringLiteral("Error"); break;
			case _Log_Fatal: return QStringLiteral("Fatal"); break;
			}
		}
		inline void resetColor() {
#ifdef _WIN32
			if (m_console != INVALID_HANDLE_VALUE) {
				setColor(m_oldColor);
			}
#endif
		}
		inline void operator()(int level, const QString& str) {
			setLevelColor(level);
			qDebug().noquote() << QString("(ragis)%1  %2:").arg(QTime::currentTime().toString("hh:mm::ss:zzz  ")).arg(getLogLevelStr(level))
				<< str;
			resetColor();
		}
	};
}
namespace ragis
{
	static int g_logLevel = _Log_Debug;
}

namespace ragis
{
	static spdlog::logger g_logger("");

#ifdef DISABLE_TP
	class GlobalConfig
	{
	public:
		static std::string ragisNotifyLevel() { return "trace"; }
		static bool ragisNotifyAsync() { return false; }
		static bool ragisNotifyFile() { return false; }
	};
#endif

	void initLogger()
	{
		std::map<std::string, spdlog::level::level_enum> levelMap = {
			{"trace", spdlog::level::trace},
			{"debug", spdlog::level::debug},
			{"info", spdlog::level::info},
			{"warn", spdlog::level::warn},
			{"error", spdlog::level::err},
			{"fatal", spdlog::level::critical},
			// 兼容 osg
			{"debug_info", spdlog::level::debug},
			{"debug_fp", spdlog::level::debug},
		};
		spdlog::level::level_enum level = spdlog::level::debug;
		if (levelMap.count(GlobalConfig::ragisNotifyLevel())) {
			level = levelMap[GlobalConfig::ragisNotifyLevel()];
		}
		g_logLevel = level;

		spdlog::logger logger("ragis");
		logger.set_level(level);

		std::string pattern = "%^(ragis)%H:%M:%S:%e    %v%$"; // no %l

		std::vector<spdlog::sink_ptr> sinks;
		if (GlobalConfig::ragisNotifyAsync()) {
			auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
			console_sink->set_level(level);
			console_sink->set_pattern(pattern);
			logger.sinks().push_back(console_sink);

			if (GlobalConfig::ragisNotifyFile()) {
				auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>("log/ragis.txt", true);
				file_sink->set_level(level);
				file_sink->set_pattern(pattern);
				logger.sinks().push_back(file_sink);
			}
		} else {
			auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_st>();
			console_sink->set_level(level);
			console_sink->set_pattern(pattern);
			logger.sinks().push_back(console_sink);

			if (GlobalConfig::ragisNotifyFile()) {
				auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_st>("log/ragis.txt", true);
				file_sink->set_level(level);
				file_sink->set_pattern(pattern);
				logger.sinks().push_back(file_sink);
			}
		}
#ifdef _WIN32
		//SetConsoleOutputCP(65001);
#endif // _WIN32


		g_logger = logger;
	}

	std::string getPrintableString(const QString& qstr)
	{
#ifdef _WIN32
		if (GetConsoleOutputCP() == CP_UTF8) {
			return qstr.toStdString();
		} else {
			return qstr.toLocal8Bit().toStdString();
		}
#else
		return qstr.toStdString();
#endif // _WIN32
	}

	void _LogLog(_LogLevel level, const QString& str, const char* file, const char* func)
	{
		static std::once_flag s_flag;
		std::call_once(s_flag, [&]() {
			initLogger();
					   });
		if (level < g_logLevel) {
			return;
		}

		auto stdstr = getPrintableString(str);
		switch (level) {
		default:
		case _Log_Trace: g_logger.trace("Trace: {}", stdstr); break;
		case _Log_Debug: g_logger.debug("Debug: {}", stdstr); break;
		case _Log_Info: g_logger.info("Info : {}", stdstr); break;
		case _Log_Warn: g_logger.warn("Warn : {}", stdstr); break;
		case _Log_Err: g_logger.error("Error: {}", stdstr); break;
		case _Log_Fatal: g_logger.critical("Fatal: {}", stdstr); exit(0); break;
		}
		
		return;
		
		ConsoleAppender()(level, str);

#if 0
		RA_Log* logger = nullptr;
		switch (level) {
		case _Log_Debug: {
			qDebug().noquote() << str;
			return;
		}break;
		case _Log_Info: {
			static auto s_logger = RA_Log::Instance(Log_Infomation, "ragis");
			logger = s_logger;
		}break;
		case _Log_Warn: {
			static auto s_logger = RA_Log::Instance(Log_Warning, "ragis");
			logger = s_logger;
		}break;
		case _Log_Err: //
		case _Log_Fatal: {
			static auto s_logger = RA_Log::Instance(Log_Error, "ragis");
			logger = s_logger;
		}break;
		}
		
		if (logger) {
			logger->WriteLog(str);
		}
#else
		ConsoleAppender()(level, str);
#endif
	}
}
