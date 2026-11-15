#include "inputBox.h"


/******************************************************/
/*              InputBox.cpp                          */
/******************************************************/
#include <windows.h>

int WINAPI WndProc(HWND hWnd,
	UINT uMsg,
	WPARAM wParam,
	LPARAM lParam);
BOOL _InitVar();
HWND _CreateWindow(HINSTANCE hInst);
int _Run(HWND hWnd);

HINSTANCE _hInstance;
wchar_t *_lpWndMsg;
wchar_t *_lpWndTitle;
wchar_t *_lpDefValue;
int _xPos;
int _yPos;
wchar_t *_lpHelpFile;
int _nHelpIndex;
HWND _hParent;
HWND _hDesktop;
HWND _hEdit, _hBtnOk, _hBtnCancel, _hBtnHelp;
HWND _hMsgText;
RECT _st_rcDesktop;
RECT _st_rcWnd;
HFONT _hWndFont;
wchar_t _szBuffer[256];
wchar_t *_lpWndFontName = L"宋体";
UINT _nMaxLine = 255;
UINT _nEditStyle = WS_BORDER | WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL | ES_AUTOVSCROLL;



BOOL _InitInputBox(HWND hParent)
{
	if (!hParent)
		return FALSE;
	_hParent = hParent;
	if (!_hInstance)
		return _InitVar();
	return TRUE;
}

BOOL _InitVar()
{
	_hInstance = ::GetModuleHandle(NULL);
	_hDesktop = ::GetDesktopWindow();
	::GetWindowRect(_hDesktop,&_st_rcDesktop);
	if (!_xPos)
		_xPos = (_st_rcDesktop.right - 365) / 2;
	if (!_yPos)
		_yPos = (_st_rcDesktop.bottom - 130) / 2;
	return TRUE;
}

int WINAPI WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	HDC hWndDc;
	WORD uBtnID;
	switch(uMsg)
	{
	case WM_DESTROY:
		if (_hWndFont)
			::DeleteObject(_hWndFont);
		::PostQuitMessage(0);
		break;
	case WM_CREATE:
		_hMsgText = ::CreateWindowEx(0,
			L"Static",
			_lpWndMsg,
			WS_CHILD | WS_VISIBLE,
			5,
			5,
			275,
			70,
			hWnd,
			(HMENU)1000,
			_hInstance,
			0);
		_hBtnOk = ::CreateWindowEx(0,
			L"Button",
			L"确定(&K)",
			WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
			285,
			5,
			65,
			20,
			hWnd,
			(HMENU)IDOK,
			_hInstance,
			0);
		_hBtnCancel = ::CreateWindowEx(0,
			L"Button",
			L"取消(&C)",
			WS_CHILD | WS_VISIBLE,
			285,
			30,
			65,
			20,
			hWnd,
			(HMENU)IDCANCEL,
			_hInstance,
			0);
		_hBtnHelp = ::CreateWindowEx(0,
			L"Button",
			L"帮助(&H)",
			WS_CHILD | WS_VISIBLE,
			285,
			55,
			65,
			20,
			hWnd,
			(HMENU)IDHELP,
			_hInstance,
			0);
		_hEdit = ::CreateWindowEx(WS_EX_CLIENTEDGE,
			L"Edit",
			_lpDefValue,
			_nEditStyle,
			5,
			80,
			350,
			20,
			hWnd,
			(HMENU)2000,
			_hInstance,
			0);
		::SendMessage(_hEdit,EM_SETLIMITTEXT,_nMaxLine,0);
		_hWndFont = ::CreateFont(12,
			6,
			0,
			0,
			12,
			0,
			0,
			0,
			GB2312_CHARSET,
			OUT_DEFAULT_PRECIS,
			CLIP_DEFAULT_PRECIS,
			DEFAULT_QUALITY,
			DEFAULT_PITCH,
			_lpWndFontName);
		if (!::lstrlen(_lpHelpFile))
			ShowWindow(_hBtnHelp,SW_HIDE);
		hWndDc = ::GetDC(hWnd);
		::SelectObject(hWndDc,_hWndFont);
		::ReleaseDC(hWnd,hWndDc);
		::SendDlgItemMessage(hWnd,1000,WM_SETFONT,(WPARAM)_hWndFont,0);
		::SendDlgItemMessage(hWnd,2000,WM_SETFONT,(WPARAM)_hWndFont,0);
		::SendDlgItemMessage(hWnd,IDOK,WM_SETFONT,(WPARAM)_hWndFont,0);
		::SendDlgItemMessage(hWnd,IDCANCEL,WM_SETFONT,(WPARAM)_hWndFont,0);
		::SendDlgItemMessage(hWnd,IDHELP,WM_SETFONT,(WPARAM)_hWndFont,0);
		break;
	case WM_KEYDOWN:
		if (wParam == VK_RETURN)
			::SendMessage(hWnd,WM_COMMAND,IDOK,0);
		break;
	case WM_SETFOCUS:
		::SetFocus(_hEdit);
		break;
	case WM_COMMAND:
		uBtnID = LOWORD(wParam);
		switch(uBtnID)
		{
		case IDOK:
			::GetDlgItemText(hWnd,2000,_szBuffer,256);
			::DestroyWindow(hWnd);
			break;
		case IDCANCEL:
			::DestroyWindow(hWnd);
			break;
		case IDHELP:
			::WinHelp(hWnd,_lpHelpFile,HELP_INDEX,_nHelpIndex);
			break;
		};
		break;
	default:
		return ::DefWindowProc(hWnd, uMsg, wParam, lParam);
	}
	return (TRUE);
}

