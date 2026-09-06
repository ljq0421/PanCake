using ProjectCake.Data;
using ProjectCake.Orders;

namespace ProjectCake.Customers;

public sealed class CustomerQueue
{
    public const double MaxArrivalDelaySeconds = 3.0;
    public const double EnterDurationSeconds = 0.35;
    public const double LeaveDurationSeconds = 0.45;

    private readonly DayPlan _plan;
    private readonly IReadOnlyDictionary<string, CustomerTypeData> _types;
    private readonly double _patienceMultiplier;
    private readonly int _capacity;
    private readonly List<CustomerRuntime> _slots = new();
    private readonly Queue<CustomerRuntime> _pending = new();
    private int _nextPlanIndex;
    private readonly double _pressureDelaySeconds;
    private readonly double _maxPressureDelaySeconds;
    private int _pressurePlanIndex = -1;
    private double _pressureDelayApplied;
    private double _pressureBlockedUntil;

    public CustomerQueue(DayPlan plan, IReadOnlyDictionary<string, CustomerTypeData> types, double patienceMultiplier, int capacity, double pressureDelaySeconds = 0, double maxPressureDelaySeconds = 0)
    {
        _plan = plan;
        _types = types;
        _patienceMultiplier = patienceMultiplier;
        _capacity = capacity;
        _pressureDelaySeconds = pressureDelaySeconds;
        _maxPressureDelaySeconds = maxPressureDelaySeconds;
    }

    public event Action<CustomerRuntime>? CustomerEntered;
    public event Action<CustomerRuntime>? CustomerLost;
    public event Action<CustomerRuntime>? CustomerRemoved;
    public event Action? Changed;

    public IReadOnlyList<CustomerRuntime> Slots => _slots;
    public IReadOnlyCollection<CustomerRuntime> DoorQueue => _pending.ToArray();
    public string? SelectedCustomerId { get; private set; }
    public CustomerRuntime? SelectedCustomer => _slots.FirstOrDefault(customer => customer.Id == SelectedCustomerId);
    public bool HasUnscheduled => _nextPlanIndex < _plan.Customers.Count;
    public bool IsResolved => !HasUnscheduled && _pending.Count == 0 && _slots.Count == 0;

    public void Tick(double dayElapsedSeconds, double deltaSeconds, bool acceptArrivals)
    {
        bool changed = false;
        if (acceptArrivals)
        {
            while (_nextPlanIndex < _plan.Customers.Count && _plan.Customers[_nextPlanIndex].ArrivalTime <= dayElapsedSeconds)
            {
                if (_maxPressureDelaySeconds > 0 && _slots.Count + _pending.Count >= _capacity) break;
                if (_pressurePlanIndex != _nextPlanIndex)
                {
                    _pressurePlanIndex = _nextPlanIndex; _pressureDelayApplied = 0; _pressureBlockedUntil = 0;
                }
                if (dayElapsedSeconds < _pressureBlockedUntil) break;
                if (IsUnderComplexPressure() && _pressureDelaySeconds > 0 && _pressureDelayApplied < _maxPressureDelaySeconds)
                {
                    double delay = Math.Min(_pressureDelaySeconds, _maxPressureDelaySeconds - _pressureDelayApplied);
                    _pressureDelayApplied += delay;
                    _pressureBlockedUntil = dayElapsedSeconds + delay;
                    break;
                }
                PlannedCustomer plan = _plan.Customers[_nextPlanIndex++];
                _pending.Enqueue(new CustomerRuntime(plan, _types[plan.CustomerTypeId], _patienceMultiplier));
                _pressurePlanIndex = -1;
                changed = true;
                changed |= AdmitPending();
            }
        }

        foreach (CustomerRuntime customer in _pending)
        {
            if (customer.State == CustomerState.ArrivalDelayed)
            {
                customer.ArrivalDelaySeconds += deltaSeconds;
                if (customer.ArrivalDelaySeconds >= MaxArrivalDelaySeconds)
                {
                    customer.State = CustomerState.DoorWaiting;
                    changed = true;
                }
            }
        }

        changed |= AdmitPending();

        foreach (CustomerRuntime customer in _slots.ToArray())
        {
            if (customer.State == CustomerState.Leaving)
            {
                customer.PhaseSeconds += deltaSeconds;
                if (customer.PhaseSeconds >= LeaveDurationSeconds)
                {
                    customer.State = CustomerState.Left;
                    _slots.Remove(customer);
                    if (SelectedCustomerId == customer.Id)
                    {
                        SelectedCustomerId = null;
                    }
                    CustomerRemoved?.Invoke(customer);
                    changed = true;
                }
                continue;
            }

            if (customer.Tick(deltaSeconds))
            {
                if (SelectedCustomerId == customer.Id)
                {
                    SelectedCustomerId = null;
                }
                CustomerLost?.Invoke(customer);
                changed = true;
            }
        }

        changed |= AdmitPending();

        if (changed)
        {
            Changed?.Invoke();
        }
    }

