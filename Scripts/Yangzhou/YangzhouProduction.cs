using ProjectCake.Xian;

namespace ProjectCake.Yangzhou;

public enum YangzhouQuality { Perfect, Good, Poor }
public sealed record YangzhouFood(string ProductId, YangzhouQuality Quality = YangzhouQuality.Perfect);

public sealed class YangzhouCutting
{
    public YangzhouCutting(YangzhouBoardData data) => Data = data;
    public YangzhouBoardData Data { get; }
    public bool Cutting { get; private set; }
    public double Progress { get; private set; }
    public int Portions { get; private set; }
    private double _time, _distance;
    private int _direction, _reversals;
    public bool TryStart(RefillableStock raw)
    {
        if (Cutting || Portions >= Data.Capacity || !raw.TryConsume(1)) return false;
        Cutting = true; Progress = _time = _distance = 0; _direction = _reversals = 0; return true;
    }
    // Time alone and a single teleport cannot complete cutting. Only pointer motion accrues work.
    public void Stroke(double dx, double seconds)
    {
        if (!Cutting || !double.IsFinite(dx) || seconds <= 0 || Math.Abs(dx) < 2) return;
        int direction = Math.Sign(dx);
        if (_direction != 0 && _direction != direction) _reversals++;
        _direction = direction; _distance += Math.Min(Math.Abs(dx), 100); _time += Math.Min(seconds, .1);
        Progress = Math.Min(Data.Snap, Math.Min(_time / Data.Seconds, _distance / 600) * Data.Snap);
        if (Progress + .000001 < Data.Snap || _reversals < 2) return;
        Portions = Math.Min(Data.Capacity, Portions + Data.Yield); Cutting = false; Progress = 1;
    }
    public bool TryTake() { if (Portions <= 0) return false; Portions--; return true; }
}

public sealed class YangzhouScalding
{
    public bool Loaded { get; private set; }
    public bool Immersed { get; private set; }
    public int Dips { get; private set; }
    public double ImmersionSeconds { get; private set; }
    public double SeasonRemaining { get; private set; }
    public bool Seasoned { get; private set; }
    public bool Ready => Loaded && Seasoned;
    public YangzhouQuality Quality => Dips >= 3 ? YangzhouQuality.Perfect : Dips == 2 ? YangzhouQuality.Good : YangzhouQuality.Poor;
    public bool TryLoad(YangzhouCutting board)
    {
        if (Loaded || !board.TryTake()) return false;
        Loaded = true; Dips = 0; ImmersionSeconds = SeasonRemaining = 0; Seasoned = false; return true;
    }
    public bool Dip()
    {
        if (!Loaded || Immersed || Dips >= 3 || Seasoned || SeasonRemaining > 0) return false;
        Immersed = true; ImmersionSeconds = 0; return true;
    }
    public bool Lift()
    {
        if (!Immersed) return false;
        bool valid = ImmersionSeconds + .000001 >= .3;
        Immersed = false; ImmersionSeconds = 0; if (valid) Dips++; return valid;
    }
    public void CancelGesture() { Immersed = false; ImmersionSeconds = 0; }
    public bool Season(RefillableStock stock)
    {
        if (!Loaded || Dips == 0 || Immersed || Seasoned || SeasonRemaining > 0 || !stock.TryConsume(1)) return false;
        SeasonRemaining = .3; return true;
    }
    public void Tick(double delta)
    {
        if (delta <= 0) return;
        if (Immersed) ImmersionSeconds += delta;
        if (SeasonRemaining > 0) { SeasonRemaining = Math.Max(0, SeasonRemaining - delta); if (SeasonRemaining == 0) Seasoned = true; }
    }
    public bool TryTake(out YangzhouFood food)
    {
        food = new("G01", Quality); if (!Ready) return false;
        Loaded = Seasoned = Immersed = false; Dips = 0; return true;
    }
}

