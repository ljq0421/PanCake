using Godot;

namespace ProjectCake.UI;

/// <summary>Audition-approved clips shared by the Tianjin and Wuhan action players.</summary>
internal static class CartoonActionClips
{
    internal const string PickUp = "res://resource/audio/sfx/action-pickup-k01.wav";
    internal const string Drop = "res://resource/audio/sfx/action-drop-k02.wav";
    internal const string Mix = "res://resource/audio/sfx/action-mix-k03.wav";
    internal const string Error = "res://resource/audio/sfx/action-error-k07.wav";
    internal static AudioStreamWav Load(string path) => GD.Load<AudioStreamWav>(path);
}
