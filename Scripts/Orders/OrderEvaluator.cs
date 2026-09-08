using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.Orders;

public sealed class OrderEvaluator
{
    public DeliveryEvaluation EvaluateCompletedGuangzhou(OrderProgress progress, double waitRatio, CustomerTypeData type)
    {
        if (!progress.IsComplete) return new(DeliveryGrade.Incomplete, 0, 0, 0, "还缺少商品。", true);
        int waiting = waitRatio <= .30 ? 0 : waitRatio <= .60 ? 5 : waitRatio < .84 ? 15 : 30;
        int score = Math.Clamp(100 - waiting - (progress.HasRecipeMismatch ? 20 : 0) - (progress.HasRiceRollDry ? 10 : 0)
            - (progress.HasRiceRollBroken ? 5 : 0) - (progress.HasDimSumOversteamed ? 5 : 0), 0, 100);
        bool perfect = waitRatio <= .30 && !progress.HasRecipeMismatch && !progress.HasQualityIssue;
        int revenue = progress.HasRecipeMismatch ? RoundSeventyPercent(progress.Order.BasePrice) : progress.Order.BasePrice;
        int tip = perfect ? (int)Math.Ceiling(progress.Order.BasePrice * (double)Math.Round(type.PerfectTipRate, 4)) : 0;
        var grade = progress.HasRecipeMismatch ? DeliveryGrade.Incorrect : perfect ? DeliveryGrade.Perfect : DeliveryGrade.Correct;
        return new(grade, revenue, tip, score, perfect ? $"Perfect！小费 ¥{tip}" : progress.HasRecipeMismatch
            ? $"配料有误 · 整单七折 ¥{revenue} · 满意度 {score}" : $"出餐完成 · 满意度 {score}", true);
    }

    public DeliveryEvaluation EvaluateCompletedXian(OrderProgress progress, double waitRatio, CustomerTypeData type)
    {
        if (!progress.IsComplete) return new(DeliveryGrade.Incomplete, 0, 0, 0, "还缺少商品。", true);
        int waiting = waitRatio <= .30 ? 0 : waitRatio <= .60 ? 5 : waitRatio < .84 ? 15 : 30;
        int score = Math.Clamp(100 - waiting - (progress.HasMeatMismatch ? 20 : 0) - (progress.HasJuiceMismatch ? 20 : 0) - (progress.HasBunOverbrowned ? 5 : 0), 0, 100);
        bool perfect = waitRatio <= .30 && !progress.HasRecipeMismatch && !progress.HasBunOverbrowned;
        int revenue = progress.HasRecipeMismatch ? RoundSeventyPercent(progress.Order.BasePrice) : progress.Order.BasePrice;
        int tip = perfect ? (int)Math.Ceiling(progress.Order.BasePrice * type.PerfectTipRate) : 0;
        var grade = progress.HasRecipeMismatch ? DeliveryGrade.Incorrect : perfect ? DeliveryGrade.Perfect : DeliveryGrade.Correct;
        return new(grade, revenue, tip, score, perfect ? $"Perfect！小费 ¥{tip}" : progress.HasRecipeMismatch ? $"配方有误，整单七折 ¥{revenue} · 满意度 {score}" : $"出餐完成 · 满意度 {score}", true);
    }

    public DeliveryEvaluation EvaluateCompletedWuhan(OrderProgress progress, double waitRatio, CustomerTypeData customerType)
    {
        if (!progress.IsComplete) return new DeliveryEvaluation(DeliveryGrade.Incomplete, 0, 0, 0, "订单还缺少商品。", true);
        int waitPenalty = waitRatio <= .30 ? 0 : waitRatio <= .60 ? 5 : waitRatio < .84 ? 15 : 30;
        int issuePenalty = (progress.HasRecipeMismatch ? 20 : 0)
            + (progress.HasNoodlesOvercooked ? 10 : 0)
            + (progress.HasDoupiOverbrowned ? 5 : 0);
        int satisfaction = Math.Clamp(100 - waitPenalty - issuePenalty, 0, 100);
        int revenue = progress.HasRecipeMismatch ? RoundSeventyPercent(progress.Order.BasePrice) : progress.Order.BasePrice;
        bool perfect = waitRatio <= .30 && !progress.HasRecipeMismatch && !progress.HasNoodlesSoft
            && !progress.HasNoodlesOvercooked && !progress.HasDoupiOverbrowned && progress.AllNoodlesMixed;
        if (perfect)
        {
            int tip = (int)Math.Ceiling(progress.Order.BasePrice * customerType.PerfectTipRate);
            return new DeliveryEvaluation(DeliveryGrade.Perfect, revenue, tip, satisfaction, $"Perfect！获得 ¥{tip} 小费。", true);
        }
        DeliveryGrade grade = progress.HasRecipeMismatch ? DeliveryGrade.Incorrect : DeliveryGrade.Correct;
        string message = progress.HasRecipeMismatch ? $"配方错误，整单按 70% 结算 ¥{revenue}，满意度 {satisfaction}。" : $"订单完成，满意度 {satisfaction}。";
        return new DeliveryEvaluation(grade, revenue, 0, satisfaction, message, true);
    }

    public DeliveryEvaluation EvaluateCompleted(OrderProgress progress, CustomerState customerState, CustomerTypeData customerType)
    {
        if (!progress.IsComplete)
        {
            return new DeliveryEvaluation(DeliveryGrade.Incomplete, 0, 0, 0, "订单还缺少商品。", true);
        }

        if (progress.HasRecipeMismatch)
        {
            int revenue = RoundSeventyPercent(progress.Order.BasePrice);
            return new DeliveryEvaluation(DeliveryGrade.Incorrect, revenue, 0, 55, $"配方错误，整单按 70% 结算 ¥{revenue}。", true);
        }

        if (progress.HasQualityIssue || customerState != CustomerState.Happy)
        {
            return new DeliveryEvaluation(DeliveryGrade.Correct, progress.Order.BasePrice, 0, 85, "订单正确完成。", true);
        }

        int tip = (int)Math.Ceiling(progress.Order.BasePrice * customerType.PerfectTipRate);
        return new DeliveryEvaluation(DeliveryGrade.Perfect, progress.Order.BasePrice, tip, 100, $"Perfect！获得 ¥{tip} 小费。", true);
    }

    public DeliveryEvaluation Evaluate(
        OrderData order,
        CustomerState customerState,
        PreparedPancake pancake,
        RecipeData target,
        double perfectTipRate = 0.10)
    {
        if (pancake.Quality == PancakeQuality.Burnt)
        {
            return new DeliveryEvaluation(DeliveryGrade.Rejected, 0, 0, 0, "焦糊煎饼不能交付。");
        }

        bool matches = pancake.ExtraIngredients.SetEquals(target.ExtraIngredients);
        if (!matches)
        {
            int revenue = RoundSeventyPercent(order.BasePrice);
            return new DeliveryEvaluation(DeliveryGrade.Incorrect, revenue, 0, 55, $"配料错误，按 70% 结算 ¥{revenue}。");
        }

        if (pancake.Quality == PancakeQuality.Perfect && customerState == CustomerState.Happy)
        {
            int tip = (int)Math.Ceiling(order.BasePrice * perfectTipRate);
            return new DeliveryEvaluation(DeliveryGrade.Perfect, order.BasePrice, tip, 100, $"Perfect！获得 ¥{tip} 小费。");
        }

        return new DeliveryEvaluation(DeliveryGrade.Correct, order.BasePrice, 0, 85, "订单正确完成。");
    }

    private static int RoundSeventyPercent(int value) => (int)Math.Floor(value * 0.70 + 0.5);
}
