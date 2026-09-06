using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanVisualCapture : Node
{
    public override async void _Ready()
    {
        DataCatalog catalog=GetNode<DataCatalog>("/root/DataCatalog");
        string savePath=$"user://wuhan-capture-{Guid.NewGuid():N}.json";var save=new SaveService();AddChild(save);save.UsePathForTests(savePath);save.Data.Coins=3000;
        CityProgressData progress=save.Data.Wuhan;progress.HighestUnlockedDay=12;progress.EquipmentLevels["noodle_cooker"]=3;progress.EquipmentLevels["ingredient_station"]=3;progress.EquipmentLevels["doupi_griddle"]=3;progress.EquipmentLevels["egg_rice_wine_station"]=1;
        var hub=new WuhanHub();AddChild(hub);hub.Initialize(catalog,save);await Frames(3);Save("res://.tmp/wuhan_hub.png");hub.QueueFree();await Frames(2);
        var controller=new DayController();AddChild(controller);var day=new WuhanDayScreen();AddChild(day);day.ConnectController(controller);day.Initialize(catalog,save,controller,8);day.BeginDay();controller.Tick(3.1);controller.Tick(32);await Frames(3);Save("res://.tmp/wuhan_day8.png");
        string absolute=ProjectSettings.GlobalizePath(savePath);if(File.Exists(absolute))File.Delete(absolute);GD.Print("WUHAN_CAPTURE_DONE");GetTree().Quit();
    }
    private async Task Frames(int count){for(int i=0;i<count;i++)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);}
    private void Save(string path){Directory.CreateDirectory(Path.GetDirectoryName(ProjectSettings.GlobalizePath(path))!);GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath(path));}
}
