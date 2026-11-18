
#include "stdafx.h"

#include "DiscipleChangePage.h"
#include "ServerDateManager.h"
#include "StringConverter.h"
#include "DataTableManager.h"
#include "BlackBoard.h"
#include "Disciple.h"
#include "Skill.h"
#include "PopupPage.h"
#include "MessageBoxPage.h"

REGISTER_PAGE("DiscipleChangePage",DiscipleChangePage);
USING_NS_CC;

void DiscipleChangeContent::refreshContent( void )
{
	mSelect = dynamic_cast<CCMenuItemImage* >(mContentContainer->getVariable("mSelect"));
	mSelect->retain();
	//mSelect->unselected();
	mSelect->setNormalImage(::getContentUnselectedSpirte("Normal"));
	mSelect->setSelectedImage(::getContentUnselectedSpirte("Normal"));

	Disciple disciple(mID);
	CCSprite* prop=dynamic_cast<CCSprite* >(mContentContainer->getVariable("mHeadPic"));
	if(prop)
	{
		prop->initWithFile(disciple.iconPic().c_str());
	}
	CCMenuItemImage* qualityFrame=dynamic_cast<CCMenuItemImage* >(mContentContainer->getVariable("mQualityFrame"));
	if(qualityFrame)
	{
		qualityFrame->setNormalImage(disciple.getFrameNormalSpirte());
		qualityFrame->setSelectedImage(disciple.getFrameSelectedSpirte());
	}
	CCLabelBMFont* name=dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mName"));
	if(name)
	{
		name->setString(Language::Get()->getString(disciple.name()).c_str());
#if defined(Macro_TestUseCCReViScrollViewFacade) && defined(_DEBUG)
		std::string strTmp = StringConverter::toString(this->m_iIdx) + Language::Get()->getString(disciple.name());
		name->setString(strTmp.c_str());
#endif
	}
	CCSprite* quality=dynamic_cast<CCSprite* >(mContentContainer->getVariable("mMemQuality"));
	if(quality)
	{
		quality->initWithFile(disciple.getQualityImageFile().c_str());
	}
	CCLabelBMFont* levelName=dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mMemLevel"));
	if(levelName)
	{
		levelName->setString(StringConverter::toString(disciple.level()).c_str());
	}
	CCLabelBMFont* valueKey=dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mMemValue"));
	if(valueKey)
	{
		valueKey->setString(StringConverter::toString(disciple.getDiscipleValue()).c_str());
	}
#ifdef Macro_TestUseCCReViScrollViewFacade
	setSellect(m_pItemData->m_bSelected);
#endif
}

void DiscipleChangeContent::onMenuItemAction( const std::string& itemName, cocos2d::CCObject* sender, int tag )
{
	if(itemName=="onSelected")
	{
#ifdef Macro_TestUseCCReViScrollViewFacade
		// [haizei] 选中记录在数据对象上；视图复用后 this 指针对应的行会变，
		// 不能再传视图指针（点确认会换到隔壁船员的根因）
		if(m_pItemData)
		{
			mOwnner->setSellectedContent(m_pItemData);
			setSellect(m_pItemData->m_bSelected);
		}
#else
		mOwnner->setSellectedContent(this);
#endif
	}
}

void DiscipleChangeContent::setSellect( bool sellect )
{
	if(!mSelect)
	{
		return;
	}
	if(sellect)
	{
		//mSelect->selected();
		mSelect->setNormalImage(::getContentSelectedSpirte("Normal"));
		mSelect->setSelectedImage(::getContentSelectedSpirte("Normal"));
	}
	else
	{
		//mSelect->unselected();
		mSelect->setNormalImage(::getContentUnselectedSpirte("Normal"));
		mSelect->setSelectedImage(::getContentUnselectedSpirte("Normal"));
	}
}

DiscipleChangeContent::~DiscipleChangeContent()
{
	if(mSelect)
		mSelect->release();
}

