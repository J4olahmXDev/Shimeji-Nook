using System.IO;
using System.Text.Json;
using System.Windows.Media.Imaging;
using System.Windows.Media;
namespace ShimejiNook;

record Frame(BitmapSource Image, byte[] Pixels, int W, int H);
record Animation(Frame[] Frames, double Fps, bool Loop, int Facing, double RenderScale, double HorizontalPivot, double BottomPadding);
record Model(string Id, string Name, string Assets, string[] Quotes);
class Library
{
    public List<Model> Models { get; } = [];
    public Model Current { get; private set; } = null!;
    public Dictionary<string, Animation> Animations { get; private set; } = [];
    public Library() { string root = Path.Combine(AppContext.BaseDirectory, "Assets"); Models.Add(new("thungngern", "ถุงเงิน", root, ["ถุงอยู่กับซัวว์นะ 💙", "ถุงเป็นกำลังใจให้นะ", "ค่อย ๆ ทำทีละนิดก็ได้นะ ถุงรอได้", "พักหายใจสักนิดนะ แล้วเราค่อยไปต่อด้วยกัน", "วันนี้ซัวว์ทำได้ดีแล้วนะ", "เหนื่อยก็พักได้ ถุงอยู่ตรงนี้เสมอ", "ไม่ต้องเก่งทุกวันก็ได้ แค่พยายามก็พอแล้ว", "ดื่มน้ำสักหน่อยไหม ถุงเป็นห่วงนะ"])); string packs = Path.Combine(root, "Models"); if (Directory.Exists(packs)) foreach (var folder in Directory.GetDirectories(packs)) { using var d = JsonDocument.Parse(File.ReadAllText(Path.Combine(folder, "model.json"))); var j = d.RootElement; Models.Add(new(j.GetProperty("id").GetString()!, j.GetProperty("displayName").GetString()!, Path.Combine(folder, j.GetProperty("assetsDirectory").GetString()!), j.GetProperty("speech").GetProperty("quotes").EnumerateArray().Select(q => q.GetString()!).ToArray())); } }
    public void Select(string id) { var model = Models.FirstOrDefault(m => m.Id == id) ?? Models[0]; using var doc = JsonDocument.Parse(File.ReadAllText(Path.Combine(model.Assets, "manifest.json"))); var root = doc.RootElement; Dictionary<string, Animation> result = []; foreach (var entry in root.GetProperty("animations").EnumerateObject()) { string state = entry.Name[(entry.Name.IndexOf('_') + 1)..]; state = state == "climb_hang" ? "climb" : state == "interactions" ? "drag" : state; var j = entry.Value; var frames = Directory.GetFiles(Path.Combine(model.Assets, entry.Name), "frame_*.png").OrderBy(f => f, StringComparer.Ordinal).Select(ReadFrame).ToArray(); if (j.TryGetProperty("playbackOrder", out var order)) frames = order.EnumerateArray().Select(n => frames[n.GetInt32()]).ToArray(); int facing = root.TryGetProperty("nativeFacing", out var face) && face.TryGetProperty(state, out var v) ? v.GetInt32() : 1; result[state] = new(frames, j.GetProperty("fps").GetDouble(), !j.TryGetProperty("loop", out var loop) || loop.GetBoolean(), facing, j.TryGetProperty("renderScale", out var rs) ? rs.GetDouble() : 1, j.TryGetProperty("horizontalPivot", out var hp) ? hp.GetDouble() : .5, (root.GetProperty("canvas")[1].GetDouble() - root.GetProperty("pivot")[1].GetDouble()) / root.GetProperty("canvas")[1].GetDouble()); } if (!result.ContainsKey("idle")) throw new InvalidDataException("Model is missing idle frames"); Animations = result; Current = model; }
    static Frame ReadFrame(string file) { var image = new BitmapImage(); image.BeginInit(); image.CacheOption = BitmapCacheOption.OnLoad; image.UriSource = new Uri(file); image.EndInit(); image.Freeze(); var rgba = new FormatConvertedBitmap(image, PixelFormats.Bgra32, null, 0); rgba.Freeze(); byte[] pixels = new byte[rgba.PixelWidth * rgba.PixelHeight * 4]; rgba.CopyPixels(pixels, rgba.PixelWidth * 4, 0); return new(rgba, pixels, rgba.PixelWidth, rgba.PixelHeight); }
    public Animation Get(string state) => Animations.GetValueOrDefault(state) ?? Animations["idle"];
}
