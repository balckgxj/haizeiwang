
#include "stdafx.h"

#include "GamePlatform.h"
#include <cstdio>

#ifdef _WINDOWS
#include <direct.h>
#endif
// 用引擎自带的 ZipUtils 做 inflate，避免直接依赖 external/zlib 的头文件
// （那份 zconf.h 在 MSVC 下会去找 unistd.h）
#include "base/ZipUtils.h"
#include "GameMaths.h"

#include <string>
#include "cocos2d.h"

// ---------------------------------------------------------------------------
// 资源文件读取
//
// 老资源里的配置表/脚本是「0xEF 0xFE + 异或 + zlib 压缩」的，2.x 时代这段逻辑
// 就在 Platform/GamePlatform.cpp 里。迁移时这个文件一度没被编进工程，导致配置表
// 读出来是乱码（图集不加载、界面缺图），这里保持原逻辑，只把 2.x 的
// CCFileUtils::sharedFileUtils() 换成 3.x 的 FileUtils::getInstance()，
// 并把 size 类型从 unsigned long* 适配成 3.x 的 ssize_t*。
// ---------------------------------------------------------------------------

void saveFileInPath( const std::string& fileInPath, const char* mode, const unsigned char* data, unsigned long size )
{
	FILE* fp = fopen(fileInPath.c_str(), mode ? mode : "wb");
	if (!fp)
	{
		int directoryDepth = 50;
		int pathstart = 0;
		int totalLength = (int)fileInPath.length();
		while (!fp && --directoryDepth > 0 && pathstart != (int)std::string::npos && pathstart < totalLength)
		{
			int pathend = (int)fileInPath.find_first_of("\\/", pathstart);
			pathstart = pathend + 1;
			if (pathend != (int)std::string::npos)
			{
				std::string subFilename = fileInPath.substr(0, pathend);
#ifdef _WINDOWS
				mkdir(subFilename.c_str());
#else
				mkdir(subFilename.c_str(), S_IRWXU);
#endif
			}
			fp = fopen(fileInPath.c_str(), mode ? mode : "wb");
		}
	}
	if (!fp)
	{
		CCLOG("[saveFileInPath] open failed: %s", fileInPath.c_str());
		return;
	}
	if (data && size > 0)
	{
		fwrite(data, 1, (size_t)size, fp);
	}
	fclose(fp);
}

static const char gamekey[] = "youaiABC";
static const int blocksize = 1024 * 8;

static bool decBuffer(unsigned long inSize, unsigned char* inBuffer, unsigned long& outSize, unsigned char*& outBuffer)
{
	if (inSize < 1 || inBuffer == nullptr)
	{
		return false;
	}
	unsigned char* decbuffer = new unsigned char[(size_t)inBuffer[0] * blocksize];
	outSize = (unsigned long)((size_t)inBuffer[0] * blocksize);
	if (decbuffer)
	{
		int keyflag = 0;
		int keylength = (int)strlen(gamekey);
		for (unsigned long i = 0; i < inSize; ++i)
		{
			*(inBuffer + i) = (unsigned char)(*(inBuffer + i) ^ gamekey[keyflag]);
			keyflag = (keyflag + 1) % keylength;
		}
		unsigned char* inflated = nullptr;
		ssize_t inflatedLen = cocos2d::ZipUtils::inflateMemory(inBuffer + 1, (ssize_t)(inSize - 1), &inflated);
		if (inflated && inflatedLen > 0)
		{
			outSize = (unsigned long)inflatedLen;
			outBuffer = new unsigned char[outSize];
			memcpy(outBuffer, inflated, outSize);
			free(inflated);
			delete[] decbuffer;
			return true;
		}
		if (inflated)
		{
			free(inflated);
		}
		delete[] decbuffer;
		CC_SAFE_DELETE_ARRAY(outBuffer);
	}
	return false;
}

unsigned char* getFileData( const char* pszFileName, const char* pszMode, unsigned long * pSize ,unsigned short* crc)
{
	if (pSize)
	{
		*pSize = 0;
	}
	if (crc)
	{
		*crc = 0;
	}
	if (!pszFileName || !pszMode)
	{
		return nullptr;
	}

	ssize_t fileSize = 0;
	cocos2d::FileUtils* fu = cocos2d::FileUtils::getInstance();
	unsigned char* buffer = fu->getFileData(pszFileName, pszMode, &fileSize);

	if (buffer && fileSize > 2 && buffer[0] == 0xef && buffer[1] == 0xfe)
	{
		if (strcmp(pszMode, "rb") != 0)
		{
			delete[] buffer;
			fileSize = 0;
			buffer = fu->getFileData(pszFileName, "rb", &fileSize);
		}
		if (buffer == nullptr)
		{
			return nullptr;
		}
		unsigned long outBufferSize = 0;
		unsigned char* outBuffer = 0;
		if (crc != 0)
		{
			*crc = GameMaths::GetCRC16((unsigned char*)buffer, (int)fileSize);
		}
		if (decBuffer((unsigned long)fileSize - 2, buffer + 2, outBufferSize, outBuffer))
		{
			delete[] buffer;
			if (pSize)
			{
				*pSize = outBufferSize;
			}
			return outBuffer;
		}
		delete[] buffer;
		return nullptr;
	}

	if (crc != 0 && buffer)
	{
		*crc = GameMaths::GetCRC16((unsigned char*)buffer, (int)fileSize);
	}
	if (pSize)
	{
		*pSize = (unsigned long)fileSize;
	}
	return buffer;
}