#ifdef Macro_TestUseCCReViScrollViewFacade

void DiscipleChangeContent::initItemView()
{
	mContentContainer = CCBManager::Get()->createAndLoad(getCcbiFileName());
	mContentContainer->setListener(this);
	mContentContainer->retain();
	//
	this->m_pItemNode = mContentContainer;
}

void DiscipleChangeContent::refreshItemView( cocos2d::extension::CCReViSvItemData* pItem )
{
	DiscipleChangeContentItemData* pItemData = static_cast<DiscipleChangeContentItemData*>(pItem);
	if (pItemData)
	{
		this->m_pItemData = pItemData;
		this->mID = pItemData->m_iDiscipleID;
#ifdef _DEBUG
		this->m_iIdx = pItemData->m_iIdx;
#endif
		this->refreshContent();
	}
}

#endif

DiscipleChangePage::DiscipleChangePage(void)
{
	membersRootNode = NULL;
	members = NULL;
	mContentList.clear();
	mCurSellectedContent = NULL;
#ifdef Macro_TestUseCCReViScrollViewFacade
	m_curSelectedItemData = NULL;
#endif
	isDesOrder=true;
}

DiscipleChangePage::~DiscipleChangePage(void)
{
}

void DiscipleChangePage::Enter( MainFrame* frame)
{
	confirmFlag = true;
	isDesOrder=true;
	rebuildAllItem();
	mCurSellectedContent = NULL;
#ifdef Macro_TestUseCCReViScrollViewFacade
	m_curSelectedItemData = NULL;
#endif
	refreshPage();
}

void DiscipleChangePage::Exit( MainFrame* frame)
{
	clearAllItem();
#ifdef Macro_TestUseCCReViScrollViewFacade
	delete m_pScrollViewFacade;
	m_pScrollViewFacade = NULL;
#endif
	members = NULL;
	membersRootNode = NULL;
}

void DiscipleChangePage::Execute( MainFrame* )
{

}

void DiscipleChangePage::load( void )
{
	loadCcbiFile("MemberReplace.ccbi");
	members =  dynamic_cast<cocos2d::extension::CCScrollView*>(getVariable("mChangeContent"));
	membersRootNode = members->getContainer();

#ifdef Macro_TestUseCCReViScrollViewFacade
	m_pScrollViewFacade = new cocos2d::extension::CCReViScrollViewFacade(members);
	m_pScrollViewFacade->init(Macro_FixedViewItemsMaxNum,Macro_FixedViewItemsMaxNum);
#endif

}

bool DiscipleFilter_Change(unsigned int id)
{
	//��ǰ����
	if(id == BlackBoard::Get()->CurChangeDiscipleID)
	{
		return false;
	}
	if(id != 0)
	{
		//������
		Disciple disciple(id);
		if(disciple.isInBattle())
			return false;
	}

	return true;
}

