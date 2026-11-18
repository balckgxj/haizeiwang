
#include "stdafx.h"

#include "SkillChangePage.h"
#include "ServerDateManager.h"
#include "StringConverter.h"
#include "DataTableManager.h"
#include "BlackBoard.h"
#include "Skill.h"
#include "Disciple.h"
#include "MessageBoxPage.h"

REGISTER_PAGE("SkillChangePage",SkillChangePage);
USING_NS_CC;

void SkillChangeContent::refreshContent( void )
{
	mSelect = dynamic_cast<CCMenuItemImage* >(mContentContainer->getVariable("mSelect"));
	//mSelect->unselected();

	mSelect->setNormalImage(::getContentUnselectedSpirte("Normal"));
	mSelect->setSelectedImage(::getContentUnselectedSpirte("Normal"));

	Skill skill(mID);

	CCSprite* prop=dynamic_cast<CCSprite* >(mContentContainer->getVariable("mSkillPic"));
	if(prop)
	{
		prop->initWithFile(skill.iconPic().c_str());
	}
	CCMenuItemImage* frame=dynamic_cast<CCMenuItemImage* >(mContentContainer->getVariable("mQualityFrame"));
	if(frame)
	{
		frame->setNormalImage(skill.getFrameNormalSpirte());
		frame->setSelectedImage(skill.getFrameSelectedSpirte());
	}
	CCSprite* skillAtkTypePic=dynamic_cast<CCSprite* >(mContentContainer->getVariable("mSkillBuffPic"));
	if(skillAtkTypePic)
	{
		skillAtkTypePic->initWithFile(skill.getSkillAtkTypePic().c_str());
	}
	CCSprite* skillQuality=dynamic_cast<CCSprite* >(mContentContainer->getVariable("mSkillQuality"));
	if(skillQuality)
	{
		skillQuality->initWithFile(skill.getQualityImageFile().c_str());
	}
	CCLabelBMFont* skillName = dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mSkillName"));
	if(skillName)
	{
		skillName->setString(skill.name().c_str());
#if defined(Macro_TestUseCCReViScrollViewFacade) && defined(_DEBUG)
		std::string strTmp = StringConverter::toString(this->m_iIdx) + Language::Get()->getString(skill.name());
		skillName->setString(strTmp.c_str());
#endif
	}
	CCLabelBMFont* skillLevel=dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mSkillLevel"));
	if(skillLevel)
	{
		skillLevel->setString(StringConverter::toString(skill.level()).c_str());
	}
	CCLabelBMFont* attackValue = dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mBuffValue"));
	if(attackValue)
	{
		attackValue->setString(skill.quantityStr().c_str());
	}

	CCSprite* mMPInBattlePic=dynamic_cast<CCSprite* >(mContentContainer->getVariable("mMPInBattlePic"));
	CCLabelBMFont* skillCarriedBy=dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mSkillCarriedBy"));
	if(skillCarriedBy)
	{
		carriedByDiscipleName = skill.getSkillCarriedBy();
		if(carriedByDiscipleName!="")
		{
			char buff[128];
			std::string s= Language::Get()->getString("@CarriedBy");
			sprintf(buff,s.c_str(),carriedByDiscipleName.c_str());
			skillCarriedBy->setString(buff);
			mMPInBattlePic->setVisible(true);
		}
		else
		{
			skillCarriedBy->setString("");
			mMPInBattlePic->setVisible(false);
		}
	}
	CCLabelBMFont* skillValue=dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mSkillValue"));
	if(skillValue)
	{
		skillValue->setString(StringConverter::toString(skill.getSkillValue()).c_str());
	}
	CCLabelBMFont* skillAtkType = dynamic_cast<CCLabelBMFont* >(mContentContainer->getVariable("mSkillAtkType"));
	if(skillAtkType)
	{
		skillAtkType->setString(skill.getSkillAtkType().c_str());
	}
#ifdef Macro_TestUseCCReViScrollViewFacade
	setSellect(m_pItemData->m_bSelected);
#endif
}

