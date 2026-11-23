#ifndef RA_LICENSE_H
#define RA_LICENSE_H
#include <QString>


class RA_License
{
public:
	static RA_License* Instance();

	bool IsEmpower();
	bool IsValTime(int nDay = 30);//nDay：授权天数，默认30天
	void ResetValTime();//若过期需要复位时间授权，调用此函数重新计数
private:
	RA_License();
	~RA_License();

	int first_time_t;
private:
	QString getCpuSeq();
	QString getBiosSeq();
	QString getBaseboardNum();
	std::string GetWmiInfo(const wchar_t* queryKey, const wchar_t* propName);
};

#endif // RA_LICENSE_H
