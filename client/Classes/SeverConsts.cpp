
#include "stdafx.h"

#include "SeverConsts.h"
#include "Concurrency.h"
#include "GameMaths.h"
#include "GamePlatform.h"
#include "json/json.h"
#include "cocos2d.h"
#include "GamePlatform.h"
#include "libOS.h"
#include "Language.h"
#include "libPlatform.h"

const std::string TEMP_SEVER_FILE_DOWNLOADED = "_tempSeverFile.cfg";
const std::string TEMP_UPDATE_FILE_DOWNLOADED = "_tempUpdateFile.cfg";
const std::string TEMP_CONFIG_FILE_BACKUP = "_tempConfigFile.cfg";
class SeverCheckingFileTask : public ThreadTask
{
public:
	SeverCheckingFileTask(){}
	int run()
	{
		SeverConsts::FILELIST& mFiles = SeverConsts::Get()->_lockFileList();
		SeverConsts::FILELIST checkList;
		SeverConsts::FILELIST addList;
		checkList.swap(mFiles);
		SeverConsts::FILELIST::iterator it = checkList.begin();
		

		for(;it!=checkList.end();++it)
		{
			unsigned long filesize;
			unsigned short checkedCRC = 0;
			char* pBuffer = (char*)getFileData((*it)->checkpath.c_str(),"rb",&filesize,&checkedCRC);

			if(!pBuffer || checkedCRC != (*it)->crc)
				addList.push_back(*it);
			else
				delete *it;

			if(pBuffer)delete pBuffer;
		}
		
		mFiles.swap(addList);
		SeverConsts::Get()->_unlockFileList();
		SeverConsts::Get()->_notifyFileCheckDone();
		
		return 0;
	}
};

void SeverConsts::init( const std::string& configfile )
{
	setOriginalSearchPath();

	CurlDownload::Get()->addListener(this);
    
    std::string desFile(cocos2d::FileUtils::getInstance()->getWritablePath());
    desFile=desFile+"/"+TEMP_SEVER_FILE_DOWNLOADED;
    remove(desFile.c_str());
    
    std::string desFile2(cocos2d::FileUtils::getInstance()->getWritablePath());
    desFile2=desFile2+"/"+TEMP_UPDATE_FILE_DOWNLOADED;
    remove(desFile2.c_str());
    
	
	mConfigFile = configfile;

	std::string bundleVersion = "";
	std::string newVersion = "";
	//cocos2d::Application::getInstance()->getResourceRootPath();
	//cocos2d::FileUtils::getInstance()->setSearchPaths()
	std::string bundleConfigFile = cocos2d::FileUtils::getInstance()->fullPathForFilename(configfile.c_str());
	mCfgFilePath = bundleConfigFile;
	CCLOG("0 parse bundleConfigFile: %s", bundleConfigFile.c_str());
	if(_parseConfigFile(bundleConfigFile))
		bundleVersion = mLocalVerson;
	CCLOG("bundleVersion: %s", bundleVersion.c_str());
	
	/*
		in our DreamOnePiece android program, bundle unziped path is same with cocos2d::FileUtils::getInstance()->getWritablePath()
		in android bundleConfigFile == searchpath1
	*/

	std::string searchpath1 = cocos2d::FileUtils::getInstance()->getWritablePath()+"/"+mAdditionalSearchPath + "/" + configfile;
	CCLOG("1 try to parse localConfigFile: %s", searchpath1.c_str());
	std::string searchpath2 = cocos2d::FileUtils::getInstance()->getWritablePath()+"/"+TEMP_CONFIG_FILE_BACKUP;
	CCLOG("2 try to parse localConfigFile: %s", searchpath2.c_str());
	
	if(bundleConfigFile != searchpath1 && _parseConfigFile(searchpath1.c_str()))
	{
		CCLOG("1 parse localConfigFile: %s", searchpath1.c_str());
		newVersion = mLocalVerson;
	}
	else if(bundleConfigFile != searchpath2 && _parseConfigFile(searchpath2.c_str()))
	{
		CCLOG("2 parse localConfigFile: %s", searchpath2.c_str());
		newVersion = mLocalVerson;
	}
	CCLOG("newVersion: %s", newVersion.c_str());

	setAdditionalSearchPath();

	if(bundleVersion!="" && newVersion!="")
	{
		int bundleGameVersion,bundleAppVersion,bundleResVersion;
		int LocalGameVersion,LocalAppVersion,LocalResVersion;
		checkVersion(bundleVersion,bundleGameVersion,bundleAppVersion,bundleResVersion);
		checkVersion(newVersion,LocalGameVersion,LocalAppVersion,LocalResVersion);

		//-DANDROID in Android's Aplication.mk
#if !defined(ANDROID)
		/*
			our dreamonepiece android program have check and process apk(bundle) version to resource version
		*/
		//check if bundle version is larger-equal to resource version
		if(bundleGameVersion>LocalGameVersion || bundleAppVersion>LocalAppVersion || bundleVersion == newVersion)
		{
			clearVersion();
            cocos2d::FileUtils::getInstance()->purgeCachedEntries();
			//use bundle config again
			_parseConfigFile(bundleConfigFile);
		}
#endif
	}
	
	mNeedUpdateTotalBytes = 0u;

}


