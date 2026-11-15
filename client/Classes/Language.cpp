
#include "stdafx.h"

#include "Language.h"
#include "json/json.h"
#include "cocos2d.h"
#include "GamePlatform.h"

USING_NS_CC;

void Language::init( const std::string& languagefile )
{
	addLanguageFile(languagefile);
}

void Language::addLanguageFile( const std::string& languagefile )
{
	// [haizei][diag] PageHeap 取证：打印入参字符串的实际指针/内容
	if (getenv("HAIZEI_MENU_DIAG"))
		CCLOG("[LangDiag] addLanguageFile this=%p ref=%p ptr=%p len=%d content=%s",
			(void*)this, (const void*)&languagefile,
			(const void*)languagefile.c_str(), (int)languagefile.size(),
			languagefile.c_str());

	Json::Reader jreader;
	Json::Value data;
	unsigned long filesize;
	// [haizei] 路径临时对象具名化，保证整个调用期间有效（PageHeap 下曾在此野读崩溃）
	if (getenv("HAIZEI_MENU_DIAG")) CCLOG("[LangDiag] step1 before fullPath");
	std::string fullPath = cocos2d::FileUtils::getInstance()->fullPathForFilename(languagefile.c_str());
	if (getenv("HAIZEI_MENU_DIAG")) CCLOG("[LangDiag] step2 fullPath=%s", fullPath.c_str());
	char* pBuffer = (char*)getFileData(fullPath.c_str(), "rt", &filesize);
	if (getenv("HAIZEI_MENU_DIAG")) CCLOG("[LangDiag] step3 read size=%u buf=%p", filesize, (void*)pBuffer);

	if(!pBuffer)
	{
		char msg[256];
		sprintf(msg,"Failed open file: %s !!",languagefile.c_str());
		cocos2d::CCMessageBox(msg,"ERROR!");
	}
	else
	{
		jreader.parse(pBuffer,data,false);
		CC_SAFE_DELETE_ARRAY(pBuffer);

		if(data["version"].asInt()==1)
		{
			Json::Value files = data["strings"];
			if(!files.empty() && files.isArray())
			{
				for(int i = 0;i < files.size();++i)
				{
					Json::Value unit = files[i];
					if(unit["k"].empty()) continue;
					std::string _key = unit["k"].asString();
					std::string _value = unit["v"].asString();
					replaceEnter(_key);
					if(mStrings.find(_key)==mStrings.end())
						mStrings.insert(std::make_pair(_key,_value));
					else
					{
						char msg[256];
						sprintf(msg,"Multiple defines of string: %s !!",_key.c_str());
						cocos2d::CCMessageBox(msg,"ERROR!");
					}
				}
			}

		}
	}
	CC_SAFE_DELETE_ARRAY(pBuffer);
}

const std::string & Language::getString( const std::string& _key )
{
	std::map<std::string,std::string>::const_iterator it = mStrings.find(_key);
	if(it!=mStrings.end())
		return it->second;
	else
		return _key;

}

bool Language::hasString( const std::string& _key )
{
	std::map<std::string,std::string>::iterator it = mStrings.find(_key);
	return (it!=mStrings.end());
}


void Language::updateNode( cocos2d::CCNode* _root )
{
	// [haizei] 防御：loadCcbiFile 在资源缺失时会以 nullptr 调用本函数，
	// 直接访问 _root->getChildren() 会空指针崩溃。先判空再处理。
	if(!_root) return;
	cocos2d::CCLabelBMFont* bmf = dynamic_cast<cocos2d::CCLabelBMFont* >(_root);
	if(bmf)
	{	
		std::string _key = bmf->getString();
		replaceEnter(_key);
		if(hasString(_key))
		{
			const std::string& str = Language::Get()->getString(_key);
			bmf->setString(str.c_str());
		}
	}
	cocos2d::CCLabelTTF *ttf = dynamic_cast<cocos2d::CCLabelTTF* >(_root);
	if(ttf)
	{	
		std::string _key = ttf->getString();
		if(hasString(_key))
		{
			const std::string& str = Language::Get()->getString(_key);
			ttf->setString(str.c_str());
		}
	}

	for (auto pObj : _root->getChildren())
	{
		cocos2d::CCNode* subnode = dynamic_cast<cocos2d::CCNode*>(pObj);
		if(subnode)
		{
			updateNode(subnode);
		}
	}
}

void Language::replaceEnter( std::string &_str )
{
	if(_str.find_first_of('\r')==std::string::npos && _str.find_first_of('\n')==std::string::npos)
		return;

	std::string ret;
	for(std::string::size_type i=0;i<_str.size();++i)
	{
		if(_str[i]!='\r'&&_str[i]!='\n')
			ret+=_str[i];
	}
	_str = ret;
}

void Language::clear()
{
	mStrings.clear();
}

Language* Language::getInstance()
{
	return Language::Get();
}