void DiscipleChangePage::buildItem( void )
{
	DiscipleDateCollect::DiscipleIDCollect collect = DiscipleDateCollect::Get()->getDiscipleCollection(DiscipleFilter_Change);
	if(collect.size()<=0)
	{
		CCBContainer* longButton = CCBManager::Get()->createAndLoad("LongButton.ccbi");
		longButton->setListener(this,999);
		if(longButton)
		{
			CCLabelBMFont* goGetBtnLabel=dynamic_cast<CCLabelBMFont*>(longButton->getVariable(("mButtonLabel")));
			if(goGetBtnLabel)
			{
				goGetBtnLabel->setString(Language::Get()->getString("@GoMarketGetDisciple").c_str());
			}
			membersRootNode->addChild(longButton);
			CCPoint pos = ccp(0,0);
			longButton->setPosition(pos);
			CCSize size = CCSize(longButton->getContentSize().width, longButton->getContentSize().height);
			members->setContentSize(size);
			members->setContentOffset(ccp(0, members->getViewSize().height - members->getContentSize().height*members->getScaleY()));
		}
		return;
	}
	
#ifdef Macro_TestUseCCReViScrollViewFacade
	{
		const int iMaxNode = (int)m_pScrollViewFacade->getMaxDynamicControledItemViewsNum();
		int iCount = 0;
		float fOneItemHeight = 0.f;//�ȸ�
		float fOneItemWidth = 0.f;
		
		if (isDesOrder)
		{
			DiscipleDateCollect::DiscipleIDCollect::reverse_iterator itr = collect.rbegin();
			if(collect.rbegin() == collect.rend()){
				int fontWidth =members->getViewSize().width; 
				int fontHeight =members->getViewSize().height; 

				CCLabelBMFont* normalBMFontSingle = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
				normalBMFontSingle->setString(Language::Get()->getString("@noDiscipleToChange").c_str());
				normalBMFontSingle->setColor(ccBLACK);
				normalBMFontSingle->setScale(1);
				CCPoint pos = ccp(fontWidth/2+2,-fontHeight/2-2);
				normalBMFontSingle->setPosition(pos);
				membersRootNode->addChild(normalBMFontSingle);

				CCLabelBMFont* normalBMFontSingle2 = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
				normalBMFontSingle2->setString(Language::Get()->getString("@noDiscipleToChange").c_str());
				normalBMFontSingle2->setColor(ccGRAY);
				normalBMFontSingle2->setScale(1);
				CCPoint pos2 = ccp(fontWidth/2,-fontHeight/2);
				normalBMFontSingle2->setPosition(pos2);
				membersRootNode->addChild(normalBMFontSingle2);
			}
			while(itr != collect.rend())
			{
				//
				DiscipleChangeContentItemData* pItemData = new DiscipleChangeContentItemData();
				pItemData->m_iDiscipleID = *itr;
				pItemData->m_bSelected = false;
				pItemData->m_iIdx = iCount;
				//
				pItemData->m_ptPosition = ccp(0, fOneItemHeight*iCount);
				//
				DiscipleChangeContent* pItem = NULL;
				if (iCount < iMaxNode)
				{
					//
					pItem = new DiscipleChangeContent(*itr, this);
					pItem->initItemView();

					//pItem->refreshItemView(pItemData);//��ʼ��m_pScrollViewFacade->setDynamicItemsStartPosition����
					//
					if (fOneItemHeight < pItem->getContainerNode()->getContentSize().height)
						fOneItemHeight = pItem->getContainerNode()->getContentSize().height;
					if (fOneItemWidth < pItem->getContainerNode()->getContentSize().width)
						fOneItemWidth = pItem->getContainerNode()->getContentSize().width;
				}
				m_pScrollViewFacade->addItem(pItemData, pItem);
				//
				++itr;
				++iCount;
			}
		}
		else
		{
			DiscipleDateCollect::DiscipleIDCollect::iterator itr = collect.begin();
			while(itr != collect.end())
			{
				//
				DiscipleChangeContentItemData* pItemData = new DiscipleChangeContentItemData();
				pItemData->m_iDiscipleID = *itr;
				pItemData->m_bSelected = false;
				pItemData->m_iIdx = iCount;
				//
				pItemData->m_ptPosition = ccp(0, fOneItemHeight*iCount);
				//
				DiscipleChangeContent* pItem = NULL;
				if (iCount < iMaxNode)
				{
					//
					pItem = new DiscipleChangeContent(*itr, this);
					pItem->initItemView();

					//pItem->refreshItemView(pItemData);//��ʼ��m_pScrollViewFacade->setDynamicItemsStartPosition����
					//
					if (fOneItemHeight < pItem->getContainerNode()->getContentSize().height)
						fOneItemHeight = pItem->getContainerNode()->getContentSize().height;
					if (fOneItemWidth < pItem->getContainerNode()->getContentSize().width)
						fOneItemWidth = pItem->getContainerNode()->getContentSize().width;
				}
				m_pScrollViewFacade->addItem(pItemData, pItem);
				//
				++itr;
				++iCount;
			}
		}
		//
		CCSize size = CCSize(fOneItemWidth, fOneItemHeight*iCount);
		members->setContentSize(size);
		/*
			ע��ScrollView������ܿص�DynamicItems����������Items
			ScrollViewê��(0.f,0.f)λ�����½�
			height������������
			width������������
			��������˳���ܵߵ�����˼�ǣ�������ӵ���ʾ�������������Ͻ�
		*/
		members->setContentOffset(ccp(0, members->getViewSize().height - members->getContentSize().height*members->getScaleY()));
		m_pScrollViewFacade->setDynamicItemsStartPosition(iCount-1);
		{
			//m_pScrollViewFacade->setDynamicItemsStartPosition(0);
		}
		//
	}
#else
	//DiscipleDateCollect::DiscipleIDCollect collect = DiscipleDateCollect::Get()->getDiscipleCollection(DiscipleFilter_Change);
	DiscipleDateCollect::DiscipleIDCollect::iterator itr = collect.begin(); 
	if(itr == collect.end()){
		int fontWidth =members->getViewSize().width; 
		int fontHeight =members->getViewSize().height; 

		CCLabelBMFont* normalBMFontSingle = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
		normalBMFontSingle->setString(Language::Get()->getString("@noDiscipleToChange").c_str());
		normalBMFontSingle->setColor(ccBLACK);
		normalBMFontSingle->setScale(1);
		CCPoint pos = ccp(fontWidth/2+2,-fontHeight/2-2);
		normalBMFontSingle->setPosition(pos);
		membersRootNode->addChild(normalBMFontSingle);

		CCLabelBMFont* normalBMFontSingle2 = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
		normalBMFontSingle2->setString(Language::Get()->getString("@noDiscipleToChange").c_str());
		normalBMFontSingle2->setColor(ccGRAY);
		normalBMFontSingle2->setScale(1);
		CCPoint pos2 = ccp(fontWidth/2,-fontHeight/2);
		normalBMFontSingle2->setPosition(pos2);
		membersRootNode->addChild(normalBMFontSingle2);
	}
	for(int i = collect.size() - 1; itr != collect.end(); ++itr, --i)
	{
		DiscipleChangeContent * item = new DiscipleChangeContent((*itr), this);
		item->init();
		//addItem(item);
		mContentList.push_back(item);
		membersRootNode->addChild(item->getContainerNode());
		CCPoint pos = ccp(0,item->getContainerNode()->getContentSize().height*i);
		item->getContainerNode()->setPosition(pos);
		CCSize size = CCSize(item->getContainerNode()->getContentSize().width, item->getContainerNode()->getContentSize().height*mContentList.size());
		members->setContentSize(size);
		members->setContentOffset(ccp(0,members->getViewSize().height - members->getContentSize().height*members->getScaleY()));
	}
#endif
}

