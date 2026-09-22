using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private bool _showCustomerCollection;
    private string _customerCategory = "", _selectedCollectionCustomer = "";
    private int _customerPage;
    private WuhanArtCatalog? _collectionPortraitArt;
    private readonly Dictionary<string, Texture2D> _customerDetailIcons = new();

    private TextureRect CustomerDetailIcon(Control parent, string asset, Rect2 bounds, float rotation = 0)
    {
        string path = "res://resource/art/Global/" + asset + ".png";
        if (!_customerDetailIcons.TryGetValue(path, out var texture))
        {
            var source = Texture(path);
            using var pixels = source.GetImage(); var used = pixels.GetUsedRect();
            texture = new AtlasTexture { Atlas = source, Region = new Rect2(used.Position, used.Size) };
            _customerDetailIcons[path] = texture;
        }
        var icon = new TextureRect { Name = "DetailIcon", ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered, Texture = texture,
            Position = bounds.Position, Size = bounds.Size, PivotOffset = bounds.Size / 2,
            RotationDegrees = rotation, MouseFilter = MouseFilterEnum.Ignore };
        parent.AddChild(icon); return icon;
    }

    private void CollectionSectionTabs()
    {
        foreach (var (id, title, customers, x) in new[] {
            ("BreakfastSection", "早餐收藏", false, 143f), ("CustomerSection", "顾客图鉴", true, 392f) })
        {
            var button = Button(_collectionContent, id, "", new(x, 203, 227, 51), () =>
            {
                _showCustomerCollection = customers;
                PresentBreakfastCollection(); Focus(id);
            }, bare: true);
            CollectionPaper(button, new(0, 0, 227, 51), selected: _showCustomerCollection == customers);
            Text(button, "Caption", title, new(8, 3, 211, 45), 29, true);
        }
    }

    private CustomerStatistics CustomerStats(string id) => _save!.Data.CustomerRecords.GetValueOrDefault(id) ?? new();
    private static string CustomerCategoryName(string category) => category == CustomerCollection.Generic ? "通用" : JourneyModel.City(category).Name;

    private void RenderCustomerCollection()
    {
        bool wuhan = _save!.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan);
        if (_customerCategory == StableIds.Cities.Wuhan && !wuhan) { _customerCategory = ""; _customerPage = 0; }
        var all = CustomerCollection.Cards.Where(c => _customerCategory == "" || c.Category == _customerCategory).ToArray();
        var available = all.Where(c => c.Category != StableIds.Cities.Wuhan || wuhan).ToArray();
        int pages = Math.Max(1, (available.Length + 7) / 8);
        _customerPage = Math.Clamp(_customerPage, 0, pages - 1);
        var shown = available.Skip(_customerPage * 8).Take(8).ToArray();
        var selected = shown.FirstOrDefault(c => c.Id == _selectedCollectionCustomer) ?? shown.FirstOrDefault();
        _selectedCollectionCustomer = selected?.Id ?? "";
        var categories = new[] { ("", "全部"), (CustomerCollection.Generic, "通用"), (StableIds.Cities.Tianjin, "天津"), (StableIds.Cities.Wuhan, "武汉") };
        for (int i = 0; i < categories.Length; i++)
        {
            var (category, title) = categories[i]; string name = "CustomerCategory" + i;
            var button = Button(_collectionContent, name, "", new(130 + i * 190, 272, 174, 52), () =>
            {
                _customerCategory = category; _customerPage = 0; _selectedCollectionCustomer = "";
                PresentBreakfastCollection(); Focus(name);
            }, bare: true);
            CollectionPaper(button, new(0, 0, 174, 52), selected: category == _customerCategory);
            Text(button, "Caption", title, new(6, 5, 162, 42), 25, true);
            if (category == StableIds.Cities.Wuhan && !wuhan)
            {
                button.Disabled = true;
                var mark = CollectionPaper(button, new(134, 16, 30, 30), "lock"); mark.Scale = Vector2.One * .65f;
            }
        }
        _collectionPortraitArt ??= new WuhanArtCatalog();
        for (int i = 0; i < shown.Length; i++)
        {
            var card = shown[i]; var stats = CustomerStats(card.Id);
            var button = Button(_collectionContent, "CustomerCard_" + card.Id, "", new(130 + i % 4 * 190, 347 + i / 4 * 221, 174, 207), () =>
            {
                _selectedCollectionCustomer = card.Id; PresentBreakfastCollection(); Focus("CustomerCard_" + card.Id);
            }, bare: true);
            CollectionPaper(button, new(0, 0, 174, 207), "postage", selected?.Id == card.Id);
            var head = _collectionPortraitArt.CustomerPortrait(card.Id, CustomerExpression.Normal).Head;
            using var pixels = head.GetImage(); var bounds = pixels.GetUsedRect();
            var portrait = new TextureRect { Name = "Portrait", Position = new(27, 12), Size = new(120, 104),
                Texture = new AtlasTexture { Atlas = head, Region = new Rect2(bounds.Position, bounds.Size) },
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                MouseFilter = MouseFilterEnum.Ignore, Modulate = stats.Known ? Colors.White : new Color(0, 0, 0, .28f) };
            button.AddChild(portrait);
            Text(button, "Name", stats.Known ? card.Name : "尚未结识", new(10, 120, 154, 52), 23, true);
            Text(button, "State", stats.Regular ? "熟客" : stats.Known ? $"已接待 {stats.Served} 次" : CustomerCategoryName(card.Category), new(8, 177, 158, 24), 19, true);
        }
        var previous = Button(_collectionContent, "CustomerPrevious", "", new(143, 795, 166, 48), () => ChangeCustomerPage(-1), bare: true);
        PageArrowArt.Apply(previous, false, _customerCategory);
        previous.Disabled = _customerPage == 0;
        Text(_collectionContent, "CustomerPage", $"{_customerPage + 1} / {pages}", new(350, 795, 300, 48), 25, true);
        var next = Button(_collectionContent, "CustomerNext", "", new(710, 795, 166, 48), () => ChangeCustomerPage(1), bare: true);
        PageArrowArt.Apply(next, true, _customerCategory);
        next.Disabled = _customerPage + 1 == pages;
        Text(_collectionContent, "CustomerFooter", wuhan ? "一顿顿早餐，把过客变成熟悉的面孔。" : "下一站武汉，还有新的朋友等你认识。", new(150, 864, 720, 45), 23, true);
        if (selected is not null) RenderCustomerDetail(selected);
        Focus(selected is null ? "Back" : "CustomerCard_" + selected.Id);
    }

    private void ChangeCustomerPage(int delta)
    {
        _customerPage += delta; _selectedCollectionCustomer = ""; PresentBreakfastCollection();
    }

    private void RenderCustomerDetail(CustomerCard card)
    {
        var stats = CustomerStats(card.Id);
        _collectionDetail = new Control { Name = "CustomerDetail", Position = new(1032, 110), Size = new(747, 837),
            Scale = Vector2.One * .94f, MouseFilter = MouseFilterEnum.Ignore };
        _collectionContent.AddChild(_collectionDetail);
        Text(_collectionDetail, "CustomerName", stats.Known ? card.Name : "尚未结识", new(10, 0, 720, 72), 40);
        Text(_collectionDetail, "CustomerOrigin", CustomerCategoryName(card.Category) + " · 熟客小记", new(12, 77, 680, 39), 24);
        var photo = CollectionPaper(_collectionDetail, new(10, 138, 284, 338), "photo");
        if (stats.Known)
        {
            var portrait = GD.Load<PackedScene>("res://Scenes/UI/CustomerPortraitView.tscn").Instantiate<CustomerPortraitView>();
            portrait.Position = new(16, 16); photo.AddChild(portrait);
            portrait.SetVisual(_collectionPortraitArt!.CustomerPortrait(card.Id, CustomerExpression.Normal));
            portrait.SetCounterCalibration(_collectionPortraitArt.CustomerLayout(card.Id));
            portrait.CustomMinimumSize = Vector2.Zero; portrait.Size = new(252, 250);
        }
        else
        {
            var silhouette = new TextureRect
            {
                Name = "CustomerSilhouette", Position = new(16, 16), Size = new(252, 250),
                Texture = GD.Load<Texture2D>(CustomerCollection.FullBodyArtPath(card)),
                ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                MouseFilter = MouseFilterEnum.Ignore,
                Modulate = new Color(0, 0, 0, .28f),
            };
            photo.AddChild(silhouette);
        }
        Text(photo, "PhotoCaption", stats.Known ? "旅途中认识的朋友" : "期待下一次相遇", new(10, 281, 264, 38), 23, true);
        var heart = CustomerDetailIcon(photo, "BookUI/奖励章中心符号｜爱心", new(244, -12, 48, 48), 12);
        heart.Modulate = stats.Known ? Colors.White : new Color(1, 1, 1, .45f);
        CustomerDetailIcon(_collectionDetail, "HUDUI/经营手账页图标-天津", new(330, 136, 47, 52), -8);
        Text(_collectionDetail, "NoteTitle", "人物小记", new(392, 139, 331, 47), 30);
        Text(_collectionDetail, "CustomerDescription", stats.Known ? card.Description : "正确完成这位顾客的一份整单，收摊保存后，即可把这次相遇留在手账里。", new(330, 201, 393, 157), 27);
        var quote = CollectionPaper(_collectionDetail, new(322, 375, 416, 100));
        quote.Fill = new("#F8EACF"); quote.Ink = new("#DEC69E");
        Text(quote, "QuotationMark", "“", new(12, 2, 44, 58), 62).AddThemeColorOverride("font_color", new Color("#B98046"));
        Text(_collectionDetail, "CustomerSaying", stats.Known ? card.Saying : "每一张陌生面孔，都可能成为熟客。", new(373, 384, 347, 78), 26);
        CollectionPaper(_collectionDetail, new(0, 499, 747, 146));
        CustomerDetailIcon(_collectionDetail, "BookUI/奖励章中心符号｜星星", new(21, 505, 43, 43), -10);
        Text(_collectionDetail, "StoryTitle", "街坊趣闻", new(80, 506, 642, 38), 29);
        Text(_collectionDetail, "CustomerStory", stats.StoryUnlocked ? card.Anecdote : $"再正确接待 {3 - stats.Served} 次，就能听到这位朋友的小故事。", new(22, 552, 700, 75), 26);
        CollectionPaper(_collectionDetail, new(0, 667, 347, 170));
        CustomerDetailIcon(_collectionDetail, "StartPage/日历", new(21, 678, 39, 39), -5);
        Text(_collectionDetail, "RecordTitle", "我的记录", new(72, 679, 252, 38), 29);
        Text(_collectionDetail, "CustomerFirst", stats.Known ? $"初遇 · {JourneyModel.City(stats.FirstCity).Name} · 第 {stats.FirstDay} 天" : "尚未留下接待记录", new(21, 727, 303, 42), 22);
        Text(_collectionDetail, "CustomerServed", $"正确接待：{stats.Served} 次", new(21, 782, 303, 33), 24);
        CollectionPaper(_collectionDetail, new(367, 667, 380, 170));
        Text(_collectionDetail, "StampsTitle", "从初遇到熟客", new(387, 679, 340, 38), 29);
        CollectionStamp("CustomerFirstStamp", "初遇", "接待1次", new(381, 717), stats.Known, new("#D6533C"));
        CollectionStamp("CustomerStoryStamp", "趣闻", "接待3次", new(499, 717), stats.StoryUnlocked, new("#B57716"));
        CollectionStamp("CustomerRegularStamp", "熟客", "接待5次", new(617, 717), stats.Regular, new("#8C6743"));
    }
}