void SeverConsts::start()
{
	// [haizei] 本地单机模式：没有 version.cfg / 没有更新服务器时（PC 端现在就是这种
	// 情况），联网下载区服表必然失败，LoadingFrame 就会停在“检查更新失败”。
	// 这里直接读本地服表并置 CS_OK，让流程走到选服/登录。
	// 开关：Resources/haizei_local_mode.flag 存在即启用（想走线上热更删掉该文件即可）
	if(mSeverFile.empty() ||
		!cocos2d::FileUtils::getInstance()->fullPathForFilename("haizei_local_mode.flag").empty())
	{
		CCLOG("[SeverConsts] local mode enabled, skip update check");
		_loadLocalSevers();
		return;
	}

	std::string desFile(cocos2d::FileUtils::getInstance()->getWritablePath());
	desFile=desFile+"/"+TEMP_SEVER_FILE_DOWNLOADED;
	CurlDownload::Get()->downloadFile(mSeverFile,desFile);
	mCheckState = CS_CHECKING;
}

// ---------------------------------------------------------------------------
// [haizei] iOS 版通过 Tailscale 连本机服务
//
// iOS bundle 里带了 haizei_local_mode.flag，会走本地模式读 localSevers.json。
// 本地服表里的 127.0.0.1 会让手机去连它自己，永远连不到电脑上的游戏服。
// 因此 iOS 平台把回环地址替换成电脑的 Tailscale IP（100.65.143.49），
// 游戏服 DZM 绑定 0.0.0.0:25524，Tailscale 内网可直连。
// PC(Win32) 端保持原样，仍连本机 127.0.0.1。
//
// 注意：这是硬编码的 Tailscale IP，若电脑的 Tailscale 地址变了需同步修改此处。
// ---------------------------------------------------------------------------
static std::string haizeiSeverAddressForPlatform(const std::string& addr)
{
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS)
    if (addr.empty() || addr == "127.0.0.1" || addr == "localhost" || addr == "::1")
        return "100.65.143.49";
    return addr;
#else
    (void)addr;
    return addr;
#endif
}

// ---------------------------------------------------------------------------
// [haizei] 读取本地区服表
//
// 优先读 Resources/localSevers.json（格式与原区服表一致）：
//   { "defaultSeverID":1,
//     "severs":[{"id":1,"name":"本地服","address":"127.0.0.1","port":25524,"state":"general"}] }
// 没有该文件时退回内置的 127.0.0.1:25524（server/xml/config.xml 里的端口）。
// ---------------------------------------------------------------------------
void SeverConsts::_loadLocalSevers()
{
	cleanup();

	bool parsed = false;
	Json::Value root;
	Json::Reader reader;

	std::string path = cocos2d::FileUtils::getInstance()->fullPathForFilename("localSevers.json");
	if(!path.empty())
	{
		unsigned long filesize = 0;
		char* pBuffer = (char*)getFileData(path.c_str(),"rt",&filesize);
		if(pBuffer)
		{
			parsed = reader.parse(pBuffer,root,false) && root["severs"].isArray() && root["severs"].size()>0;
			CC_SAFE_DELETE_ARRAY(pBuffer);
		}
	}

	if(parsed)
	{
		Json::Value severs = root["severs"];
		for(int i=0;i<(int)severs.size();++i)
		{
			SEVER_ATTRIBUTE* severAtt = new SEVER_ATTRIBUTE;
			severAtt->name = severs[i]["name"].empty() ? "local" : severs[i]["name"].asString();
			severAtt->address = haizeiSeverAddressForPlatform(
				severs[i]["address"].empty() ? "127.0.0.1" : severs[i]["address"].asString());
			severAtt->port = severs[i]["port"].empty() ? 25524 : severs[i]["port"].asInt();
			severAtt->id = severs[i]["id"].empty() ? (i+1) : severs[i]["id"].asInt();
			severAtt->state = SS_GENERAL;
			std::string st = severs[i]["state"].isString() ? severs[i]["state"].asString() : "";
			if(st == "new")
				severAtt->state = SS_NEW;
			else if(st == "full")
				severAtt->state = SS_FULL;
			mSeverList.insert(std::make_pair(severAtt->id,severAtt));
		}
		mSeverDefaultID = root["defaultSeverID"].empty() ? mSeverList.begin()->first : root["defaultSeverID"].asInt();
	}
	else
	{
		SEVER_ATTRIBUTE* severAtt = new SEVER_ATTRIBUTE;
		severAtt->id = 1;
		severAtt->name = "本地服";
		severAtt->address = haizeiSeverAddressForPlatform("127.0.0.1");
		severAtt->port = 25524;
		severAtt->state = SS_GENERAL;
		mSeverList.insert(std::make_pair(severAtt->id,severAtt));
		mSeverDefaultID = 1;
	}

	// 选服时 LoadingFrame 会优先读 UserDefault，旧存档里的 id 可能已经不在表里
	if(mSeverList.find(mSeverDefaultID) == mSeverList.end())
	{
		mSeverDefaultID = mSeverList.begin()->first;
	}
	cocos2d::UserDefault::getInstance()->setIntegerForKey("DefaultSeverID",mSeverDefaultID);

	mServerInUpdateCode = false;
	mServerInUpdateMsg.clear();
	mAnnouncement.clear();
	mUpdateFile.clear();
	if(mLocalVerson.empty())
	{
		mLocalVerson = "1.0.0.0";
	}
	mSeverVerson = mLocalVerson;
	mCheckState = CS_OK;

	CCLOG("[SeverConsts] local sever mode: id=%d %s:%d",
		mSeverList.begin()->second->id,
		mSeverList.begin()->second->address.c_str(),
		mSeverList.begin()->second->port);
}