// void DiscipleChangePage::addItem( ContentBase* item )
// {
// 	mContentList.push_back(item);
// 	membersRootNode->addChild(item->getContainerNode());
// 	CCPoint pos = ccp(0,item->getContainerNode()->getContentSize().height*(mContentList.size()-1));
// 	item->getContainerNode()->setPosition(pos);
// 	CCSize size = CCSize(item->getContainerNode()->getContentSize().width, item->getContainerNode()->getContentSize().height*mContentList.size());
// 	//membersRootNode->setContentSize(size);
// 	members->setContentSize(size);
// 	members->setContentOffset(ccp(0,members->minContainerOffset().y));
// }

void DiscipleChangePage::rebuildAllItem( void )
{
	mCurSellectedContent = NULL;//rebuild ������ܱ�����Ҳ�����ָ�
	clearAllItem();
	buildItem();
}

void DiscipleChangePage::clearAllItem( void )
{
#ifdef Macro_TestUseCCReViScrollViewFacade
	m_pScrollViewFacade->clearAllItems();
	m_curSelectedItemData = NULL;
#endif
	ContentList::iterator itr = mContentList.begin();
	while(itr != mContentList.end())
	{
		delete (*itr);
		++itr;
	}
	ContentList list;
	mContentList.swap(list);
	membersRootNode->removeAllChildren();
}