HWND _CreateWindow(HINSTANCE hInst)
{
	WNDCLASSEX st_WndClass;
	HWND hWnd;
	::RtlZeroMemory(&st_WndClass,sizeof(st_WndClass));
	st_WndClass.cbSize        = sizeof(st_WndClass);
	st_WndClass.hInstance     = hInst;
	st_WndClass.hbrBackground = (HBRUSH)COLOR_BTNSHADOW;
	st_WndClass.hCursor       = LoadCursor(0, IDC_ARROW);
	st_WndClass.hIcon         = LoadIcon(0, IDI_APPLICATION);
	st_WndClass.hIconSm       = st_WndClass.hIcon;
	st_WndClass.lpfnWndProc   = (WNDPROC)&WndProc;
	st_WndClass.lpszClassName = L"InputBox_Class";
	st_WndClass.style         = CS_HREDRAW | CS_VREDRAW;
	::RegisterClassEx(&st_WndClass);
	hWnd = ::CreateWindowEx(0,
		L"InputBox_Class",
		_lpWndTitle,
		WS_DLGFRAME | WS_SYSMENU | WS_VISIBLE,
		_xPos,
		_yPos,
		365,
		130,
		_hParent,
		0,
		hInst,
		0);
	return hWnd;
}

int _Run(HWND hWnd)
{
	MSG st_Msg;
	if (!hWnd)
		return 0;
	::ShowWindow(hWnd,SW_SHOW);
	::UpdateWindow(hWnd);
	while(::GetMessage(&st_Msg,0,0,0))
	{
		if (st_Msg.message == WM_KEYDOWN)
		{
			if (st_Msg.wParam == VK_RETURN)
				::SendMessage(hWnd,st_Msg.message,st_Msg.wParam,st_Msg.wParam);
		}
		::TranslateMessage (&st_Msg) ;
		::DispatchMessage (&st_Msg) ;
	}
	return st_Msg.wParam;
}

wchar_t *_InputBox(wchar_t *lpWndMsg,
	wchar_t *lpWndTitle,
	wchar_t *lpDefValue,
	int xPos,
	int yPos,
	wchar_t *lpHelpFile,
	int nHelpIndex)
{
	_lpWndMsg = lpWndMsg;
	_lpWndTitle = lpWndTitle;
	_lpDefValue = lpDefValue;
	_xPos = xPos;
	_yPos = yPos;
	_lpHelpFile = lpHelpFile;
	_nHelpIndex = nHelpIndex;
	if (!_hInstance)
		_InitVar();
	_Run(_CreateWindow(_hInstance));
	return _szBuffer;
}

