use StockExchange

create view v_Transaction_history as
select
    t.transaction_id,
    u.user_name,
    af.symbol as from_asset,
    at.symbol as to_asset,
    t.amount_from,
    t.amount_to,
    t.executed_rate,
    s.name as status_name,
    t.created_at
from Transactions t
join Users u on t.user_id = u.user_id
join Assets af on t.from_asset_id = af.asset_id
join Assets at on t.to_asset_id = at.asset_id
join Transaction_statuses s on t.status = s.status_id;
go

create view v_Pending_transactions as
select
    af.symbol as from_asset,
    at.symbol as to_asset,
    count(t.transaction_id) as pending_orders_count,
    sum(t.amount_from) as total_locked_volume,
    min(t.requested_rate) as lowest_requested_rate,
    max(t.requested_rate) as highest_requested_rate
from Transactions t
join Assets af on t.from_asset_id = af.asset_id
join Assets at on t.to_asset_id = at.asset_id
where t.status = 1
group by af.symbol, at.symbol;
go

create view v_current_rates as
select
    a.symbol as asset_symbol,
    a.name as asset_name,
    er.rate_to_usd,
    er.valid_since
from Exchange_rates er
join Assets a on er.asset_id = a.asset_id
where er.valid_until is null;
go