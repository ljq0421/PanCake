namespace ProjectCake.Yangzhou;

public sealed record YangzhouOrderRecord(int Id, string Customer, string CustomerType, string TemplateId,
    bool Lost, bool Unreceived, bool Perfect, int Mistakes, int Sales, int Tips, double? Satisfaction);

public enum YangzhouPhase { Prep, Running, Closing, Results }
public sealed record YangzhouResult(int Day, int Planned, int Completed, int Lost, int Sales, int Tips, double Satisfaction, int PerfectOrders, int PerfectGansi)
{
    public int Revenue => Sales + Tips;
    public int Stars => Day != 12 ? 0 : Completed >= 18 && Satisfaction >= 90 && PerfectGansi >= 10 ? 3 : Completed >= 17 && Satisfaction >= 82 ? 2 : Completed >= 14 && Satisfaction >= 70 ? 1 : 0;
}

/// <summary>Whole-tray service, prep time and city-specific pressure rules share one deterministic clock.</summary>
public sealed class YangzhouSession
{
    private readonly YangzhouCatalog _catalog;
    private readonly List<YangzhouOrder> _waiting = new(), _served = new();
    private readonly List<YangzhouOrderRecord> _records = new();
    public IReadOnlyList<YangzhouOrderRecord> BusinessRecords => _records.AsReadOnly();
    private void Record(YangzhouOrder o, bool lost) => _records.Add(new(o.Plan.Id, o.Type.Name, o.Type.Id,
        o.Template.Id, lost, false, !lost && o.Perfect, o.Mistakes, lost ? 0 : o.Price, lost ? 0 : o.Tip, lost ? null : o.Satisfaction));
    private int _next, _lost, _prepBatches;
    private double _delay, _nextAt;
    public YangzhouSession(YangzhouCatalog catalog, int day, int boardLevel, int steamerLevel)
    {
        _catalog = catalog; Day = catalog.Day(day); Kitchen = new(catalog, day, boardLevel, steamerLevel);
        Plan = YangzhouOrderGenerator.Generate(catalog, Day); _nextAt = Plan[0].Arrival;
    }
    public YangzhouDay Day { get; }
    public YangzhouKitchen Kitchen { get; }
    public IReadOnlyList<YangzhouPlannedOrder> Plan { get; }
    public IReadOnlyList<YangzhouOrder> Waiting => _waiting;
    public IReadOnlyList<YangzhouOrder> Served => _served;
    public YangzhouOrder? Selected => _waiting.FirstOrDefault(o => o.Plan.Id == SelectedId);
    public int SelectedId { get; private set; }
    public YangzhouPhase Phase { get; private set; }
    public bool Paused { get; private set; }
    public double PrepRemaining { get; private set; } = 5;
    public double Elapsed { get; private set; }
    public double ClosingRemaining { get; private set; } = 15;
    public int PressureDelays { get; private set; }
    public double CurrentDelay => _delay;
    public bool CanWork => !Paused && Phase != YangzhouPhase.Results;
    public int Revenue => _served.Sum(o => o.Price + o.Tip);
    public void Select(int id) { if (CanWork && _waiting.Any(o => o.Plan.Id == id)) SelectedId = id; }
    public void Pause(bool paused) { Paused = paused; Kitchen.Scald.CancelGesture(); }
    public bool Cut() => CanWork && Kitchen.Board.TryStart(Kitchen.Tofu);
    public void Stroke(double dx, double seconds) { if (CanWork) Kitchen.Board.Stroke(dx, seconds); }
    public bool LoadGansi() => CanWork && Kitchen.Scald.TryLoad(Kitchen.Board);
    public bool Dip() => CanWork && Kitchen.Scald.Dip();
    public bool Lift() => CanWork && Kitchen.Scald.Lift();
    public bool Season() => CanWork && Kitchen.Scald.Season(Kitchen.Seasoning);
    public bool TakeTea() => CanWork && Kitchen.TakeTea();
    public bool Refill(string id) => CanWork && id switch
    {
        "tofu" => Kitchen.Tofu.TryRefill(), "B01" when Day.Day >= 3 => Kitchen.RawBuns.TryRefill(),
        "B02" when Day.Day >= 5 => Kitchen.RawSiumai.TryRefill(), "season" => Kitchen.Seasoning.TryRefill(),
        "T01" when Day.Day >= 2 => Kitchen.Tea.TryRefill(), _ => false,
    };
    public bool LoadSteamer(int layer, string product, int quantity)
    {
        if (!CanWork || layer < 0 || layer >= Kitchen.Steamers.Length || product is not ("B01" or "B02") || product == "B02" && Day.Day < 5) return false;
        var steamer = Kitchen.Steamers[layer];
        if (Phase == YangzhouPhase.Prep && steamer.State == YangzhouSteamState.Empty && _prepBatches >= 1) return false;
        bool empty = steamer.State == YangzhouSteamState.Empty;
        if (!steamer.Load(product, quantity, product == "B01" ? Kitchen.RawBuns : Kitchen.RawSiumai)) return false;
        if (Phase == YangzhouPhase.Prep && empty) _prepBatches++;
        return true;
    }
    public bool SteamAction(int layer)
    {
        if (!CanWork || layer < 0 || layer >= Kitchen.Steamers.Length) return false;
        var steamer = Kitchen.Steamers[layer];
        return steamer.State switch
        {
            YangzhouSteamState.Loaded => steamer.Start(), YangzhouSteamState.Ready => steamer.Open(),
            YangzhouSteamState.Open => steamer.Collect(steamer.ProductId == "B01" ? Kitchen.Buns : Kitchen.Siumai), _ => false,
        };
    }
    public bool Stage(string product) => CanWork && Selected?.Stage(product, Kitchen) == true;
    public bool Serve()
    {
        var order = Selected;
        if (!CanWork || order is null || !order.Serve()) return false;
        Record(order, false); _served.Add(order); _waiting.Remove(order); SelectFirst(); return true;
    }
    public void Tick(double seconds)
    {
        if (!CanWork || seconds <= 0 || !double.IsFinite(seconds)) return;
        // Bounded steps keep prep/closing transitions and pressure rules invariant under low frame rates.
        while (seconds > .000001 && Phase != YangzhouPhase.Results)
        {
            double dt = Math.Min(.05, seconds); Step(dt); seconds -= dt;
        }
    }
    private void Step(double dt)
    {
        Kitchen.Tick(dt);
        if (Phase == YangzhouPhase.Prep)
        {
            PrepRemaining = Math.Max(0, PrepRemaining - dt);
            if (PrepRemaining < .000001) { PrepRemaining = 0; Phase = YangzhouPhase.Running; }
            return;
        }
        foreach (var order in _waiting.ToArray())
        {
            order.Tick(dt, Day.Day == 1);
            if (Day.Day != 1 && order.WaitRatio >= 1) { Record(order, true); order.Lose(); _waiting.Remove(order); _lost++; }
        }
        SelectFirst();
        if (Phase == YangzhouPhase.Running)
        {
            Elapsed = Math.Min(Day.Duration, Elapsed + dt);
            Arrive();
            if (Elapsed + .000001 >= Day.Duration) Phase = YangzhouPhase.Closing;
        }
        else if (Phase == YangzhouPhase.Closing)
        {
            if (Day.Day == 1) Arrive(true); // Tutorial customers never fail; complete the last trays at your own pace.
            else ClosingRemaining = Math.Max(0, ClosingRemaining - dt);
            if (_waiting.Count == 0 && _next == Plan.Count) Phase = YangzhouPhase.Results;
            else if (Day.Day != 1 && ClosingRemaining < .000001)
            {
                foreach (var order in _waiting) { Record(order, true); order.Lose(); }
                foreach (var pending in Plan.Skip(_next)) _records.Add(new(pending.Id, _catalog.Customer(pending.CustomerId).Name,
                    pending.CustomerId, pending.TemplateId, true, true, false, 0, 0, 0, null));
                _lost += _waiting.Count + Plan.Count - _next; _waiting.Clear(); _next = Plan.Count; Phase = YangzhouPhase.Results;
            }
        }
    }
    private void Arrive(bool tutorialClosing = false)
    {
        if (_next >= Plan.Count || _waiting.Count >= 5 || (!tutorialClosing && Elapsed + .000001 < _nextAt)) return;
        var next = Plan[_next];
        if (Day.Day < 6 && next.TemplateId == "K" && _waiting.Any(o => o.Template.Id == "K")) return;
        int complex = _waiting.Count(o => o.Template.Complex);
        bool pressure = complex >= 2 || complex >= 1 && _waiting.Any(o => o.Template.Large);
        if (!tutorialClosing && pressure && _delay < 4)
        {
            _delay += 2; PressureDelays++; _nextAt = Elapsed + 2; return;
        }
        _waiting.Add(new(next, _catalog, Day.Day == 1)); _next++;
        _delay = 0; _nextAt = _next < Plan.Count ? Math.Max(Plan[_next].Arrival, Elapsed + .25) : double.PositiveInfinity; SelectFirst();
    }
    private void SelectFirst() { if (Selected is null) SelectedId = _waiting.FirstOrDefault()?.Plan.Id ?? 0; }
    public YangzhouResult Result() => new(Day.Day, Day.Customers, _served.Count, _lost, _served.Sum(o => o.Price), _served.Sum(o => o.Tip),
        _served.Count == 0 ? 0 : _served.Average(o => o.Satisfaction), _served.Count(o => o.Perfect), _served.Sum(o => o.StagedItems.Count(f => f.ProductId == "G01" && f.Quality == YangzhouQuality.Perfect)));
}