void _SetNumber(BOOL fIsNumber)
{
	if (fIsNumber)
		_nEditStyle |= ES_NUMBER;
}
void _SetPassword(BOOL fIsPassword)
{
	if (fIsPassword)
		_nEditStyle |= ES_PASSWORD;
	else
		_nEditStyle &= ~ES_PASSWORD;
}
void _SetLowerCase(BOOL fIsLowerCase)
{
	if (fIsLowerCase)
		_nEditStyle |= ES_LOWERCASE;
}
void _SetUpperCase(BOOL fIsUpperCase)
{
	if (fIsUpperCase)
		_nEditStyle |= ES_UPPERCASE;
}
void _SetMaxLine(unsigned int nLineSize)
{
	if (nLineSize)
		if (nLineSize < _nMaxLine)
			_nMaxLine = nLineSize;
}

/* ============================================================
 * 本地版新增：合并登录窗口（账号 + 密码 + 登录/注册/退出 单窗口）
 * 中文文字用 \x 转义，避免源码编码问题：
 * 账号=\x8D26\x53F7  密码=\x5BC6\x7801  登录=\x767B\x5F55
 * 注册=\x6CE8\x518C  退出=\x9000\x51FA
 * 新账号登录后自动注册=\x65B0\x8D26\x53F7\x767B\x5F55\x540E\x81EA\x52A8\x6CE8\x518C
 * ============================================================ */
static wchar_t *_lpAccountBuf = 0;
static wchar_t *_lpPasswordBuf = 0;
static int _loginResult = 0;
static HFONT _hLoginFont = 0;

#define LB_ID_ACCOUNT   3001
#define LB_ID_PASSWORD  3003
#define LB_ID_REGISTER  3101

static void _LoginReadFields(HWND hWnd)
{
	::GetDlgItemText(hWnd, LB_ID_ACCOUNT, _lpAccountBuf, 64);
	::GetDlgItemText(hWnd, LB_ID_PASSWORD, _lpPasswordBuf, 64);
}