bool SeverConsts::_parseConfigFile( const std::string& configfile )
{
	Json::Value root;
	Json::Reader jreader;
	Json::Value data;
	unsigned long filesize;
    
	char* pBuffer = (char*)getFileData(configfile.c_str(),
		"rt",&filesize);

	bool openSuccessful = true;
	if(!pBuffer)
	{
		char msg[256];
		sprintf(msg,"Failed open file: %s !!",configfile.c_str());
		//cocos2d::CCMessageBox(msg,"ERROR!");
		openSuccessful = false;
	}
	else
	{
		openSuccessful = jreader.parse(pBuffer,data,false);
		if(openSuccessful && data["version"].asInt()==1 && !data["localVerson"].empty() && !data["sever"].empty())
		{
			mLocalVerson = data["localVerson"].asString();
			mSeverFile = data["sever"].asString();

			if(!data["inStoreUpdate"].empty() && data["inStoreUpdate"].isString())
			{
				mInStoreUpdate = data["inStoreUpdate"].asString();
			}
			if(!data["severBackup"].empty() && data["severBackup"].isString())
			{
				mSeverBackup = data["severBackup"].asString();
			}
			else
				mSeverBackup = "";
			//
			if (!data["androidApk"].empty() && data["androidApk"].isObject())
			{
				Json::Value androidApk = data["androidApk"];
				std::string platform_str = libPlatformManager::getPlatform()->getClientChannel();
				if (!androidApk["rootAddress"].empty() && !androidApk[platform_str].empty())
				{
					mDirectDownloadUrl = androidApk["rootAddress"].asString() + androidApk[platform_str].asString();
				}
				if (!androidApk["downloadMsg"].empty())
				{
					mDirectDownloadMsg = androidApk["downloadMsg"].asString();
				}
			}
			//

			//some android platform has its own server,read the server address
			if (!data["androidServer"].empty() && data["androidServer"].isObject())
			{
				Json::Value androidServer = data["androidServer"];
				std::string platform_str = libPlatformManager::getPlatform()->getClientChannel();
				char serverStr[128];
				char serverBackupStr[128];
				sprintf(serverStr,"%s_sever",platform_str.c_str());
				sprintf(serverBackupStr,"%s_severBackup",platform_str.c_str());
				if (!androidServer[serverStr].empty())
				{
					mSeverFile =  androidServer[serverStr].asString();
				}
				if(!androidServer[serverBackupStr].empty()&&androidServer[serverBackupStr].isString())
				{
					mSeverBackup = androidServer[serverBackupStr].asString();
				}
			}
		}
		else
			openSuccessful = false;
		CC_SAFE_DELETE_ARRAY(pBuffer);
        
	}
	return openSuccessful;
}


void SeverConsts::update( float dt )
{

	CurlDownload::Get()->update(dt);
	if(mUpdateState == US_CHECKING && _waitThreadFileCheck == FCS_DONE)
	{
		mUpdateState = US_DOWNLOADING;

		AutoRelaseLock _autolock(_waitThreadFileCheckMutex);
		_waitThreadFileCheck = FCS_NOTSTART;
		
		mCheckFileThread.shutdown();

		cocos2d::FileUtils::getInstance()->setPopupNotify(_isPopNotifyWhenFileNotFound);
		_downloadFiles();
	}
}

