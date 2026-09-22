using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TeachingEmphasisSelfTest : Node
{
    private static string Output => "res://artifacts/teaching-emphasis-20260922" + (ExperienceProfile.IsDemo ? "-demo" : "");
    private SubViewport _viewport = null!;
    private int _checks;
    private async Task Frames()
    {
        for (int i = 0; i < 6; i++)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            JourneyTransition.For(this).Finish();
        }
    }
    private void Check(bool value, string message)
    { if (!value) throw new InvalidOperationException(message); _checks++; }
    private async Task Shot(string name)
    {
        await Frames(); RenderingServer.ForceDraw(false);
        using var image = _viewport.GetTexture().GetImage();
        Check(image.SavePng(ProjectSettings.GlobalizePath(Output + "/" + name + ".png")) == Error.Ok, name);
    }
    private void CheckInk(Label label, bool marked)
    {
        var ink = label.GetNode<TeachingEmphasis>("TeachingEmphasis"); ink.Refresh();
        string translated = label.Tr(label.Text);
        Check(ink.GetParsedText() == translated, "markup preserves translated copy: " + label.Text);
        Check(ink.Text.Split("[color=").Length - 1 == (marked ? 1 : 0), "one or zero emphasis: " + label.Text);
        Check(ink.GetContentHeight() <= ink.Size.Y + 1, $"text height fits: {label.Text} {ink.GetContentHeight()}/{ink.Size.Y}");
        Check(ink.GetContentWidth() <= ink.Size.X + 1, "text width fits: " + label.Text);
        Check(ink.MouseFilter == Control.MouseFilterEnum.Ignore, "text cannot intercept operation");
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            GetWindow().Position = new(-10000, -10000);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Output + "/settings-" + Guid.NewGuid() + ".cfg");
            var save = GetNode<SaveService>("/root/SaveService");
            if (ExperienceProfile.IsDemo) save.UseDemoPathForTests(Output + "/save-demo.json");
            else save.UsePathForTests(Output + "/save.json");
            Check(save.ResetProgress(out _), "isolated save");
            save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            _viewport = new SubViewport { Size = new(1920, 1080), RenderTargetUpdateMode = SubViewport.UpdateMode.Always, GuiEmbedSubwindows = true };
            AddChild(_viewport);
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            _viewport.AddChild(main);
            var start = main.GetNode<StartScreen>("UI/StartScreen"); start.PresentHome();
            await Frames();
            foreach (string language in new[] { "zh_CN", "en" })
            {
                settings.SetLanguage(language); await Frames();
                var guide = InterfaceTeaching.Offer(start, "emphasis-test", InterfaceLessons.Replay(StableIds.Cities.Tianjin), replay: true)!;
                await Frames();
                for (int i = 0; i < guide.StepCount; i++)
                {
                    var label = guide.FindChild("TeachingText", true, false) as Label;
                    CheckInk(label!, i is 0 or 4 or 5 or 8);
                    if (i is 0 or 4 or 5 or 8) await Shot($"interface-{i}-{language}");
                    ((Button)guide.FindChild("NextTeaching", true, false)).EmitSignal(Button.SignalName.Pressed);
                    await Frames();
                }
                foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
                {
                    start.PresentCity(city); await Frames();
                    ((Button)start.FindChild("Help", true, false)).EmitSignal(Button.SignalName.Pressed);
                    await Frames();
                    for (int i = 0; i < 3; i++) CheckInk((Label)start.FindChild("HelpTip" + i, true, false), true);
                    await Shot($"help-{city.Replace(':', '-')}-{language}-1080");
                    _viewport.Size = new(1280, 720); await Frames();
                    for (int i = 0; i < 3; i++) CheckInk((Label)start.FindChild("HelpTip" + i, true, false), true);
                    await Shot($"help-{city.Replace(':', '-')}-{language}-720");
                    start.PresentHome(); _viewport.Size = new(1920, 1080); await Frames();
                }
            }
            // Reuse one Label across changing instructions, language and ordinary summaries.
            var host = new Control { Theme = TianjinUi.CreateTheme() }; _viewport.AddChild(host);
            var text = new Label { AutowrapMode = TextServer.AutowrapMode.WordSmart }; host.AddChild(text);
            TeachingEmphasis.Attach(text);
            string[] operations = {
                "按住左键在面糊上划动，摊成一张饼。", "在饼面刷酱；达到订单酱量后短按右键收刷，或按 F。",
                "在焦饼上长按右键 0.45 秒，再拖入垃圾桶。", "把漏勺拖到空碗，沥干后自动倒入。",
                "按住左键在碗里划动，碗口进度环填满变绿后，再加牛肉。", "面已拌匀，点击牛肉加入碗中，无需再次搅拌。",
                "沿虚线横划一次、竖划一次，切好后自动入盘。", "拖入垃圾桶，松手丢弃。", "松手交给亮起的顾客。"
            };
            foreach (string language in new[] { "zh_CN", "en" })
            {
                settings.SetLanguage(language);
                foreach (string copy in operations.Concat(new[] { "等第一面成熟，再翻面。", "豆浆补货中，等待补满。",
                    "接下来自己试试。营业时留意火候，并按订单添加配料。", "教学记录未保存，请重试。", "请按订单要求重新制作并交付。" }))
                {
                    text.Text = copy; TeachingCardLayout.Place(text, 20, 20, 300); await Frames();
                    CheckInk(text, operations.Contains(copy));
                }
            }
            GD.Print($"TEACHING_EMPHASIS_PASS checks={_checks} demo={ExperienceProfile.IsDemo}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
