using Godot;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private void BuildNewCitySummary()
    {
        var r = _model.Result;
        TravelPanel(_summary, new(890, -65, 560, 180), emphasize: true);
        TravelHeading(_summary, "今日收入", new(905, -83, 245, 51));
        CaptureTravelMotion(TravelMotionGroup.Income, _summary, () =>
        {
            Art(_summary, "总收入图标", new(906, 0, 90, 90));
            _income = TravelValue(_summary, $"¥{r.TotalRevenue + _model.ChallengeReward}", new(1006, -2, 184, 96), 78);
            TravelPanel(_summary, new(1202, -25, 230, 124), true);
            string[] captions = { "菜品销售", "顾客小费", "挑战奖金" };
            string[] amounts = { $"¥{r.SaleRevenue}", $"+¥{r.Tips}", $"+¥{_model.ChallengeReward}" };
            for (int i = 0; i < 3; i++)
            {
                TravelValue(_summary, captions[i], new(1212, -18 + i * 38, 105, 32), 22, color: Muted);
                var amount = TravelValue(_summary, amounts[i], new(1320, -18 + i * 38, 102, 32), 26, HorizontalAlignment.Right);
                if (i == 2) amount.Name = "ChallengeRewardAmount";
            }
        });

        TravelPanel(_summary, new(890, 145, 560, 95));
        TravelHeading(_summary, "挑战结果", new(905, 127, 245, 47));
        CaptureTravelMotion(TravelMotionGroup.Challenge, _summary, () =>
        {
            bool hasChallenge = _model.Challenge is not null;
            if (hasChallenge)
            {
                string asset = _model.Challenge!.Achieved(r) ? "挑战完成" : "挑战失败";
                Picture(_summary, GD.Load<Texture2D>(JourneyModel.ArtRoot + asset + ".png"), new(910, 174, 62, 62)).Name = "ChallengeResultIcon";
            }
            Text(_summary, hasChallenge ? _model.ChallengeCaption : "今日暂无挑战",
                new(hasChallenge ? 985 : 915, 177, hasChallenge ? 445 : 510, 58), 23, wrap: true).Name = "ChallengeSettlement";
        });

        var unlock = ButtonAt(_summary, "", new(890, 254, 560, 198), RequestNewJourney);
        unlock.Name = "NewCityUnlock";
        unlock.TooltipText = "展开新旅程 · 查看武汉解锁";
        unlock.Disabled = !_model.CanClose;
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
        {
            var box = TianjinUi.Box(new Color(state == "hover" ? "#FFE49B" : state == "pressed" ? "#F1CC7C" : "#FFF0BC"), 18, 3, false);
            box.BorderColor = new("#C08335");
            unlock.AddThemeStyleboxOverride(state, box);
        }
        Picture(unlock, GD.Load<Texture2D>(JourneyModel.ArtRoot + "武汉旅行明信片.png"), new(8, 40, 232, 148));
        Picture(unlock, GD.Load<Texture2D>(JourneyModel.ArtRoot + "Dayx背景.png"), new(232, 0, 320, 94));
        TravelValue(unlock, "新城市解锁！", new(263, 24, 240, 42), 34, HorizontalAlignment.Center, new Color("#AA4926"));
        TravelValue(unlock, "武汉", new(247, 91, 290, 51), 42);
        TravelValue(unlock, "点击展开新旅程", new(247, 155, 295, 32), 25, color: new Color("#875323"));

        AddTravelUpgradeButton();
        if (_upgradeEntry is not null)
        {
            unlock.FocusNext = unlock.GetPathTo(_upgradeEntry);
            _upgradeEntry.FocusPrevious = _upgradeEntry.GetPathTo(unlock);
            _upgradeEntry.FocusNext = _upgradeEntry.GetPathTo(CloseButton);
            CloseButton.FocusPrevious = CloseButton.GetPathTo(_upgradeEntry);
        }
    }
}