void SeverConsts::downloaded( const std::string& url,const std::string& filename )
{
	if(url == mSeverFile)
	{
		_parseSeverFile(filename);
	}
	else if(url == mUpdateFile)
	{
		_parseUpdateFile(filename);
		_checkUpdateFile();
		//_downloadFiles();
	}
	else
	{
		AutoRelaseLock autolock(mFileListMutex);

		FILELIST filelist;
		filelist.swap(mFileList);
		FILELIST::iterator it = filelist.begin();
		for(;it!=filelist.end();++it)
		{
			if((*it)->filename == filename)
			{
				mUpdatedCount+=(*it)->size;
				delete (*it);
			}
			else
			{
				mFileList.push_back(*it);
			}
		}
		if(mFileList.empty())
		{
			if(mDownloadFailedList.empty())
			{
				//mUpdateState = US_OK;
				//_finishUpdate();

				mUpdateState = US_NOT_STARTED;
				cocos2d::FileUtils::getInstance()->purgeCachedEntries();
				updateResources();
			}
			else
				mUpdateState = US_FAILED;
		}
	}
}

void SeverConsts::downloadFailed( const std::string& url, const std::string& filename )
{
	if(url == mSeverFile)
	{
		static int _serveFileErrCount=0;
		if(_serveFileErrCount<=30)
		{
			start();
			_serveFileErrCount++;
		}
		else
		{
			if(_getSeversWithBackupAddress())
			{
				return;
			}
			else
			{
				mCheckState = CS_FAILED;
			}
		}
	}
	else if(url == mUpdateFile)
	{
		static int _updateFileErrCount=0;
		if(_updateFileErrCount<=30)
		{
			_retryUpdateFile();
			_updateFileErrCount++;
		}
		else
		{
			mUpdateState = US_FAILED;
		}
	}
	else
	{
		AutoRelaseLock autolock(mFileListMutex);
		FILELIST filelist;
		filelist.swap(mFileList);
		FILELIST::iterator it = filelist.begin();
		for(;it!=filelist.end();++it)
		{
			if((*it)->filename == filename)
			{
				mDownloadFailedList.push_back(filename);
				delete (*it);
			}
			else
			{
				mFileList.push_back(*it);
			}
		}
		if(mFileList.empty() && !mDownloadFailedList.empty())
			mUpdateState = US_FAILED;
	}
	std::string::size_type index=url.find_last_of("/");
	if(index!=url.npos)
	{
		mFailedName=url.substr(index+1,url.length());
	}
	else
	{
		mFailedName=url;
	}
}


void SeverConsts::_parseSeverFile( const std::string& severfile )
{
	Json::Value root;
	Json::Reader jreader;
	Json::Value data;
	unsigned long filesize;
	char* pBuffer = (char*)getFileData(
		cocos2d::FileUtils::getInstance()->fullPathForFilename(severfile.c_str()).c_str(),
		"rt",&filesize);

	if(!pBuffer)
	{
		if(_getSeversWithBackupAddress())
			return;
		else
		{
			cocos2d::CCMessageBox("1 FAILED to get Sever file!!","ERROR!");
			mCheckState = CS_FAILED;
			CC_SAFE_DELETE_ARRAY(pBuffer);
			return;
		}
	}
	
	jreader.parse(pBuffer,data,false);
	if(	data["version"].empty() || 
		data["version"].asInt()!=1 ||
		data["severs"].empty() ||
		!data["severs"].isArray() ||
		data["severVerson"].empty() ||
		data["updateAddress"].empty() ||
		data["defaultSeverID"].empty() ||
		data["rootAddress"].empty())
	{
		if(_getSeversWithBackupAddress())
			return;
		else
		{
			cocos2d::CCMessageBox("2 FAILED to get Sever file!!","ERROR!");
			mCheckState = CS_FAILED;
			CC_SAFE_DELETE_ARRAY(pBuffer);
			return;
		}
	}
	//--begin xinzheng 2013-7-17
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID) || defined(WIN32)
	if (!data["androidApk"].empty() && data["androidApk"].isObject())
	{
		Json::Value androidApk = data["androidApk"];
		std::string platform_str = libPlatformManager::getPlatform()->getClientChannel();
		if (!androidApk["rootAddress"].empty() && !androidApk[platform_str].empty())
		{
			mDirectDownloadUrl = androidApk["rootAddress"].asString() + androidApk[platform_str].asString();
		}
		if (!androidApk["downloadMsg"].empty())
		{
			mDirectDownloadMsg = androidApk["downloadMsg"].asString();
		}
	}
