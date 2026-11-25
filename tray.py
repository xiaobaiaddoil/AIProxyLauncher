"""Pure-stdlib Windows system tray icon with native context menu (no-op on non-Windows)."""
from __future__ import annotations

from pathlib import Path
import sys
import threading

if sys.platform == "win32":
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    shell32 = ctypes.windll.shell32
    kernel32 = ctypes.windll.kernel32

    LRESULT = ctypes.c_ssize_t
    WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)

    WM_DESTROY = 0x0002
    WM_COMMAND = 0x0111
    WM_USER = 0x0400
    WM_TRAY = WM_USER + 20
    WM_LBUTTONUP = 0x0202
    WM_LBUTTONDBLCLK = 0x0203
    WM_RBUTTONUP = 0x0205

    NIM_ADD = 0x00000000
    NIM_MODIFY = 0x00000001
    NIM_DELETE = 0x00000002
    NIF_MESSAGE = 0x00000001
    NIF_ICON = 0x00000002
    NIF_TIP = 0x00000004

    IMAGE_ICON = 1
    LR_LOADFROMFILE = 0x00000010
    LR_DEFAULTSIZE = 0x00000040
    IDI_APPLICATION = 32512

    MF_STRING = 0x00000000
    MF_SEPARATOR = 0x00000800
    TPM_LEFTALIGN = 0x0000
    TPM_BOTTOMALIGN = 0x0020
    TPM_RIGHTBUTTON = 0x0002

    ID_SHOW = 1001
    ID_LAUNCH = 1002
    ID_CHECK = 1003
    ID_EXIT = 1004

    class WNDCLASSW(ctypes.Structure):
        _fields_ = [
            ("style", wintypes.UINT),
            ("lpfnWndProc", WNDPROC),
            ("cbClsExtra", ctypes.c_int),
            ("cbWndExtra", ctypes.c_int),
            ("hInstance", wintypes.HINSTANCE),
            ("hIcon", wintypes.HICON),
            ("hCursor", wintypes.HANDLE),
            ("hbrBackground", wintypes.HBRUSH),
            ("lpszMenuName", wintypes.LPCWSTR),
            ("lpszClassName", wintypes.LPCWSTR),
        ]

    class NOTIFYICONDATAW(ctypes.Structure):
        _fields_ = [
            ("cbSize", wintypes.DWORD),
            ("hWnd", wintypes.HWND),
            ("uID", wintypes.UINT),
            ("uFlags", wintypes.UINT),
            ("uCallbackMessage", wintypes.UINT),
            ("hIcon", wintypes.HICON),
            ("szTip", wintypes.WCHAR * 128),
        ]

    user32.DefWindowProcW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)
    user32.DefWindowProcW.restype = LRESULT
    user32.RegisterClassW.argtypes = (ctypes.POINTER(WNDCLASSW),)
    user32.RegisterClassW.restype = wintypes.ATOM
    user32.CreateWindowExW.argtypes = (
        wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
        ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
        wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID,
    )
    user32.CreateWindowExW.restype = wintypes.HWND
    user32.LoadImageW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR, wintypes.UINT, ctypes.c_int, ctypes.c_int, wintypes.UINT)
    user32.LoadImageW.restype = wintypes.HANDLE
    user32.LoadIconW.argtypes = (wintypes.HINSTANCE, wintypes.LPCWSTR)
    user32.LoadIconW.restype = wintypes.HICON
    user32.DestroyIcon.argtypes = (wintypes.HICON,)
    user32.DestroyWindow.argtypes = (wintypes.HWND,)
    user32.PostMessageW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)
    user32.PostQuitMessage.argtypes = (ctypes.c_int,)
    user32.GetMessageW.argtypes = (ctypes.POINTER(wintypes.MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT)
    user32.TranslateMessage.argtypes = (ctypes.POINTER(wintypes.MSG),)
    user32.DispatchMessageW.argtypes = (ctypes.POINTER(wintypes.MSG),)
    user32.CreatePopupMenu.restype = wintypes.HMENU
    user32.AppendMenuW.argtypes = (wintypes.HMENU, wintypes.UINT, wintypes.UINT, wintypes.LPCWSTR)
    user32.DestroyMenu.argtypes = (wintypes.HMENU,)
    user32.SetForegroundWindow.argtypes = (wintypes.HWND,)
    user32.GetCursorPos.argtypes = (ctypes.POINTER(wintypes.POINT),)
    user32.TrackPopupMenu.argtypes = (
        wintypes.HMENU, wintypes.UINT, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.HWND, wintypes.LPVOID,
    )
    shell32.Shell_NotifyIconW.argtypes = (wintypes.DWORD, ctypes.POINTER(NOTIFYICONDATAW))
    shell32.Shell_NotifyIconW.restype = wintypes.BOOL
    kernel32.GetModuleHandleW.argtypes = (wintypes.LPCWSTR,)
    kernel32.GetModuleHandleW.restype = wintypes.HMODULE


class SystemTray:
    """Dedicated-thread Windows tray icon so Tk's own event loop stays completely untouched."""

    supported = sys.platform == "win32"

    def __init__(self, tooltip: str, icon_path: Path | None, on_show, on_launch, on_check, on_exit):
        self._tooltip = tooltip[:120]
        self._icon_path = icon_path
        self._on_show = on_show
        self._on_launch = on_launch
        self._on_check = on_check
        self._on_exit = on_exit
        self._hwnd = None
        self._hicon = None
        self._owns_icon = False
        self._wndproc = None
        self._thread: threading.Thread | None = None
        self._ready = threading.Event()
        self._active = False

    def start(self) -> bool:
        if not self.supported or self._active:
            return self._active
        self._ready.clear()
        self._thread = threading.Thread(target=self._run, daemon=True, name="AIProxyTray")
        self._thread.start()
        self._ready.wait(timeout=2.0)
        return self._active

    def update_tooltip(self, tooltip: str) -> None:
        self._tooltip = tooltip[:120]
        if not self.supported or not self._active or not self._hwnd:
            return
        try:
            nid = NOTIFYICONDATAW()
            nid.cbSize = ctypes.sizeof(NOTIFYICONDATAW)
            nid.hWnd = self._hwnd
            nid.uID = 1
            nid.uFlags = NIF_TIP
            nid.szTip = self._tooltip
            shell32.Shell_NotifyIconW(NIM_MODIFY, ctypes.byref(nid))
        except Exception:
            pass

    def stop(self) -> None:
        if not self.supported or not self._hwnd:
            return
        try:
            user32.PostMessageW(self._hwnd, WM_DESTROY, 0, 0)
        except Exception:
            pass
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=1.5)
        self._hwnd = None
        self._active = False

    def _show_menu(self, hwnd) -> None:
        menu = user32.CreatePopupMenu()
        if not menu:
            return
        try:
            user32.AppendMenuW(menu, MF_STRING, ID_SHOW, "显示主窗口")
            user32.AppendMenuW(menu, MF_STRING, ID_LAUNCH, "检查修复并打开勾选项")
            user32.AppendMenuW(menu, MF_STRING, ID_CHECK, "检查全部代理状态")
            user32.AppendMenuW(menu, MF_SEPARATOR, 0, None)
            user32.AppendMenuW(menu, MF_STRING, ID_EXIT, "退出 AI 代理启动器")
            pt = wintypes.POINT()
            user32.GetCursorPos(ctypes.byref(pt))
            user32.SetForegroundWindow(hwnd)
            user32.TrackPopupMenu(menu, TPM_LEFTALIGN | TPM_BOTTOMALIGN | TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, None)
        finally:
            user32.DestroyMenu(menu)

    def _run(self) -> None:
        hinst = kernel32.GetModuleHandleW(None)
        class_name = f"AIProxyLauncherTray_{id(self)}"

        def proc(hwnd, msg, wparam, lparam):
            if msg == WM_TRAY:
                event = lparam & 0xFFFF
                if event in {WM_LBUTTONUP, WM_LBUTTONDBLCLK}:
                    self._on_show()
                elif event == WM_RBUTTONUP:
                    self._show_menu(hwnd)
                return 0
            if msg == WM_COMMAND:
                cmd = wparam & 0xFFFF
                if cmd == ID_SHOW:
                    self._on_show()
                elif cmd == ID_LAUNCH:
                    self._on_launch()
                elif cmd == ID_CHECK:
                    self._on_check()
                elif cmd == ID_EXIT:
                    self._on_exit()
                return 0
            if msg == WM_DESTROY:
                nid = NOTIFYICONDATAW()
                nid.cbSize = ctypes.sizeof(NOTIFYICONDATAW)
                nid.hWnd = hwnd
                nid.uID = 1
                shell32.Shell_NotifyIconW(NIM_DELETE, ctypes.byref(nid))
                if self._owns_icon and self._hicon:
                    user32.DestroyIcon(self._hicon)
                    self._hicon = None
                user32.PostQuitMessage(0)
                return 0
            return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

        self._wndproc = WNDPROC(proc)
        wc = WNDCLASSW()
        wc.lpfnWndProc = self._wndproc
        wc.hInstance = hinst
        wc.lpszClassName = class_name
        user32.RegisterClassW(ctypes.byref(wc))

        hwnd = user32.CreateWindowExW(0, class_name, "AIProxyLauncherTray", 0, 0, 0, 0, 0, None, None, hinst, None)
        if not hwnd:
            self._ready.set()
            return
        self._hwnd = hwnd

        hicon = None
        if self._icon_path and self._icon_path.is_file():
            hicon = user32.LoadImageW(None, str(self._icon_path), IMAGE_ICON, 16, 16, LR_LOADFROMFILE)
            if hicon:
                self._owns_icon = True
        if not hicon:
            hicon = user32.LoadIconW(None, ctypes.cast(IDI_APPLICATION, wintypes.LPCWSTR))
        self._hicon = hicon

        nid = NOTIFYICONDATAW()
        nid.cbSize = ctypes.sizeof(NOTIFYICONDATAW)
        nid.hWnd = hwnd
        nid.uID = 1
        nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP
        nid.uCallbackMessage = WM_TRAY
        nid.hIcon = hicon
        nid.szTip = self._tooltip
        self._active = bool(shell32.Shell_NotifyIconW(NIM_ADD, ctypes.byref(nid)))
        self._ready.set()
        if not self._active:
            user32.DestroyWindow(hwnd)
            return

        msg = wintypes.MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))
        self._active = False

