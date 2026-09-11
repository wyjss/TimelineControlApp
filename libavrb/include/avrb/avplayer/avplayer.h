#pragma once
#include <avutil/export.h>
#include <QWidget>

class QTimer;
class AVPlayback;

struct AVReaderOptions;
class AVREADERWRITER_EXPORT AVPlayer : public QWidget
{
	Q_OBJECT
public:
	AVPlayer(QWidget* parent = nullptr);
	virtual ~AVPlayer();

	bool open(const QString& path);
	bool open(const AVReaderOptions& opts);
	bool openDebug(const AVReaderOptions& opts);
	bool play();
	bool pause();
	bool stop();
	bool seek(double sec);
	double position() const;
	double duration() const;
private:
	AVPlayback* m_playback = nullptr;
};