void SkillChangeContent::onMenuItemAction( const std::string& itemName, cocos2d::CCObject* sender, int tag )
{
	if(itemName=="onSelected")
	{
#ifdef Macro_TestUseCCReViScrollViewFacade
		// [haizei] 选中记录在数据对象上；视图复用后 this 对应的行会变
		if(m_pItemData)
		{
			mOwnner->setSellectedContent(m_pItemData);
			setSellect(m_pItemData->m_bSelected);
		}
#else
		mOwnner->setSellectedContent(this);
#endif
		if(mSelect && carriedByDiscipleName!="" && mSelect->isSelected())
		{
			char buff[128];
			std::string s= Language::Get()->getString("@AlreadyUsedBy");
			sprintf(buff,s.c_str(),carriedByDiscipleName.c_str());
			MSG_BOX(buff);
		}
	}
}

void SkillChangeContent::setSellect( bool sellect )
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

#ifdef Macro_TestUseCCReViScrollViewFacade

void SkillChangeContent::initItemView()
{
	mContentContainer = CCBManager::Get()->createAndLoad(getCcbiFileName());
	mContentContainer->setListener(this);
	mContentContainer->retain();
	//
	this->m_pItemNode = mContentContainer;
}

void SkillChangeContent::refreshItemView( cocos2d::extension::CCReViSvItemData* pItem )
{
	SkillChangeContentItemData* pItemData = static_cast<SkillChangeContentItemData*>(pItem);
	if (pItemData)
	{
		this->m_pItemData = pItemData;
		this->mID = pItemData->m_iSkillID;
#ifdef _DEBUG
		this->m_iIdx = pItemData->m_iIdx;
#endif
		this->refreshContent();
	}
}

#endif

SkillChangePage::SkillChangePage(void)
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

SkillChangePage::~SkillChangePage(void)
{
}

void SkillChangePage::Enter( MainFrame* frame)
{
	// [haizei] 上下文保护：本页需要父流程（布阵/战斗）设置 CurBattlePosition 并提供战斗数据；
	// 直开时 getUserBattleInfo 返回空，SkillFilter_Change 解引用空战斗信息而崩溃。无数据则安全返回。
	if(!ServerDateManager::Get()->getUserBattleInfo(BlackBoard::Get()->CurBattlePosition)) return;
	isDesOrder=true;
	rebuildAllItem();
	mCurSellectedContent = NULL;
#ifdef Macro_TestUseCCReViScrollViewFacade
	m_curSelectedItemData = NULL;
#endif
	refreshPage();
}

void SkillChangePage::Exit( MainFrame* frame)
{
	clearAllItem();
#ifdef Macro_TestUseCCReViScrollViewFacade
	delete m_pScrollViewFacade;
	m_pScrollViewFacade = NULL;
#endif
}

void SkillChangePage::Execute( MainFrame* )
{

}

void SkillChangePage::load( void )
{
	loadCcbiFile("SkillsChanged.ccbi");
	members =  dynamic_cast<cocos2d::extension::CCScrollView*>(getVariable("mChangeContent"));
	membersRootNode = members->getContainer();

#ifdef Macro_TestUseCCReViScrollViewFacade
	m_pScrollViewFacade = new cocos2d::extension::CCReViScrollViewFacade(members);
	m_pScrollViewFacade->init(Macro_FixedViewItemsMaxNum,Macro_FixedViewItemsMaxNum);
#endif

}