#else
	if (!data["iosIpa"].empty() && data["iosIpa"].isObject())
	{
		Json::Value iosIpa = data["iosIpa"];
		std::string platform_str = libPlatformManager::getPlatform()->getClientChannel();
		if (!iosIpa["rootAddress"].empty() && !iosIpa[platform_str].empty())
		{
			mDirectDownloadUrl = iosIpa["rootAddress"].asString() + iosIpa[platform_str].asString();
		}
		if (!iosIpa["downloadMsg"].empty())
		{
			mDirectDownloadMsg = iosIpa["downloadMsg"].asString();
		}
	}
#endif
	if (!data["updateByteSize"].empty())
	{
		mNeedUpdateTotalBytes = data["updateByteSize"].asUInt();
	}
	if (!data["updateMsg"].empty())
	{
		mNeedUpdateMsg = data["updateMsg"].asString();
	}
	else
		mNeedUpdateMsg = "";
	//--end
	cleanup();
	Json::Value severs = data["severs"];
	for(int i=0;i<severs.size();++i)
	{
		if(	!severs[i]["name"].empty() &&
			!severs[i]["address"].empty() &&
			!severs[i]["port"].empty() &&
			!severs[i]["id"].empty() &&
			!severs[i]["state"].empty() )
		{
			SEVER_ATTRIBUTE* severAtt = new SEVER_ATTRIBUTE;
			severAtt->name = severs[i]["name"].asString();
			severAtt->address = severs[i]["address"].asString();
			severAtt->port = severs[i]["port"].asInt();
			severAtt->id = severs[i]["id"].asInt();
			if(severs[i]["state"].asString() == "general")
				severAtt->state = SS_GENERAL;
			else if(severs[i]["state"].asString() == "new")
				severAtt->state = SS_NEW;
			else if(severs[i]["state"].asString() == "full")
				severAtt->state = SS_FULL;

			mSeverList.insert(std::make_pair(severAtt->id,severAtt));
		}
	}

	mUpdateFile = data["updateAddress"].asString();
	mSeverVerson = data["severVerson"].asString();
	mUpdateRootAddress = data["rootAddress"].asString();
	mSeverDefaultID = data["defaultSeverID"].asInt();
    
    if(!data["inStoreUpdate"].empty() && data["inStoreUpdate"].isString())
    {
        mInStoreUpdate = data["inStoreUpdate"].asString();
    }
    
	if(	!data["announcement"].empty() )
	{
		mAnnouncement = data["announcement"].asString();
	}
	if(!data["serverInUpdate"].empty())
	{
		mServerInUpdateMsg = data["serverInUpdate"].asString();
		if (!mServerInUpdateMsg.empty())
			mServerInUpdateCode = true;
	}
	else
	{
		mServerInUpdateCode = false;
	}

	int SeverGameVersion,SeverAppVersion,SeverResVersion;
	int LocalGameVersion,LocalAppVersion,LocalResVersion;
	checkVersion(mSeverVerson,SeverGameVersion,SeverAppVersion,SeverResVersion);
	checkVersion(mLocalVerson,LocalGameVersion,LocalAppVersion,LocalResVersion);
	
	if(SeverGameVersion>LocalGameVersion || SeverAppVersion>LocalAppVersion)
	{
		mCheckState = CS_NEED_STORE_UPDATE;
		CC_SAFE_DELETE_ARRAY(pBuffer);
        remove(cocos2d::FileUtils::getInstance()->fullPathForFilename(severfile.c_str()).c_str());
        
		return;
	}
	if(SeverGameVersion==LocalGameVersion && SeverAppVersion==LocalAppVersion &&SeverResVersion>LocalResVersion)
	{
		mCheckState = CS_NEED_UPDATE;
		CC_SAFE_DELETE_ARRAY(pBuffer);
        remove(cocos2d::FileUtils::getInstance()->fullPathForFilename(severfile.c_str()).c_str());
        return;
	}
	mCheckState = CS_OK;
	CC_SAFE_DELETE_ARRAY(pBuffer);
    remove(cocos2d::FileUtils::getInstance()->fullPathForFilename(severfile.c_str()).c_str());
}

void SeverConsts::cleanup()
{
	for(SEVERLIST::iterator it = mSeverList.begin();it!=mSeverList.end();++it)
		if(it->second)delete it->second;
	mSeverList.clear();
}

