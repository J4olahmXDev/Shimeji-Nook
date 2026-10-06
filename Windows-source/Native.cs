using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
namespace ShimejiNook;

static class Native
{
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; public int Width => Right - Left; public int Height => Bottom - Top; }
    [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int Size; public RECT Monitor, Work; public uint Flags; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(nint h, System.Text.StringBuilder value, int size);
    public delegate bool EnumProc(nint h, nint p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, nint p);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(nint h);
    [DllImport("user32.dll")] public static extern bool IsIconic(nint h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(nint h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(nint h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] public static extern nint GetStyle(nint h, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] public static extern nint SetStyle(nint h, int index, nint value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(nint h, nint after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(nint h);
    [DllImport("user32.dll")] public static extern nint MonitorFromPoint(POINT p, uint flags);
    [DllImport("user32.dll")] public static extern bool GetMonitorInfo(nint h, ref MONITORINFO info);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(nint h, int attribute, out RECT value, int size);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(nint h, int attribute, out int value, int size);
    public static RECT Work(double x, double y) { var m = new MONITORINFO { Size = Marshal.SizeOf<MONITORINFO>() }; GetMonitorInfo(MonitorFromPoint(new POINT { X = (int)x, Y = (int)y }, 2), ref m); return m.Work; }
    public static List<(nint Handle, RECT Rect)> Windows() { var list = new List<(nint, RECT)>(); EnumWindows((h, p) => { GetWindowThreadProcessId(h, out uint pid); var name = new System.Text.StringBuilder(256); GetClassName(h, name, 256); if (name.ToString() is "Progman" or "WorkerW" or "Shell_TrayWnd" or "Shell_SecondaryTrayWnd") return true; if (pid == Environment.ProcessId || !IsWindowVisible(h) || IsIconic(h) || ((long)GetStyle(h, -20) & 0x80) != 0) return true; DwmGetWindowAttribute(h, 14, out int cloak, 4); if (cloak != 0) return true; if (DwmGetWindowAttribute(h, 9, out RECT r, 16) != 0) GetWindowRect(h, out r); if (r.Width > 100 && r.Height > 80) list.Add((h, r)); return true; }, 0); return list; }
    public static void Transparent(nint h, bool on) { long s = (long)GetStyle(h, -20), v = on ? s | 0x20 : s & ~0x20; if (v != s) SetStyle(h, -20, (nint)v); }
}
class FloatWindow : Window
{
    public nint Handle { get; private set; }
    public double Scale => Handle == 0 ? 1 : Math.Max(1, Native.GetDpiForWindow(Handle) / 96.0);
    public FloatWindow() { WindowStyle = WindowStyle.None; AllowsTransparency = true; Background = System.Windows.Media.Brushes.Transparent; Topmost = true; ShowInTaskbar = Program.InspectUI; ShowActivated = false; ResizeMode = ResizeMode.NoResize; SourceInitialized += (_, _) => { Handle = new WindowInteropHelper(this).Handle; Native.SetStyle(Handle, -20, (nint)((long)Native.GetStyle(Handle, -20) | 0x08000000 | (Program.InspectUI ? 0L : 0x80L))); HwndSource.FromHwnd(Handle)?.AddHook(Hook); }; }
    nint Hook(nint h, int msg, nint w, nint l, ref bool handled) { if (msg == 0x21) { handled = true; return 3; } return 0; }
    public void Place(double x, double y) { Native.SetWindowPos(Handle, -1, (int)Math.Round(x), (int)Math.Round(y), (int)Math.Ceiling(ActualWidth * Scale), (int)Math.Ceiling(ActualHeight * Scale), 0x10); }
    public bool Contains(Native.POINT p) { Native.GetWindowRect(Handle, out var r); return p.X >= r.Left && p.X < r.Right && p.Y >= r.Top && p.Y < r.Bottom; }
}


