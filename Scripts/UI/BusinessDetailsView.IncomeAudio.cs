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
                // The revenue counter represents coins being tallied, rather than a generic UI confirmation.
                // Reuse the approved metal-coin credit clip so this read is distinct from other book cues.
                VolumeDb = -10, MaxPolyphony = 2,
                Stream = GD.Load<AudioStreamWav>(BusinessFeedbackAudio.CartoonCoinPath)
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
            _newCityAudio?.Stop();
        }
        if (what == NotificationApplicationFocusIn) _incomeAudioFocused = true;
    }
}
