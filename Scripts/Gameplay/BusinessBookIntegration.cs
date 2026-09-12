using Godot;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class XianDayScreen
{
    private BusinessBookSession _book = null!;
    internal BusinessDetailsView BusinessDetails => _book.View;
    private void BuildBusinessBook() => _book = new(this, this, new(1270, 18),
        () => CanInteract && !_surfaces.Values.Any(s => s.HasGesture),
        () => BusinessBookModel.From(StableIds.Cities.Xian, _controller.Ledger!.Build(), _controller.BusinessRecords, _catalog),
        paused => { if (_controller is not null) _controller.SetPauseReason("business-book", paused); if (paused) CancelGestures(); },
        () => HubRequested?.Invoke(), SaveResult);
}
public partial class GuangzhouDayScreen
{
    private BusinessBookSession _book = null!;
    internal BusinessDetailsView BusinessDetails => _book.View;
    private void BuildBusinessBook() => _book = new(this, _canvas, new(1250, 20),
        () => CanInteract && !_trays.Any(t => t.HasGesture),
        () => BusinessBookModel.From(StableIds.Cities.Guangzhou, _controller.Ledger!.Build(), _controller.BusinessRecords, _catalog),
        paused => { if (_controller is not null) _controller.SetPauseReason("business-book", paused); if (paused) CancelGestures(); },
        () => HubRequested?.Invoke(), CommitResult);
}

public partial class YangzhouDayScreen
{
    private BusinessBookSession _book = null!;
    internal BusinessDetailsView BusinessDetails => _book.View;
    private void BuildBusinessBook() => _book = new(this, _canvas, new(1260, 28),
        () => CanWork() && !this.Descendants<YangzhouSurface>().Any(s => s.HasGesture),
        () => YangzhouBusinessBook.Snapshot(Session, _catalog),
        paused => { if (paused) CancelGestures(); },
        () => HubRequested?.Invoke(), () => SaveResult());
}
