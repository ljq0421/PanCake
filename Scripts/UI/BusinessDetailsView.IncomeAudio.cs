using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private AudioStreamPlayer? _incomeAudio;
    private int _countedIncome;
    private ulong? _lastIncomeSound;
    private bool _incomeAudioFocused = true;

    private void SetCountingIncome(int amount)
    {
        bool increased = amount > _countedIncome;
        _countedIncome = amount;
        _income.Text = $"¥{amount}";
        if (!increased || !_incomeAudioFocused || !IsVisibleInTree()) return;
        ulong now = Time.GetTicksMsec();
        if (_lastIncomeSound is { } last && now - last < 160) return;
        _lastIncomeSound = now;
        if (_incomeAudio is null)
        {
            _incomeAudio = new AudioStreamPlayer
            {
                Name = "IncomeCountAudio", Bus = JourneySettings.EffectsBus,
                VolumeDb = -16, MaxPolyphony = 2,
                Stream = BusinessFeedbackAudio.Make(ProjectCake.Gameplay.BusinessCue.CoinCredited)
            };
            AddChild(_incomeAudio);
        }
        _incomeAudio.Play();
    }

    private void StopIncomeAudio()
    {
        _incomeAudio?.Stop();
        _countedIncome = 0;
        _lastIncomeSound = null;
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut)
        {
            _incomeAudioFocused = false;
            _incomeAudio?.Stop();
        }
        if (what == NotificationApplicationFocusIn) _incomeAudioFocused = true;
    }
}