bool SkillFilter_Change(unsigned int id)
{
	const UserBattleInfo* info = ServerDateManager::Get()->getUserBattleInfo(BlackBoard::Get()->CurBattlePosition);
	Skill skill(id);

	//���츳����
	if(skill.isBornSkill())
		return false;

	//���츳����һ��
	Skill bornSkill(Disciple(info->discipleId).skill1());
	if(skill.itemID() == bornSkill.itemID() )
	{
		return false;
	}

	unsigned int CurChangeSkillID = 0;
	if(BlackBoard::Get()->CurChangeSkillPosition == 1)
	{
		CurChangeSkillID = info->skill1;
		//�ͼ��ܲ�2�ļ���һ��
		if( info->skill2 && Skill(info->skill2).itemID() == skill.itemID() )
			return false;
	}
	else if(BlackBoard::Get()->CurChangeSkillPosition == 2)
	{
		CurChangeSkillID = info->skill2;
		//�ͼ��ܲ�1�ļ���һ��
		if( info->skill1 && Skill(info->skill1).itemID() == skill.itemID() )
			return false;
	}

	if(CurChangeSkillID != 0)
	{
		//�͵�ǰ����һ�������Ҽ���Ҳһ��
		Skill skillNow(CurChangeSkillID);
		if(skillNow.itemID() == skill.itemID() && skill.level() == skillNow.level())
		{
			return false;
		}
	}
	
	return true;
}

