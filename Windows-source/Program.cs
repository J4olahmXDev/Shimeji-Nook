using System.IO;
using System.Diagnostics;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
namespace ShimejiNook;

static class Program
{
    internal static readonly bool InspectUI = Environment.GetCommandLineArgs().Contains("--inspect-ui");
    public static readonly string Data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ShimejiNook");
    internal static void Log(string message)
    {
        try
        {
            Directory.CreateDirectory(Data);
            File.AppendAllText(Path.Combine(Data, "runtime.log"), $"{DateTimeOffset.Now:O} [{Environment.ProcessId}] {message}{Environment.NewLine}");
        }
        catch { Debug.WriteLine(message); }
    }

    private static void MigratePreviousApplication()
    {
        try
        {
            string previousSettings = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ThungNgern", "settings.json");
            string currentSettings = Path.Combine(Data, "settings.json");
            if (!File.Exists(currentSettings) && File.Exists(previousSettings)) File.Copy(previousSettings, currentSettings);
        }
        catch (Exception error) { Log($"Previous settings could not be copied: {error.Message}"); }
        try
        {
            using var previousExit = EventWaitHandle.OpenExisting("Local\\ThungNgern.Exit");
            previousExit.Set();
        }
        catch (WaitHandleCannotBeOpenedException) { }
        catch (UnauthorizedAccessException error) { Log($"Previous instance could not be signalled: {error.Message}"); }
    }

