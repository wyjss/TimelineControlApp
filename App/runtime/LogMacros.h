#pragma once
#include <QDebug>
#include <QBuffer>
#define DISABLE_TP

#ifndef DISABLE_TP
#include <osg/Vec3d>
#include <osg/BoundingBox>
#include <osg/Matrixd>
#include <osg/Timer>
#endif

#include <string>

inline QDebug& operator << (QDebug& q, const std::string& str) {
	q << str.c_str();
	return q;
}

#ifndef DISABLE_TP
inline QDebug& operator << (QDebug& q, const osg::Vec2d& v) {
	q << "[" << v.x() << ", " << v.y()  << "]";
	return q;
}

inline QDebug& operator << (QDebug& q, const osg::Vec3d& v) {
	q << "[" << v.x() << ", " << v.y() << ", " << v.z() << "]";
	return q;
}

inline QDebug& operator << (QDebug& q, const osg::Vec4d& v) {
	q << "[" << v.x() << ", " << v.y() << ", " << v.z() << ", " << v.w() << "]";
	return q;
}

inline QDebug& operator << (QDebug& q, const osg::BoundingBoxd& v) {
	q << "[" << v.xMin() << ", " << v.yMin() << ", " << v.zMin() << "\n"
		<< "\t" << v.xMax() << ", " << v.yMax() << ", " << v.zMax() << "]";
	return q;
}

inline QDebug& operator << (QDebug& q, const osg::Matrixd& mat) {
	for (int r = 0; r < 4; ++r) {
		q << "[";
		for (int c = 0; c < 4; ++c) {
			q << mat(r, c);
			if (c != 3) {
				q << ", ";
			}
		}
		q << "]\n";
	}
	
	return q;
}
#endif
#ifdef _MAP_
template<typename TK, typename TV>
inline QDebug& operator << (QDebug& q, const std::map<TK, TV>& m) {
	for (const auto& [k, v] : m) {
		q << "{" << k << "," << v << "},";
	}
	return q;
}
#endif
#ifdef _UNORDERED_MAP_
template<typename TK, typename TV>
inline QDebug& operator << (QDebug& q, const std::unordered_map<TK, TV>& m) {
	for (const auto& [k, v] : m) {
		q << "{" << k << "," << v << "},";
	}
	return q;
}
#endif

#define LOG_ONCE(Msg) \
{static bool s_b = true; if (s_b) { s_b = false; LOG_WARN(Msg); }}

#define LOG_MARK_DEBUG_CODE(Msg) \
	LOG_ONCE(__FUNCTION__ << " this is debug code************" << Msg << "************")

#ifndef RETURN_LOG_IF
#define RETURN_LOG_IF(_Condition, _Str, _Ret) \
	if(_Condition){ qDebug() << _Str; return _Ret;}
#endif

#define _LOG_LOG(l, ...) {\
	QString __str;\
	QDebug q(&__str); q.noquote() << __VA_ARGS__; \
	ragis::_LogLog(l, __str, __FILE__, __FUNCTION__);\
}

#ifdef LC
#define _LOG_LC LC << 
#else
#define _LOG_LC
#endif

#define LOG_TRACE(...) _LOG_LOG(ragis::_Log_Trace, _LOG_LC __VA_ARGS__)
#define LOG_DEBUG(...) _LOG_LOG(ragis::_Log_Debug, _LOG_LC __VA_ARGS__)
#define LOG_INFO(...) _LOG_LOG(ragis::_Log_Info, _LOG_LC __VA_ARGS__)
#define LOG_WARN(...) _LOG_LOG(ragis::_Log_Warn, _LOG_LC __VA_ARGS__)
#define LOG_ERROR(...) _LOG_LOG(ragis::_Log_Err, _LOG_LC __VA_ARGS__)
#define LOG_FATAL(...) _LOG_LOG(ragis::_Log_Fatal, _LOG_LC __VA_ARGS__) exit(0);

#define LOG_TRACE_METHOD(NAME) _ragis::TraceMethod __trace_method(NAME);


#define RAGIS_ENABLE_DEBUGGER
#ifdef RAGIS_ENABLE_DEBUGGER
#define DEBUGGER_ProcessTimePerSecond(name) static _ragis::ProcessTimePerSecond _rd_##name(#name);(_rd_##name).start();
#define DEBUGGER_ProcessTimePerSecond_End(name) _rd_##name.end();