void SeverConsts::checkVersion( const std::string& versionStr ,int &GameVersion, int &appVersion, int& resVersion)
{
	std::string chechStr = versionStr;

	int firstMaohao = versionStr.find_first_of(':');
	if(firstMaohao<versionStr.size() && firstMaohao!=std::string::npos)
		chechStr = versionStr.substr(firstMaohao+1,versionStr.length()-firstMaohao-1);
	
	int offset = 0;
	int lastOffset = chechStr.find_first_of('.',offset);
	std::string val = chechStr.substr(offset,lastOffset);
	sscanf(val.c_str(),"%d",&GameVersion);
	offset = lastOffset+1;

	lastOffset = chechStr.find_first_of('.',offset);
	val = chechStr.substr(offset,lastOffset);
	sscanf(val.c_str(),"%d",&appVersion);
	offset = lastOffset+1;

	lastOffset = chechStr.find_first_of('.',offset);
	val = chechStr.substr(offset,lastOffset);
	sscanf(val.c_str(),"%d",&resVersion);
	offset = lastOffset+1;
}

void SeverConsts::updateResources()
{
	if(mUpdateState == US_NOT_STARTED)
	{
		mUpdateState = US_CHECKING;
		std::string desFile(cocos2d::FileUtils::getInstance()->getWritablePath());
		desFile=desFile+"/"+TEMP_UPDATE_FILE_DOWNLOADED;
		CurlDownload::Get()->downloadFile(mUpdateFile,desFile);
	}
}

void SeverConsts::_retryUpdateFile()
{
	mUpdateState = US_CHECKING;
	std::string desFile(cocos2d::FileUtils::getInstance()->getWritablePath());
	desFile=desFile+"/"+TEMP_UPDATE_FILE_DOWNLOADED;
	CurlDownload::Get()->downloadFile(mUpdateFile,desFile);
}

void SeverConsts::_parseUpdateFile( const std::string& severfile )
{
	Json::Value root;
	Json::Reader jreader;
	Json::Value data;
	unsigned long filesize;
	char* pBuffer = (char*)getFileData(
		cocos2d::FileUtils::getInstance()->fullPathForFilename(severfile.c_str()).c_str(),
		"rt",&filesize);

	if(!pBuffer)
	{
		cocos2d::CCMessageBox("FAILED to get Update file!!","ERROR!");
		mUpdateState = US_FAILED;
		CC_SAFE_DELETE_ARRAY(pBuffer);
		return;
	}

	jreader.parse(pBuffer,data,false);
	if(	data["version"].empty() || 
		data["version"].asInt()!=1 ||
		data["severVersion"].empty() ||
		data["files"].empty() ||
		!data["files"].isArray())
	{
		cocos2d::CCMessageBox("FAILED to parse Update file!!","ERROR!");
		mUpdateState = US_FAILED;
		CC_SAFE_DELETE_ARRAY(pBuffer);
		return;
	}
	if(data["severVersion"].asString()!=mSeverVerson)
	{
		cocos2d::CCMessageBox("Sever Version different!!","ERROR!");
		mUpdateState = US_FAILED;
		CC_SAFE_DELETE_ARRAY(pBuffer);
		return;
	}
	unsigned long long totalSize = 0;
	{
		AutoRelaseLock autolock(mFileListMutex);

		Json::Value files = data["files"];
		for(int i=0;i<files.size();++i)
		{
			if(	!files[i]["c"].empty() &&
				!files[i]["f"].empty() &&
				!files[i]["s"].empty())
			{
				FILE_ATTRIBUTE* fileatt = new FILE_ATTRIBUTE;
				fileatt->filename = files[i]["f"].asString();
				if(fileatt->filename.find_first_of("/\\") == 0)
				{
					fileatt->filename = fileatt->filename.substr(1,fileatt->filename.size());
				}
				fileatt->crc = files[i]["c"].asInt();
				fileatt->size = files[i]["s"].asInt();

				totalSize+=fileatt->size;

				mFileList.push_back(fileatt);
			}
		}
	}
    remove(	cocos2d::FileUtils::getInstance()->fullPathForFilename(severfile.c_str()).c_str());

	CC_SAFE_DELETE_ARRAY(pBuffer);

	long long freespace = libOS::getInstance()->getFreeSpace();
	if(freespace>0 && totalSize > freespace)
	{
		cocos2d::CCMessageBox("Not enough space for update!!","ERROR!");
		mUpdateState = US_FAILED;
	}

	mNeedUpdateTotalBytes = totalSize;

}

