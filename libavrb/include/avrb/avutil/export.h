#ifndef AVREADERWRITER_EXPORT
#ifdef AVREADERWRITER_LIB
#define AVREADERWRITER_EXPORT __declspec(dllexport)
#else
#define AVREADERWRITER_EXPORT __declspec(dllimport)
#endif
#endif