void SkillChangePage::buildItem( void )
{
#ifdef Macro_TestUseCCReViScrollViewFacade
	{
		const int iMaxNode = (int)m_pScrollViewFacade->getMaxDynamicControledItemViewsNum();
		int iCount = 0;
		float fOneItemHeight = 0.f;//�ȸ�
		float fOneItemWidth = 0.f;
		SkillDateCollect::SkillIDCollect collect = SkillDateCollect::Get()->getSkillCollection(SkillFilter_Change);
		if(collect.rbegin() == collect.rend()){
			int fontWidth =members->getViewSize().width; 
			int fontHeight =members->getViewSize().height; 

			CCLabelBMFont* normalBMFontSingle = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
			normalBMFontSingle->setString(Language::Get()->getString("@noSkillToChange").c_str());
			normalBMFontSingle->setColor(ccBLACK);
			normalBMFontSingle->setScale(1);
			CCPoint pos = ccp(fontWidth/2+2,-fontHeight/2-2);
			normalBMFontSingle->setPosition(pos);
			membersRootNode->addChild(normalBMFontSingle);

			CCLabelBMFont* normalBMFontSingle2 = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
			normalBMFontSingle2->setString(Language::Get()->getString("@noSkillToChange").c_str());
			normalBMFontSingle2->setColor(ccGRAY);
			normalBMFontSingle2->setScale(1);
			CCPoint pos2 = ccp(fontWidth/2,-fontHeight/2);
			normalBMFontSingle2->setPosition(pos2);
			membersRootNode->addChild(normalBMFontSingle2);

		}
		if (!isDesOrder)
		{
			SkillDateCollect::SkillIDCollect::reverse_iterator itr = collect.rbegin(); 
			while(itr != collect.rend())
			{
				//
				SkillChangeContentItemData* pItemData = new SkillChangeContentItemData();
				pItemData->m_iSkillID = *itr;
				pItemData->m_bSelected = false;
				pItemData->m_iIdx = iCount;
				//
				pItemData->m_ptPosition = ccp(0, fOneItemHeight*iCount);
				//
				SkillChangeContent* pItem = NULL;
				if (iCount < iMaxNode)
				{
					//
					pItem = new SkillChangeContent(*itr, this);
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
			SkillDateCollect::SkillIDCollect::iterator itr = collect.begin(); 
			while(itr != collect.end())
			{
				//
				SkillChangeContentItemData* pItemData = new SkillChangeContentItemData();
				pItemData->m_iSkillID = *itr;
				pItemData->m_bSelected = false;
				pItemData->m_iIdx = iCount;
				//
				pItemData->m_ptPosition = ccp(0, fOneItemHeight*iCount);
				//
				SkillChangeContent* pItem = NULL;
				if (iCount < iMaxNode)
				{
					//
					pItem = new SkillChangeContent(*itr, this);
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
	SkillDateCollect::SkillIDCollect collect = SkillDateCollect::Get()->getSkillCollection(SkillFilter_Change);
	SkillDateCollect::SkillIDCollect::iterator itr = collect.begin(); 
	if(itr == collect.end()){
		int fontWidth =members->getViewSize().width; 
		int fontHeight =members->getViewSize().height; 

		CCLabelBMFont* normalBMFontSingle = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
		normalBMFontSingle->setString(Language::Get()->getString("@noSkillToChange").c_str());
		normalBMFontSingle->setColor(ccBLACK);
		normalBMFontSingle->setScale(1);
		CCPoint pos = ccp(fontWidth/2+2,-fontHeight/2-2);
		normalBMFontSingle->setPosition(pos);
		membersRootNode->addChild(normalBMFontSingle);

		CCLabelBMFont* normalBMFontSingle2 = (CCLabelBMFont*)  cocos2d::createLabelBMFontCompat("T","Lang/heiOutline24.fnt",10);  
		normalBMFontSingle2->setString(Language::Get()->getString("@noSkillToChange").c_str());
		normalBMFontSingle2->setColor(ccGRAY);
		normalBMFontSingle2->setScale(1);
		CCPoint pos2 = ccp(fontWidth/2,-fontHeight/2);
		normalBMFontSingle2->setPosition(pos2);
		membersRootNode->addChild(normalBMFontSingle2);
	}
	for(; itr != collect.end(); ++itr)
	{
		SkillChangeContent * item = new SkillChangeContent((*itr), this);
		item->init();
		addItem(item);
	}
#endif
}

void SkillChangePage::addItem( ContentBase* item )
{
	mContentList.push_back(item);
	membersRootNode->addChild(item->getContainerNode());
	CCPoint pos = ccp(0,item->getContainerNode()->getContentSize().height*(mContentList.size()-1));
	item->getContainerNode()->setPosition(pos);
	CCSize size = CCSize(item->getContainerNode()->getContentSize().width, item->getContainerNode()->getContentSize().height*mContentList.size());
	//membersRootNode->setContentSize(size);
	members->setContentSize(size);
	members->setContentOffset(ccp(0,members->getViewSize().height - members->getContentSize().height*members->getScaleY()));
}

void SkillChangePage::rebuildAllItem( void )
{
	clearAllItem();
	buildItem();
}

void SkillChangePage::clearAllItem( void )
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
	// [haizei] 防御：节点可能尚未初始化（Enter 提前 return 时），切页 Exit 仍会走到这里。
	if(membersRootNode) membersRootNode->removeAllChildren();
	mCurSellectedContent = NULL;
}

void SkillChangePage::refreshAllItem( void )
{
	ContentList::iterator itr = mContentList.begin();
	while(itr != mContentList.end())
	{
		(*itr)->refreshContent();
		++itr;
	}
}

void SkillChangePage::removeItem( ContentBase* item )
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

void SkillChangePage::reOrderAllItem()
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
			members->setContentOffset(ccp(0,members->getViewSize().height - members->getContentSize().height*members->getScaleY()));
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
			members->setContentOffset(ccp(0,members->getViewSize().height - members->getContentSize().height*members->getScaleY()));
		}
	}
}

void SkillChangePage::onMenuItemAction( const std::string& itemName, cocos2d::CCObject* sender )
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
			OPChangeSkill changeSkill;
#ifdef Macro_TestUseCCReViScrollViewFacade
			changeSkill.set_newskillid( m_curSelectedItemData->m_iSkillID );
#else
			changeSkill.set_newskillid( mCurSellectedContent->getContentID() );
#endif
			changeSkill.set_battleposition(BlackBoard::Get()->CurBattlePosition);
			changeSkill.set_skillposition( BlackBoard::Get()->CurChangeSkillPosition );
			PacketManager::Get()->sendPakcet(OPCODE_CHANGE_SKILL_C,&changeSkill);
		}
	}
	else if(itemName=="onOrderByDesc")
	{
		isDesOrder = !isDesOrder;
		reOrderAllItem();
		refreshPage();
	}
}

void SkillChangePage::refreshPage( void )
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

void SkillChangePage::setSellectedContent( SkillChangeContent* member )
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
void SkillChangePage::setSellectedContent( SkillChangeContentItemData* member )
{
	if (m_curSelectedItemData)
	{
		m_curSelectedItemData->m_bSelected = false;
		SkillChangeContent* pItemView = (SkillChangeContent*)m_pScrollViewFacade->findItemNodeByItemData(m_curSelectedItemData);
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