void SeverConsts::_checkUpdateFile()
{
	AutoRelaseLock _autolock(_waitThreadFileCheckMutex);
	_waitThreadFileCheck = FCS_CHECKING;

	_isPopNotifyWhenFileNotFound = cocos2d::FileUtils::getInstance()->isPopupNotify();
	cocos2d::FileUtils::getInstance()->setPopupNotify(false);

	AutoRelaseLock _autolockFiles(mFileListMutex);
	FILELIST::iterator it = mFileList.begin();
	for(;it!=mFileList.end();++it)
	{
        //CCLOG((*it)->filename.c_str());
		std::string filepath = cocos2d::FileUtils::getInstance()->fullPathForFilename((*it)->filename.c_str());
		(*it)->checkpath = filepath;
	}


	mCheckFileThread.execute(new SeverCheckingFileTask);
// 	AutoRelaseLock autolock(mFileListMutex);
// 	FILELIST checkList;
// 	checkList.swap(mFileList);
// 	FILELIST::iterator it = checkList.begin();
// 	bool notify = cocos2d::FileUtils::getInstance()->isPopupNotify();
// 	cocos2d::FileUtils::getInstance()->setPopupNotify(false);
// 
// 	for(;it!=checkList.end();++it)
// 	{
// 		std::string filepath = cocos2d::FileUtils::getInstance()->fullPathFromRelativePath((*it)->filename.c_str());
// 		unsigned long filesize;
// 
// 		char* pBuffer = (char*)cocos2d::FileUtils::getInstance()->getFileData(
// 			cocos2d::FileUtils::getInstance()->fullPathFromRelativePath(filepath.c_str()),
// 			"rb",&filesize);
// 		
// 		if(!pBuffer || GameMaths::GetCRC16((unsigned char*)pBuffer,filesize) != (*it)->crc)
// 			mFileList.push_back(*it);
// 		else
// 			delete *it;
// 	}
// 	cocos2d::FileUtils::getInstance()->setPopupNotify(notify);

}

void SeverConsts::_downloadFiles()
{
	AutoRelaseLock autolock(mFileListMutex);
	FILELIST::iterator it = mFileList.begin();
	mUpdateTotalCount = 0;
	for(;it!=mFileList.end();++it)
	{
		std::string url = mUpdateRootAddress+(*it)->filename;
		(*it)->filename =	cocos2d::FileUtils::getInstance()->getWritablePath() +"/"+
								mAdditionalSearchPath+ "/" +(*it)->filename;
		CurlDownload::Get()->downloadFile(url,(*it)->filename,(*it)->crc);
		mUpdateTotalCount+=(*it)->size;
	}
	if(mFileList.empty())
	{
		_finishUpdate();
	}
	else
		mUpdateState = US_DOWNLOADING;
}

SeverConsts::FILELIST& SeverConsts::_lockFileList()
{
	mFileListMutex.lock();
	return mFileList;
}

void SeverConsts::_unlockFileList()
{
	mFileListMutex.unlock();
}

void SeverConsts::_notifyFileCheckDone()
{
	AutoRelaseLock _autolock(_waitThreadFileCheckMutex);
	_waitThreadFileCheck = FCS_DONE;
}
void SeverConsts::clearVersion()
{
    std::string tempFile(cocos2d::FileUtils::getInstance()->getWritablePath());
 	tempFile.append("/");
 	tempFile.append(TEMP_CONFIG_FILE_BACKUP);
	remove(tempFile.c_str());
    
	std::string desFile(cocos2d::FileUtils::getInstance()->getWritablePath());
    desFile.append("/");
    desFile.append(mAdditionalSearchPath);
	desFile.append("/");

#if !defined(ANDROID)
	/*
		for android, desfile path is bundle unziped path, we do not remove it
	*/
    libOS::getInstance()->rmdir(desFile.c_str());
#endif
    CCLOG("clearVersion dir:%s",desFile.c_str());
}
void SeverConsts::_finishUpdate()
{
	std::string tempFile(cocos2d::FileUtils::getInstance()->getWritablePath());
	tempFile.append("/");
	tempFile.append(TEMP_CONFIG_FILE_BACKUP);

	std::string desFile(cocos2d::FileUtils::getInstance()->getWritablePath());
	desFile.append("/");
	desFile.append(mAdditionalSearchPath);
	desFile.append("/");
	desFile.append(mConfigFile);

	//{
		Json::Value root;
		Json::Reader jreader;
		Json::Value data;
		unsigned long filesize;

		char* pBuffer = (char*)getFileData(mCfgFilePath.c_str(),
			"rt",&filesize);

		bool openSuccessful = true;
		if(!pBuffer)
		{
			char msg[256] = {0};
			sprintf(msg,"_finishUpdate Failed read file: %s !!",mCfgFilePath.c_str());
			//cocos2d::CCMessageBox(msg,"ERROR!");
			CCLOG(msg);

			openSuccessful = false;
		}
		else
		{
			openSuccessful = jreader.parse(pBuffer,data,false);
		}
		if (!openSuccessful)
		{
			CCLOG("_finishUpdate Failed parse file: %s !!", mCfgFilePath.c_str());
		}
	//}
	if (openSuccessful)
	{
		data["version"] = 1;
		data["localVerson"] = mSeverVerson;
		data["sever"] = mSeverFile;
		Json::StyledWriter writer;
		std::string outstr = writer.write(data);

#if !defined(ANDROID)
		saveFileInPath(tempFile,"wb",(const unsigned char*)outstr.c_str(),outstr.size());
		
#else
		//android not use that tempFile
#endif
		saveFileInPath(desFile,"wb",(const unsigned char*)outstr.c_str(),outstr.size());
	}

	mUpdateState = US_OK;

	//--begin xinzheng 2013-7-15
	//暂时特别处理，重新加载Lang文件，可以修改设计，实现内更新后自动重新加载必要文件或者重启游戏
	if (true)
	{
		Language::Get()->clear();
		Language::Get()->init("Lang/chinese.lang");
	}
	//--end
}

