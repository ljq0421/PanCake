using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.Orders;

public sealed class OrderEvaluator
{
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