public enum YangzhouSteamState { Empty, Loaded, Steaming, Ready, Open }
public sealed class YangzhouSteamer
{
    public YangzhouSteamer(YangzhouSteamerData data) => Data = data;
    public YangzhouSteamerData Data { get; }
    public YangzhouSteamState State { get; private set; }
    public string ProductId { get; private set; } = "";
    public int Quantity { get; private set; }
    public double Elapsed { get; private set; }
    public double CookSeconds => ProductId == "B01" ? Data.BunSeconds : Data.SiumaiSeconds;
    public YangzhouQuality Quality => Data.Hold || Elapsed < (ProductId == "B01" ? 10 : 8.5) ? YangzhouQuality.Perfect
        : Elapsed < (ProductId == "B01" ? 13 : 11) ? YangzhouQuality.Good : YangzhouQuality.Poor;
    public bool Holding => Data.Hold && State == YangzhouSteamState.Ready && Elapsed >= (Data.Level == 2 ? (ProductId == "B01" ? 8 : 6.5) : CookSeconds);
    public bool Load(string productId, int quantity, RefillableStock raw)
    {
        if (State is not (YangzhouSteamState.Empty or YangzhouSteamState.Loaded) || productId is not ("B01" or "B02")
            || quantity <= 0 || Quantity + quantity > Data.Capacity || Quantity > 0 && ProductId != productId || !raw.TryConsume(quantity)) return false;
        ProductId = productId; Quantity += quantity; State = YangzhouSteamState.Loaded; return true;
    }
    public bool Start()
    {
        if (State != YangzhouSteamState.Loaded) return false;
        Elapsed = 0; State = YangzhouSteamState.Steaming; return true;
    }
    public void Tick(double delta)
    {
        if (delta <= 0 || State is not (YangzhouSteamState.Steaming or YangzhouSteamState.Ready)) return;
        Elapsed += delta;
        if (Data.Hold) Elapsed = Math.Min(Elapsed, Data.Level == 2 ? ProductId == "B01" ? 8 : 6.5 : CookSeconds);
        if (Elapsed + .000001 >= CookSeconds) State = YangzhouSteamState.Ready;
    }
    public bool Open() { if (State != YangzhouSteamState.Ready) return false; State = YangzhouSteamState.Open; return true; }
    public bool Collect(Queue<YangzhouFood> stock)
    {
        if (State != YangzhouSteamState.Open || stock.Count + Quantity > Data.Capacity) return false;
        for (int i = 0; i < Quantity; i++) stock.Enqueue(new(ProductId, Quality));
        Quantity = 0; ProductId = ""; Elapsed = 0; State = YangzhouSteamState.Empty; return true;
    }
}

public sealed class YangzhouKitchen
{
    public YangzhouKitchen(YangzhouCatalog catalog, int day, int boardLevel, int steamerLevel)
    {
        Day = day; Board = new(catalog.Boards.Single(b => b.Level == Math.Clamp(boardLevel, 1, 3)));
        var data = catalog.Steamers.Single(b => b.Level == Math.Clamp(steamerLevel, 1, 3));
        Steamers = day < 3 ? Array.Empty<YangzhouSteamer>() : Enumerable.Range(0, data.Layers).Select(_ => new YangzhouSteamer(data)).ToArray();
    }
    public int Day { get; }
    public YangzhouCutting Board { get; }
    public YangzhouScalding Scald { get; } = new();
    public YangzhouSteamer[] Steamers { get; }
    public RefillableStock Tofu { get; } = new(3, .8);
    public RefillableStock RawBuns { get; } = new(12, .8);
    public RefillableStock RawSiumai { get; } = new(12, .8);
    public RefillableStock Seasoning { get; } = new(8, .6);
    public RefillableStock Tea { get; } = new(6, .6);
    public Queue<YangzhouFood> Buns { get; } = new();
    public Queue<YangzhouFood> Siumai { get; } = new();
    public double TeaRemaining { get; private set; }
    public bool TeaReady { get; private set; }
    public bool TakeTea()
    {
        if (Day < 2 || TeaReady || TeaRemaining > 0 || !Tea.TryConsume(1)) return false;
        TeaRemaining = .3; return true;
    }
    public void Tick(double delta)
    {
        Tofu.Tick(delta); RawBuns.Tick(delta); RawSiumai.Tick(delta); Seasoning.Tick(delta); Tea.Tick(delta); Scald.Tick(delta);
        foreach (var steamer in Steamers) steamer.Tick(delta);
        if (TeaRemaining > 0) { TeaRemaining = Math.Max(0, TeaRemaining - delta); if (TeaRemaining == 0) TeaReady = true; }
    }
    public bool HasFood(string id) => id switch { "G01" => Scald.Ready, "B01" => Buns.Count > 0, "B02" => Siumai.Count > 0, "T01" => TeaReady, _ => false };
    public bool TryTake(string id, out YangzhouFood food)
    {
        food = new(id);
        if (id == "G01") return Scald.TryTake(out food);
        if (id == "B01" && Buns.TryDequeue(out var bun)) { food = bun; return true; }
        if (id == "B02" && Siumai.TryDequeue(out var siumai)) { food = siumai; return true; }
        if (id == "T01" && TeaReady) { TeaReady = false; return true; }
        return false;
    }
}