bool SeverConsts::isServerInUpdatingCode()
{
	return mServerInUpdateCode;
}

void SeverConsts::initSearchPath()
{
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
	mAdditionalSearchPath = "assets";
#else
	mAdditionalSearchPath = "_additionalSearchPath";
#endif
	const std::vector<std::string>& paths = cocos2d::FileUtils::getInstance()->getSearchPaths();
	mOriSearchPath.assign(paths.begin(),paths.end());
	cocos2d::FileUtils::getInstance()->purgeCachedEntries();
}

void SeverConsts::setOriginalSearchPath()
{
	cocos2d::FileUtils::getInstance()->setSearchPaths(mOriSearchPath);

#if ((CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID) || (CC_TARGET_PLATFORM == CC_PLATFORM_IOS) )
	//CCFileUtilsAndroid.cpp
	std::string searchpath = "lua";
	cocos2d::FileUtils::getInstance()->addSearchPath(searchpath.c_str());
	searchpath = "ccbi";
	cocos2d::FileUtils::getInstance()->addSearchPath(searchpath.c_str());
	searchpath = "txt";
	cocos2d::FileUtils::getInstance()->addSearchPath(searchpath.c_str());

#else

	std::string searchpath = "/lua";
	cocos2d::FileUtils::getInstance()->addSearchPath(searchpath.c_str());
	searchpath = "/ccbi";
	cocos2d::FileUtils::getInstance()->addSearchPath(searchpath.c_str());
	searchpath = "/txt";
	cocos2d::FileUtils::getInstance()->addSearchPath(searchpath.c_str());
#endif
	cocos2d::FileUtils::getInstance()->purgeCachedEntries();

}

void SeverConsts::setAdditionalSearchPath()
{
#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
	return;//CCFileUtilsAndroid.cpp
#endif
	std::vector<std::string> paths;
	
	std::string searchpath = cocos2d::FileUtils::getInstance()->getWritablePath()+"/"+mAdditionalSearchPath;
	paths.push_back(searchpath.c_str());
	searchpath = cocos2d::FileUtils::getInstance()->getWritablePath()+"/"+mAdditionalSearchPath+"/lua";
	paths.push_back(searchpath.c_str());
	searchpath = cocos2d::FileUtils::getInstance()->getWritablePath()+"/"+mAdditionalSearchPath+"/ccbi";
	paths.push_back(searchpath.c_str());
	searchpath = cocos2d::FileUtils::getInstance()->getWritablePath()+"/"+mAdditionalSearchPath+"/txt";
	paths.push_back(searchpath.c_str());

	for(std::vector<std::string>::iterator it = mOriSearchPath.begin();it!=mOriSearchPath.end();++it)
		paths.push_back(*it);
    
#if  (CC_TARGET_PLATFORM == CC_PLATFORM_IOS) 
	searchpath = "lua";
	paths.push_back(searchpath.c_str());
	searchpath = "ccbi";
	paths.push_back(searchpath.c_str());
	searchpath = "txt";
	paths.push_back(searchpath.c_str());
#else
	searchpath = "/lua";
	paths.push_back(searchpath.c_str());
	searchpath = "/ccbi";
	paths.push_back(searchpath.c_str());
	searchpath = "/txt";
	paths.push_back(searchpath.c_str());
#endif

	cocos2d::FileUtils::getInstance()->setSearchPaths(paths);

	cocos2d::FileUtils::getInstance()->purgeCachedEntries();
}

bool SeverConsts::_getSeversWithBackupAddress()
{
	if(mSeverBackup!="" && mSeverBackup!=mSeverFile)
	{
		mSeverFile = mSeverBackup;
		start();
		return true;
	}
	return false;
}