    [STAThread] static void Main()
    {
        try
        {
            Directory.CreateDirectory(Data);
            MigratePreviousApplication();
            Log("Starting");
            using var mutex = new Mutex(false, "Local\\ShimejiNook.Singleton");
            using var exit = new EventWaitHandle(false, EventResetMode.AutoReset, "Local\\ShimejiNook.Exit");
            bool owned;
            try { owned = mutex.WaitOne(0); } catch (AbandonedMutexException) { owned = true; }
            if (!owned)
            {
                exit.Set();
                try { owned = mutex.WaitOne(5000); } catch (AbandonedMutexException) { owned = true; }
                if (!owned) { Log("Previous instance did not exit within five seconds"); return; }
            }
            try
            {
                var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
                app.DispatcherUnhandledException += (_, e) => Log(e.Exception.ToString());
                Log("Loading character");
                var pet = new Pet();
                app.MainWindow = pet;
                var watcher = ThreadPool.RegisterWaitForSingleObject(exit, (_, _) => app.Dispatcher.BeginInvoke(() => { Log("Exit requested by another instance"); app.Shutdown(); }), null, -1, true);
                try { Log("Showing character"); pet.Show(); Log("Running"); app.Run(); }
                finally { watcher.Unregister(null); Log("Stopped"); }
            }
            finally { mutex.ReleaseMutex(); }
        }
        catch (Exception e) { Log(e.ToString()); MessageBox.Show(e.Message, "Shimeji Nook startup error"); }
    }
}
class Pet : FloatWindow
{
    readonly Library library = new(); readonly Image image = new() { Stretch = Stretch.Fill }; readonly Canvas canvas = new(); double imageX, imageY, imageW, imageH; readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromMilliseconds(16) }; readonly Stopwatch clock = Stopwatch.StartNew(); readonly Random random = new(); readonly List<FloatWindow> menus = [];
    readonly string settings = Path.Combine(Program.Data, "settings.json");
    Frame? frame; double x, y, vy, last, animationTime, stateUntil, speechUntil, decisionAt; int direction = 1, climbSide; string state = "idle"; bool paused, wandering = !Program.InspectUI, dragging, manual; double dragX, dragY; nint support; Native.RECT supportRect; FloatWindow? bubble; bool previousLeft, previousRight; Queue<string> quotes = new(); string lastQuote = "";
    public Pet() { Width = 160; Height = 193.333; canvas.Children.Add(image); Content = canvas; Title = "Shimeji Nook"; string id = "thungngern"; try { if (File.Exists(settings)) id = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(settings))?.GetValueOrDefault("model") ?? id; } catch { } library.Select(id); Loaded += (_, _) => { Home(); timer.Start(); }; timer.Tick += Tick; MouseRightButtonUp += (_, e) => { OpenMenu(); e.Handled = true; }; MouseLeftButtonDown += (_, e) => { CloseMenus(); Native.GetCursorPos(out var p); dragging = true; stateUntil = 0; manual = false; dragX = p.X - x; dragY = p.Y - y; support = 0; climbSide = 0; vy = 0; CaptureMouse(); SetState("drag"); e.Handled = true; }; MouseMove += (_, _) => { if (dragging) { Native.GetCursorPos(out var p); x = p.X - dragX; y = p.Y - dragY; Place(x, y); } }; MouseLeftButtonUp += (_, _) => { if (dragging) { dragging = false; ReleaseMouseCapture(); Snap(); SetState(climbSide != 0 ? "climb" : support != 0 ? "sit" : "fall"); stateUntil = clock.Elapsed.TotalSeconds + 3; } }; LostMouseCapture += (_, _) => { if (dragging) { dragging = false; Snap(); SetState(climbSide != 0 ? "climb" : support != 0 ? "sit" : "fall"); stateUntil = clock.Elapsed.TotalSeconds + 3; } }; Closed += (_, _) => { timer.Stop(); CloseMenus(); bubble?.Close(); }; }
    void SetState(string value) { if (state != value) { state = value; animationTime = 0; } }
    void Home() { Native.GetCursorPos(out var p); var w = Native.Work(p.X, p.Y); x = (w.Left + w.Right) / 2 - 80 * Scale; y = w.Bottom - Height * Scale; vy = 0; support = 0; climbSide = 0; manual = false; stateUntil = 0; decisionAt = 0; SetState("idle"); Place(x, y); }
    void Snap() { var wins = Native.Windows(); double feet = y + Height * Scale; foreach (var w in wins) { if (x + Width * Scale * .7 > w.Rect.Left && x + Width * Scale * .3 < w.Rect.Right && Math.Abs(feet - w.Rect.Top) < 45 * Scale && CanPerch(w.Rect)) { support = w.Handle; supportRect = w.Rect; y = w.Rect.Top - Height * Scale; vy = 0; return; } if (y + Height * Scale > w.Rect.Top && y < w.Rect.Bottom) { if (Math.Abs(x + Width * Scale * .5 - w.Rect.Left) < 35 * Scale) { support = w.Handle; supportRect = w.Rect; climbSide = -1; x = w.Rect.Left - Width * Scale * .5; return; } if (Math.Abs(x + Width * Scale * .5 - w.Rect.Right) < 35 * Scale) { support = w.Handle; supportRect = w.Rect; climbSide = 1; x = w.Rect.Right - Width * Scale * .5; return; } } } }
    void Tick(object? sender, EventArgs args)
    {
        double now = clock.Elapsed.TotalSeconds, dt = Math.Min(.05, now - last); last = now; Native.GetCursorPos(out var cursor); bool left = Native.GetAsyncKeyState(1) < 0, right = Native.GetAsyncKeyState(2) < 0; if (menus.Count > 0) { if ((left && !previousLeft || right && !previousRight) && !menus.Any(m => m.Contains(cursor))) CloseMenus(); }
        previousLeft = left; previousRight = right;
        bool hit = dragging || Opaque(cursor); Native.Transparent(Handle, !Program.InspectUI && !hit);
        if (!paused && menus.Count == 0 && !dragging)
        {
            if (support != 0) { var w = Native.Windows().FirstOrDefault(w => w.Handle == support); if (w.Handle == 0) { support = 0; climbSide = 0; } else { x += w.Rect.Left - supportRect.Left; y += w.Rect.Top - supportRect.Top; supportRect = w.Rect; if (climbSide != 0) x = (climbSide < 0 ? w.Rect.Left : w.Rect.Right) - Width * Scale * .5; } }
            var area = Native.Work(x + Width * Scale / 2, y + Height * Scale / 2); double floor = area.Bottom; if (support != 0 && climbSide == 0 && !CanPerch(supportRect)) { support = 0; y = Math.Max(area.Top, y); } bool speaking = now < speechUntil;
            if (climbSide != 0 && support != 0) { SetState("climb"); direction = climbSide == -1 ? 1 : -1; y = Math.Max(area.Top, y - 35 * Scale * dt); if (y + Height * Scale <= supportRect.Top) { climbSide = 0; y = supportRect.Top - Height * Scale; x = Math.Clamp(x, supportRect.Left, Math.Max(supportRect.Left, supportRect.Right - Width * Scale)); SetState("sit"); stateUntil = now + 3; } else if (y <= area.Top && !CanPerch(supportRect)) { climbSide = 0; support = 0; vy = 0; SetState("fall"); } }
            else
            {
                if (support != 0) { floor = supportRect.Top; if (x + Width * Scale * .7 < supportRect.Left || x + Width * Scale * .3 > supportRect.Right) { support = 0; floor = area.Bottom; } }
                double feet = y + Height * Scale; bool grounded = feet >= floor - .8 && vy >= 0;
                if (!grounded) { double oldFeet = feet; vy += 750 * Scale * dt; y += vy * dt; foreach (var w in Native.Windows()) { if (CanPerch(w.Rect) && vy > 0 && oldFeet <= w.Rect.Top && y + Height * Scale >= w.Rect.Top && x + Width * Scale * .7 > w.Rect.Left && x + Width * Scale * .3 < w.Rect.Right) { support = w.Handle; supportRect = w.Rect; floor = w.Rect.Top; break; } } if (y + Height * Scale >= floor && vy >= 0) { y = floor - Height * Scale; vy = 0; SetState("idle"); } else SetState(vy < 0 ? "jump" : "fall"); }
                else { y = floor - Height * Scale; vy = 0; if (speaking && state != "sleep") SetState("talk"); else if (state == "sleep") { } else if (now < stateUntil) { } else if (manual || wandering) { if (!manual && now >= decisionAt) { direction = random.Next(2) == 0 ? -1 : 1; SetState(random.Next(5) == 0 ? "run" : "walk"); decisionAt = now + random.Next(4, 9); } if (state != "walk" && state != "run") SetState("walk"); x += direction * (state == "run" ? 95 : 42) * Scale * dt; double min = support != 0 ? supportRect.Left : area.Left, max = (support != 0 ? supportRect.Right : area.Right) - Width * Scale; if (x < min || x > max) { var next = Native.Work(direction > 0 ? area.Right + 1 : area.Left - 1, y + Height * Scale / 2); if (support != 0 || next.Left == area.Left && next.Right == area.Right) { x = Math.Clamp(x, min, Math.Max(min, max)); direction = -direction; if (manual) { manual = false; SetState("wave"); stateUntil = now + 2; } } } } else SetState("idle"); }
            }
            Place(x, y);
        }
        if ((!paused || dragging) && menus.Count == 0) animationTime += dt;
        if (now >= speechUntil && bubble != null) { bubble.Close(); bubble = null; }
        if (bubble != null) { var r = Native.Work(x, y); bubble.Place(Math.Clamp(x + (Width * Scale - bubble.ActualWidth * bubble.Scale) / 2, r.Left, r.Right - bubble.ActualWidth * bubble.Scale), Math.Max(r.Top, y - bubble.ActualHeight * bubble.Scale - 5 * Scale)); }
        var animation = library.Get(state); int index = (int)(animationTime * animation.Fps); index = animation.Loop ? index % animation.Frames.Length : Math.Min(index, animation.Frames.Length - 1); frame = animation.Frames[index]; double size = Math.Min(Width / frame.W, Height / frame.H) * animation.RenderScale; imageW = frame.W * size; imageH = frame.H * size; imageX = Width / 2 - imageW * animation.HorizontalPivot; imageY = Height - imageH * (1 - animation.BottomPadding); image.Width = imageW; image.Height = imageH; Canvas.SetLeft(image, imageX); Canvas.SetTop(image, imageY); image.Source = frame.Image; image.RenderTransformOrigin = new Point(.5, .5); image.RenderTransform = new ScaleTransform(direction != animation.Facing && state is "walk" or "run" or "climb" ? -1 : 1, 1);
    }
    bool Opaque(Native.POINT p) { if (frame == null) return false; double sx = ((p.X - x) / Scale - imageX) / imageW, sy = ((p.Y - y) / Scale - imageY) / imageH; if (sx < 0 || sx >= 1 || sy < 0 || sy >= 1) return false; if (image.RenderTransform is ScaleTransform t && t.ScaleX < 0) sx = 1 - sx; int ix = Math.Clamp((int)(sx * frame.W), 0, frame.W - 1), iy = Math.Clamp((int)(sy * frame.H), 0, frame.H - 1); return frame.Pixels[(iy * frame.W + ix) * 4 + 3] > 24; }
    void Say() { if (quotes.Count == 0) { var shuffled = library.Current.Quotes.OrderBy(_ => random.Next()).ToList(); if (shuffled.Count > 1 && shuffled[0] == lastQuote) (shuffled[0], shuffled[1]) = (shuffled[1], shuffled[0]); quotes = new(shuffled); } lastQuote = quotes.Dequeue(); bubble?.Close(); var text = new TextBlock { Text = lastQuote, FontSize = 14, TextWrapping = TextWrapping.Wrap, MaxWidth = 215, Foreground = Brushes.DarkSlateGray }; bubble = new FloatWindow { Title = "Shimeji Nook Speech", SizeToContent = SizeToContent.WidthAndHeight, Content = new Border { Background = new SolidColorBrush(Color.FromArgb(245, 255, 252, 245)), CornerRadius = new CornerRadius(12), Padding = new Thickness(12, 9, 12, 9), Child = text } }; bubble.Show(); Native.Transparent(bubble.Handle, true); speechUntil = clock.Elapsed.TotalSeconds + 8; }
    void Emote(string value) { manual = false; if (value == "jump") { climbSide = 0; support = 0; vy = -390 * Scale; y -= 2 * Scale; } if (value == "sleep" && state == "sleep") value = "idle"; SetState(value); stateUntil = value == "sleep" ? double.PositiveInfinity : clock.Elapsed.TotalSeconds + (value == "run" ? 5 : 3); if (value == "run") { manual = true; stateUntil = 0; } }
    bool CanPerch(Native.RECT rect) => rect.Top - Height * Scale >= Native.Work((rect.Left + rect.Right) / 2.0, rect.Top).Top;
    void Visit(int side = 0) { var windows = Native.Windows().Where(w => side != 0 || CanPerch(w.Rect)).ToList(); if (windows.Count == 0) { Say(); return; } var w = windows.OrderBy(w => Math.Abs(w.Rect.Left - x) + Math.Abs(w.Rect.Top - y)).First(); support = w.Handle; supportRect = w.Rect; vy = 0; climbSide = side; y = side == 0 ? w.Rect.Top - Height * Scale : w.Rect.Top + Math.Min(120 * Scale, w.Rect.Height / 2); x = side < 0 ? w.Rect.Left - Width * Scale * .5 : side > 0 ? w.Rect.Right - Width * Scale * .5 : w.Rect.Left + Math.Max(0, (w.Rect.Width - Width * Scale) / 2); SetState(side == 0 ? "sit" : "climb"); stateUntil = clock.Elapsed.TotalSeconds + 3; }
    void CloseMenus() { foreach (var m in menus.ToArray()) m.Close(); menus.Clear(); }
    record Item(string Text, Action? Action = null, Item[]? Children = null, bool Red = false);
    Item[] Items() => [new("Emotes", Children: [new("Wave", () => Emote("wave")), new("Happy", () => Emote("happy")), new("Jump", () => Emote("jump")), new(state == "sleep" ? "Wake Up" : "Sleep", () => Emote("sleep")), new("Sit", () => Emote("sit")), new("Run", () => Emote("run"))]), new("Change Model", Children: library.Models.Select(m => new Item((m.Id == library.Current.Id ? "✓ " : "") + m.Name, () => { library.Select(m.Id); File.WriteAllText(settings, JsonSerializer.Serialize(new { model = m.Id })); quotes.Clear(); lastQuote = ""; bubble?.Close(); bubble = null; speechUntil = 0; manual = false; stateUntil = 0; decisionAt = 0; SetState("idle"); animationTime = 0; })).ToArray()), new("Say", Say), new("-"), new(paused ? "Resume" : "Pause", () => paused = !paused), new(wandering ? "Stop Wandering" : "Start Wandering", () => { wandering = !wandering; manual = false; stateUntil = 0; SetState("idle"); }), new("-"), new("Move", Children: [new("Walk Left", () => { direction = -1; manual = true; stateUntil = 0; SetState("walk"); }), new("Walk Right", () => { direction = 1; manual = true; stateUntil = 0; SetState("walk"); }), new("Climb Window Left Side", () => Visit(-1)), new("Climb Window Right Side", () => Visit(1)), new("Visit a Window", () => Visit()), new("Bring Me Home", Home)]), new("-"), new("Quit", () => Application.Current.Shutdown(), Red: true)];
    void OpenMenu() { CloseMenus(); Native.GetCursorPos(out var p); ShowMenu(Items(), p.X, p.Y, false); }
    void ShowMenu(Item[] items, double px, double py, bool child) { if (child) { foreach (var m in menus.Skip(1).ToArray()) { m.Close(); menus.Remove(m); } } var stack = new StackPanel(); double width = child ? Math.Max(155, items.Max(i => Measure(i.Text)) + 46) : 200; var window = new FloatWindow { Title = child ? "ShimejiNook Submenu" : "ShimejiNook Menu", Width = width, SizeToContent = SizeToContent.Height, Content = new Border { Background = new SolidColorBrush(Color.FromArgb(248, 251, 249, 247)), CornerRadius = new CornerRadius(10), BorderBrush = Brushes.LightGray, BorderThickness = new Thickness(1), Padding = new Thickness(6), Child = stack } }; foreach (var item in items) { if (item.Text == "-") { stack.Children.Add(new Border { Height = 9, Child = new Border { Height = 1, Background = Brushes.LightGray, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(12, 0, 12, 0) } }); continue; } var label = new TextBlock { Text = item.Text + (item.Children != null ? "   ›" : ""), FontSize = 13, VerticalAlignment = VerticalAlignment.Center, Foreground = item.Red ? Brushes.Firebrick : Brushes.Black }; var b = new Border { Height = 24, CornerRadius = new CornerRadius(5), Padding = new Thickness(10, 0, 4, 0), Background = Brushes.Transparent, Child = label }; b.MouseEnter += (_, _) => { b.Background = new SolidColorBrush(Color.FromRgb(225, 235, 250)); if (item.Children != null) { Native.GetWindowRect(window.Handle, out var r); Point pos = b.TranslatePoint(new Point(0, 0), window); ShowMenu(item.Children, r.Right, r.Top + pos.Y * window.Scale, true); } else if (!child) { foreach (var m in menus.Skip(1).ToArray()) { m.Close(); menus.Remove(m); } } }; b.MouseLeave += (_, _) => b.Background = Brushes.Transparent; b.MouseLeftButtonUp += (_, e) => { e.Handled = true; if (item.Children != null) { Native.GetWindowRect(window.Handle, out var r); Point pos = b.TranslatePoint(new Point(0, 0), window); ShowMenu(item.Children, r.Right, r.Top + pos.Y * window.Scale, true); } else { CloseMenus(); item.Action?.Invoke(); } }; stack.Children.Add(b); } menus.Add(window); window.Show(); window.UpdateLayout(); var work = Native.Work(px, py); if (child && px + window.ActualWidth * window.Scale > work.Right) { Native.GetWindowRect(menus[0].Handle, out var parent); px = parent.Left - window.ActualWidth * window.Scale; } window.Place(Math.Clamp(px, work.Left, Math.Max(work.Left, work.Right - window.ActualWidth * window.Scale)), Math.Clamp(py, work.Top, Math.Max(work.Top, work.Bottom - window.ActualHeight * window.Scale))); }
    static double Measure(string value) => new FormattedText(value, System.Globalization.CultureInfo.CurrentUICulture, FlowDirection.LeftToRight, new Typeface("Segoe UI"), 13, Brushes.Black, 1).Width;
}