void DiscipleChangePage::refreshAllItem( void )
{
	ContentList::iterator itr = mContentList.begin();
	while(itr != mContentList.end())
	{
		(*itr)->refreshContent();
		++itr;
	}
}

void DiscipleChangePage::removeItem( ContentBase* item )
{
	ContentList::iterator itr = mContentList.begin();
	while(itr != mContentList.end())
	{
		if((*itr) == item)
		{
			membersRootNode->removeChild(item->getContainerNode());
			delete item;
			mContentList.erase(itr);
		}
		++itr;
	}
}

void DiscipleChangePage::reOrderAllItem()
{
#ifdef Macro_TestUseCCReViScrollViewFacade
	this->rebuildAllItem();
	return;
#endif
	membersRootNode->removeAllChildren();
	if(isDesOrder)
	{
		ContentList::iterator itr = mContentList.begin(); 
		for(int i = 0; itr != mContentList.end(); ++itr,++i)
		{
			ContentBase * item = *itr;
			membersRootNode->addChild(item->getContainerNode());
			CCPoint pos = ccp(0,item->getContainerNode()->getContentSize().height * i);
			item->getContainerNode()->setPosition(pos);
			CCSize size = CCSize(item->getContainerNode()->getContentSize().width, item->getContainerNode()->getContentSize().height * (i+1));
			members->setContentSize(size);
			members->setContentOffset(ccp(0,members->minContainerOffset().y));
		}
	}
	else
	{
		ContentList::reverse_iterator itr = mContentList.rbegin(); 
		for(int i = 0; itr != mContentList.rend(); ++itr,++i)
		{
			ContentBase * item = *itr;
			membersRootNode->addChild(item->getContainerNode());
			CCPoint pos = ccp(0,item->getContainerNode()->getContentSize().height * i);
			item->getContainerNode()->setPosition(pos);
			CCSize size = CCSize(item->getContainerNode()->getContentSize().width, item->getContainerNode()->getContentSize().height * (i+1));
			members->setContentSize(size);
			members->setContentOffset(ccp(0,members->minContainerOffset().y));
		}
	}
}

void DiscipleChangePage::onMenuItemAction( const std::string& itemName, cocos2d::CCObject* sender )
{
	if(itemName=="onConfirm")
	{
#ifdef Macro_TestUseCCReViScrollViewFacade
		if(m_curSelectedItemData == NULL)
#else
		if(mCurSellectedContent == NULL)
#endif
		{
			MsgMainFrameChangePage msg;
			msg.pageName = "TeamPage";
			MessageManager::Get()->sendMessage(&msg);
		}
		else
		{
			if(confirmFlag)
			{
				bool isNeedConfirm=false;
				unsigned int selectedDiscipleID = 0;
#ifdef Macro_TestUseCCReViScrollViewFacade
				selectedDiscipleID = m_curSelectedItemData->m_iDiscipleID;
#else
				selectedDiscipleID = mCurSellectedContent->getContentID();
#endif
				Disciple disciple(selectedDiscipleID);
				Skill defaultSkill(disciple.skill1());
				const UserBattleInfo* battleInfo=ServerDateManager::Get()->getUserBattleInfo(BlackBoard::Get()->CurBattlePosition);
				if(battleInfo->skill1!=0)
				{
					Skill skill(battleInfo->skill1);
					if(skill.itemID()==defaultSkill.itemID())
					{
						isNeedConfirm=true;
					}
				}
				if(battleInfo->skill2!=0)
				{
					Skill skill(battleInfo->skill2);
					if(skill.itemID()==defaultSkill.itemID())
					{
						isNeedConfirm=true;
					}
				}
				if(isNeedConfirm)
				{
					std::string key="changeDiscipleConfirmKey";
					if(HAS_V(key))
					{
						SET_V(key,selectedDiscipleID);
					}
					else
					{
						ADD_V(key,selectedDiscipleID);
					}
					POP_BOX(ChangeDiscipleConfirm);
				}
				else
				{
					OPChangeDisciple changeDisciple;
					changeDisciple.set_discipleid( selectedDiscipleID );
					changeDisciple.set_position( BlackBoard::Get()->CurBattlePosition );
					PacketManager::Get()->sendPakcet(OPCODE_CHANGE_DISCIPLE_C,&changeDisciple);
					confirmFlag = false;
				}
			}
		}
	}
	else if(itemName=="onOrderByDesc")
	{
		isDesOrder = !isDesOrder;
		reOrderAllItem();
		refreshPage();
	}
}