static int WINAPI LoginWndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch (uMsg)
	{
	case WM_CREATE:
	{
		::CreateWindowEx(0, L"Static", L"\x8D26\x53F7:",
			WS_CHILD | WS_VISIBLE, 10, 16, 45, 18, hWnd, (HMENU)3000, _hInstance, 0);
		::CreateWindowEx(WS_EX_CLIENTEDGE, L"Edit", L"",
			WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, 60, 14, 185, 20, hWnd, (HMENU)LB_ID_ACCOUNT, _hInstance, 0);
		::CreateWindowEx(0, L"Static", L"\x5BC6\x7801:",
			WS_CHILD | WS_VISIBLE, 10, 48, 45, 18, hWnd, (HMENU)3002, _hInstance, 0);
		::CreateWindowEx(WS_EX_CLIENTEDGE, L"Edit", L"",
			WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL | ES_PASSWORD, 60, 46, 185, 20, hWnd, (HMENU)LB_ID_PASSWORD, _hInstance, 0);
		::CreateWindowEx(0, L"Button", L"\x767B\x5F55",
			WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON, 258, 14, 90, 24, hWnd, (HMENU)IDOK, _hInstance, 0);
		::CreateWindowEx(0, L"Button", L"\x6CE8\x518C",
			WS_CHILD | WS_VISIBLE, 258, 46, 90, 24, hWnd, (HMENU)LB_ID_REGISTER, _hInstance, 0);
		::CreateWindowEx(0, L"Static", L"\x65B0\x8D26\x53F7\x767B\x5F55\x540E\x81EA\x52A8\x6CE8\x518C",
			WS_CHILD | WS_VISIBLE, 10, 90, 220, 18, hWnd, (HMENU)3004, _hInstance, 0);
		::CreateWindowEx(0, L"Button", L"\x9000\x51FA",
			WS_CHILD | WS_VISIBLE, 100, 112, 150, 24, hWnd, (HMENU)IDCANCEL, _hInstance, 0);

		_hLoginFont = ::CreateFont(14, 7, 0, 0, 12, 0, 0, 0, GB2312_CHARSET,
			OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH, L"\x5B8B\x4F53");
		for (int id = 3000; id <= 3004; ++id)
			::SendDlgItemMessage(hWnd, id, WM_SETFONT, (WPARAM)_hLoginFont, 0);
		::SendDlgItemMessage(hWnd, IDOK, WM_SETFONT, (WPARAM)_hLoginFont, 0);
		::SendDlgItemMessage(hWnd, LB_ID_REGISTER, WM_SETFONT, (WPARAM)_hLoginFont, 0);
		::SendDlgItemMessage(hWnd, IDCANCEL, WM_SETFONT, (WPARAM)_hLoginFont, 0);
		::SetFocus(::GetDlgItem(hWnd, LB_ID_ACCOUNT));
		break;
	}
	case WM_COMMAND:
	{
		switch (LOWORD(wParam))
		{
		case IDOK:
			_LoginReadFields(hWnd);
			_loginResult = 1;
			::DestroyWindow(hWnd);
			break;
		case LB_ID_REGISTER:
			_LoginReadFields(hWnd);
			_loginResult = 2;
			::DestroyWindow(hWnd);
			break;
		case IDCANCEL:
			_loginResult = 0;
			::DestroyWindow(hWnd);
			break;
		}
		break;
	}
	case WM_DESTROY:
		if (_hLoginFont) { ::DeleteObject(_hLoginFont); _hLoginFont = 0; }
		::PostQuitMessage(0);
		break;
	default:
		return ::DefWindowProc(hWnd, uMsg, wParam, lParam);
	}
	return 0;
}

int _LoginBox(wchar_t *lpWndTitle, wchar_t *outAccount, wchar_t *outPassword)
{
	_lpAccountBuf = outAccount;
	_lpPasswordBuf = outPassword;
	outAccount[0] = 0;
	outPassword[0] = 0;
	_loginResult = 0;
	if (!_hInstance)
		_InitVar();

	WNDCLASSEX wc;
	::RtlZeroMemory(&wc, sizeof(wc));
	wc.cbSize = sizeof(wc);
	wc.hInstance = _hInstance;
	wc.hbrBackground = (HBRUSH)COLOR_WINDOW;
	wc.hCursor = LoadCursor(0, IDC_ARROW);
	wc.hIcon = LoadIcon(0, IDI_APPLICATION);
	wc.hIconSm = wc.hIcon;
	wc.lpfnWndProc = (WNDPROC)&LoginWndProc;
	wc.lpszClassName = L"LoginBox_Class";
	wc.style = CS_HREDRAW | CS_VREDRAW;
	::RegisterClassEx(&wc);

	int x = (_st_rcDesktop.right - 365) / 2;
	int y = (_st_rcDesktop.bottom - 175) / 2;
	HWND hWnd = ::CreateWindowEx(0,
		L"LoginBox_Class",
		lpWndTitle ? lpWndTitle : L"\x767B\x5F55",
		WS_DLGFRAME | WS_SYSMENU | WS_VISIBLE,
		x, y, 365, 175,
		0, 0, _hInstance, 0);
	::ShowWindow(hWnd, SW_SHOW);
	::UpdateWindow(hWnd);

	MSG msg;
	while (::GetMessage(&msg, 0, 0, 0))
	{
		if (msg.message == WM_KEYDOWN && msg.wParam == VK_RETURN)
			::SendMessage(hWnd, WM_COMMAND, IDOK, 0);
		::TranslateMessage(&msg);
		::DispatchMessage(&msg);
	}
	return _loginResult;
} 