using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class BusinessBookSelfTest
{
    private async Task CheckReferencePresentation(DataCatalog catalog)
    {
        GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
        foreach (string city in new[] { "tianjin", "wuhan" })
        {
            var background = new TextureRect
            {
                Texture = GD.Load<Texture2D>(city == "tianjin" ? "res://resource/art/TianJin/天津-煎饼.png" : "res://resource/art/Wuhan/武汉-热干面-v1.png"),
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCovered,
                MouseFilter = Control.MouseFilterEnum.Ignore
            };
            AddChild(background); background.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            var save = new SaveService(); save.UsePathForTests("res://.tmp/book-tests/reference-" + city + ".json");
            AddChild(save);
            var source = new BookUpgradeSource(save, catalog, "city:" + city);
            // Explicitly synthetic, matching the supplied four-customer reference composition.
            var orders = Enumerable.Range(1, 4).Select(i => new BookOrder(i, "reference-" + i, "普通顾客",
                i % 2 == 0 ? "male_office" : "elder_regular",
                new[] { new BookProduct("reference-food", city == "tianjin" ? "基础煎饼" : "原味热干面", 1, city == "tianjin" ? "Pancake" : "HotDryNoodles") },
                BookOutcome.Perfect, 7, 1, 100)).ToArray();
            var model = new BusinessBookModel
            {
                CityId = city, Closing = true, Orders = orders, Upgrades = source,
                Result = new() { Day = 1, CompletedCustomers = 4, SaleRevenue = 28, Tips = 4, Satisfaction = 100, PerfectOrders = 4 },
                SaveMessage = "演示数据 · 已入账 ¥32"
            };
            var view = new BusinessDetailsView(); AddChild(view);
            foreach (var size in CaptureSizes)
            {
                GetWindow().Size = size; await Frames(5);
                view.Open(model); view.FinishAnimation(); await Frames();
                CheckArtPage(view, city, "reference summary");
                CheckTravelHighlightLayout(view);
                Check(view.Descendants<Button>().Single(b => b.Name == "OpenBookUpgrades").IsVisibleInTree(), city + " reference upgrade entry");
                if (Capture) await Shot($"reference-{city}-{size.X}-summary");
                Click(view.Descendants<Button>().Single(b => b.Name == "NextBookPage")); view.FinishAnimation(); await Frames();
                var scroll = view.Descendants<ScrollContainer>().Single();
                var rows = scroll.GetChild<VBoxContainer>(0).GetChildren().OfType<Control>().Where(c => c.Name.ToString().StartsWith("OrderRow")).ToArray();
                Check(rows.Length == 4 && rows[^1].GetRect().End.Y <= scroll.Size.Y, city + " four ordinary orders entirely visible");
                Check(view.Descendants<Button>().Single(b => b.Text == "完成 4").TooltipText.Contains("子集"), city + " completed filter explains overlapping counts");
                if (Capture) await Shot($"reference-{city}-{size.X}-details");
                model.Closing = false;
                view.Open(model); view.FinishAnimation(); await Frames();
                CheckTravelHighlightLayout(view);
                Check(view.Descendants<Label>().Any(l => l.IsVisibleInTree() && l.Text == "暂未流失"), city + " live zero loss is provisional");
                if (Capture) await Shot($"reference-{city}-{size.X}-live-summary");
                model.Closing = true;
            }
            view.QueueFree(); background.QueueFree(); save.QueueFree(); await Frames();
        }
    }
}
