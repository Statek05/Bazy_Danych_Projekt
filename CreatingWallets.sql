use StockExchange;
go

alter table Transactions
add expires_at datetime null;
go

use StockExchange;
go

create trigger trg_AutoCreateWallets
on Users
after insert
as
begin

    set nocount on;

    insert into Wallets (user_id, asset_id, balance)
    select i.user_id, a.asset_id, 0.0
    from inserted i
    cross join Assets a
    where a.symbol in ('USD');

    print 'Created USD wallet for new user.';
end
go


insert into Wallets (user_id, asset_id, balance)
select u.user_id, a.asset_id, 0.0
from Users u
cross join Assets a
where a.symbol = 'USD'
  and not exists (
      select 1
      from Wallets w
      where w.user_id = u.user_id
        and w.asset_id = a.asset_id
  );
go

create view vw_UserWallets
as
select
    u.user_id,
    u.user_name,
    a.symbol,
    a.name as asset_name,
    w.balance
from Wallets w
join Users u on w.user_id = u.user_id
join Assets a on w.asset_id = a.asset_id
go

use StockExchange;
go

create function fn_CalculateSlippage (
    @requested_rate decimal(18,8),
    @actual_rate decimal(18,8)
)
returns decimal(18,8)
as
begin
    return abs((@actual_rate - @requested_rate) / @requested_rate);
end;
go