    public bool TrySelect(string customerId)
    {
        CustomerRuntime? customer = _slots.FirstOrDefault(candidate => candidate.Id == customerId);
        if (customer is null || customer.State is CustomerState.Entering or CustomerState.Leaving or CustomerState.Served)
        {
            return false;
        }

        SelectedCustomerId = customerId;
        Changed?.Invoke();
        return true;
    }

    public bool TryMarkServed(string customerId)
    {
        CustomerRuntime? customer = _slots.FirstOrDefault(candidate => candidate.Id == customerId);
        if (customer is null || customer.State is not (CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry))
        {
            return false;
        }

        customer.WasServed = true;
        customer.State = CustomerState.Leaving;
        customer.PhaseSeconds = 0;
        customer.Order.Status = OrderStatus.Completed;
        if (SelectedCustomerId == customerId)
        {
            SelectedCustomerId = null;
        }
        Changed?.Invoke();
        return true;
    }

    public IReadOnlyList<CustomerRuntime> ForceLoseAll()
    {
        var lost = new List<CustomerRuntime>();
        while (_nextPlanIndex < _plan.Customers.Count)
        {
            PlannedCustomer plan = _plan.Customers[_nextPlanIndex++];
            var customer = new CustomerRuntime(plan, _types[plan.CustomerTypeId], _patienceMultiplier) { State = CustomerState.Left };
            customer.Order.Status = OrderStatus.Lost;
            lost.Add(customer);
            CustomerLost?.Invoke(customer);
        }
        while (_pending.Count > 0)
        {
            CustomerRuntime customer = _pending.Dequeue();
            customer.State = CustomerState.Left;
            customer.Order.Status = OrderStatus.Lost;
            lost.Add(customer);
            CustomerLost?.Invoke(customer);
        }

        foreach (CustomerRuntime customer in _slots.ToArray())
        {
            if (!customer.WasServed)
            {
                customer.Order.Status = OrderStatus.Lost;
                lost.Add(customer);
                CustomerLost?.Invoke(customer);
            }
            customer.State = CustomerState.Left;
            CustomerRemoved?.Invoke(customer);
        }
        _slots.Clear();
        SelectedCustomerId = null;
        Changed?.Invoke();
        return lost;
    }

    private bool AdmitPending()
    {
        bool changed = false;
        while (_slots.Count < _capacity && _pending.Count > 0)
        {
            CustomerRuntime customer = _pending.Dequeue();
            var unavailableAppearances = _slots.Select(item => item.AppearanceId).ToHashSet(StringComparer.Ordinal);
            customer.AppearanceId = CustomerAppearanceCatalog.Select(
                customer.Type.Id,
                _plan.RandomSeed,
                customer.Id,
                unavailableAppearances);
            customer.State = CustomerState.Entering;
            customer.PhaseSeconds = 0;
            customer.Order.Status = OrderStatus.Waiting;
            _slots.Add(customer);
            CustomerEntered?.Invoke(customer);
            changed = true;
        }
        return changed;
    }

    private bool IsUnderComplexPressure()
    {
        int complex = _slots.Count(customer => customer.Order.IsComplex && customer.State is not (CustomerState.Leaving or CustomerState.Served));
        int big = _slots.Count(customer => customer.Type.IsBigOrderCustomer && customer.State is not (CustomerState.Leaving or CustomerState.Served));
        return complex >= 2 || big >= 1 && complex >= 1;
    }
}