#define DEBUGGER_ProcessTime(name) _ragis::ProcessTime _rd_##name(#name);
#define DEBUGGER_ProcessTimeIfTimeout(name, TimeoutMS) _ragis::ProcessTime _rd_##name(#name, TimeoutMS);

#define DEBUGGER_ProcessCountPerSecond(name) static _ragis::ProcessCountPerSecond _rd_##name(#name);(_rd_##name).add(1);
#define DEBUGGER_ProcessCountPerSecond_Add(name) _rd_##name.add(1);
#else
#define DEBUGGER_ProcessTimePerSecond(name);
#define DEBUGGER_ProcessTimePerSecond_End(name) ;

#define DEBUGGER_ProcessTime(name) ;
#define DEBUGGER_ProcessTimeIfTimeout(name, TimeoutMS) _ragis::ProcessTime _rd_##name(#name, TimeoutMS);

#define DEBUGGER_ProcessCountPerSecond(name) ;
#define DEBUGGER_ProcessCountPerSecond_Add(name) ;
#endif

#ifndef DISABLE_TP
#include "core/Export.h"
#else
# ifndef RAGIS2_EXPORT
# define RAGIS2_EXPORT
# endif
#endif
namespace ragis
{
	enum _LogLevel {
		_Log_Trace = 0,
		_Log_Debug,
		_Log_Info,
		_Log_Warn,
		_Log_Err,
		_Log_Fatal,
	};
	RAGIS2_EXPORT void _LogLog(_LogLevel level, const QString& str, const char* file, const char* func);
}

namespace _ragis {
	class RAGIS2_EXPORT TraceMethod {
	public:
		TraceMethod(const std::string& name) :m_name(name){
			LOG_TRACE("[TraceMethod]" << name);
		}
		~TraceMethod() {
			LOG_TRACE("[TraceMethod]" << m_name << "end");
		}
	private:
		std::string m_name;
	};

#ifndef DISABLE_TP
	class RAGIS2_EXPORT ProcessTimePerSecond {
	public:
		ProcessTimePerSecond(const std::string& name) {
			m_name = name;
			m_lastPrintTimeS = osg::Timer::instance()->time_s();
			m_processTimeS = 0;
		}

		void start() {
			m_startTimeS = osg::Timer::instance()->time_s();

		}
		void end() {
			double curTimeS = osg::Timer::instance()->time_s();
			m_processTimeS += (curTimeS - m_startTimeS);

			double elTimeS = curTimeS - m_lastPrintTimeS;
			if (elTimeS >= 2) {
				LOG_TRACE(m_name << ":" << m_processTimeS / elTimeS * 1000.0);
				m_lastPrintTimeS = osg::Timer::instance()->time_s();
				m_processTimeS = 0;
			}
		}

	private:
		std::string m_name;
		double		m_lastPrintTimeS;
		double		m_startTimeS;
		double		m_processTimeS;

	};

	class RAGIS2_EXPORT ProcessTime {
	public:
		ProcessTime(const std::string& name,int timeoutMS = -1) {
			m_name = name;
			m_timeoutMS = timeoutMS;
			m_timeS = osg::Timer::instance()->time_s();
		}
		~ProcessTime() {
			auto dt = osg::Timer::instance()->time_s() - m_timeS;
			auto dtms = int(dt * 1000);
			if (dtms > m_timeoutMS) {
				LOG_TRACE(m_name << ": process time ms: " << dtms);
			}
		}

	private:
		std::string m_name;
		double		m_timeS;
		int m_timeoutMS;
	};

	class RAGIS2_EXPORT ProcessCountPerSecond {
	public:
		ProcessCountPerSecond(const std::string& name) {
			m_name = name;
			m_lastPrintTimeS = osg::Timer::instance()->time_s();
		}

		void add(int i) {
			m_iCount += i;
			auto curTimeS = osg::Timer::instance()->time_s();
			auto dt = curTimeS - m_lastPrintTimeS;
			if (dt > 2.0) {
				LOG_TRACE(m_name << ":" << int(m_iCount / dt));
				m_lastPrintTimeS = curTimeS;
				m_iCount = 0;
			}
			
		}
	private:
		std::string m_name;
		int m_iCount = 0;
		double		m_lastPrintTimeS;
	};
#endif
}