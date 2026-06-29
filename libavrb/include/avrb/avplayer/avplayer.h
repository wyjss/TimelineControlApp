#pragma once
#include <avutil/export.h>
#include <QWidget>

class AVPlayback;

class AVREADERWRITER_EXPORT AVPlayer : public QWidget
{
public:
	AVPlayer(QWidget* parent = nullptr);
	virtual ~AVPlayer();

	void open(const QString& path);
	bool play();
	bool pause();
	bool stop();
	bool seek(double sec);
	double position() const;
	double duration() const;
private:
	AVPlayback* m_playback = nullptr;
};