void DiscipleChangePage::onMenuItemAction( const std::string& itemName, cocos2d::CCObject* sender, int tag )
{
	if(itemName=="onFunciton")
	{
		MsgMainFrameChangePage msg;
		msg.pageName = "MarketPage";
		MessageManager::Get()->sendMessage(&msg);
	}
	else
	{
#ifdef Macro_TestUseCCReViScrollViewFacade
		cocos2d::extension::CCReViSvItemNodeFacade* node = m_pScrollViewFacade->findItemNodeByIndex(tag);
		if(node!=NULL)
		{
			DiscipleChangeContent* content = dynamic_cast<DiscipleChangeContent* >(node);
			if(content)
			{
				setSellectedContent(content);
			}
		}
#else
		if(!mContentList.empty() && mContentList.size()>tag && tag>=0)
		{
			ContentBase * cont = mContentList[tag];
			if(cont)
			{
				DiscipleChangeContent* content = dynamic_cast<DiscipleChangeContent*>(cont);
				if(content)
				{
					setSellectedContent(content);
				}
			}
		}
#endif
	}
	
}

void DiscipleChangePage::setSellectedContent( DiscipleChangeContent* member )
{
	if(mCurSellectedContent)
	{
		mCurSellectedContent->m_pItemData->m_bSelected = false;
		mCurSellectedContent->setSellect(false);
	}

	if(mCurSellectedContent != member)
	{
		mCurSellectedContent = member;
		mCurSellectedContent->m_pItemData->m_bSelected = true;
		mCurSellectedContent->setSellect(true);
	}
	else
	{
		mCurSellectedContent = NULL;
	}
}

#ifdef Macro_TestUseCCReViScrollViewFacade
// [haizei] facade 版：选中落在数据对象上，视图复用/滚动后仍然正确
void DiscipleChangePage::setSellectedContent( DiscipleChangeContentItemData* member )
{
	if (m_curSelectedItemData)
	{
		m_curSelectedItemData->m_bSelected = false;
		//之前选中的行如果还在某个复用视图上，把高亮撤掉
		DiscipleChangeContent* pItemView = (DiscipleChangeContent*)m_pScrollViewFacade->findItemNodeByItemData(m_curSelectedItemData);
		if (pItemView)
			pItemView->setSellect(false);
	}

	if(m_curSelectedItemData != member)
	{
		m_curSelectedItemData = member;
		member->m_bSelected = true;
	}
	else
	{
		m_curSelectedItemData = NULL;
	}
}
#endif

void DiscipleChangePage::refreshPage( void )
{
	CCLabelBMFont* funcLable=dynamic_cast<CCLabelBMFont* >(getVariable("mFuncLable"));
	if(funcLable)
	{
		if(isDesOrder)
			funcLable->setString(Language::Get()->getString("@OrderByAsce").c_str());
		else
			funcLable->setString(Language::Get()->getString("@OrderByDesc").c_str());
	}
}
