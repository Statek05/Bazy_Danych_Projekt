use StockExchange;
go

create trigger trg_AuditWallets
on Wallets
after update
as
begin
    set nocount on;

    if update(balance)
    begin
        insert into Wallets_Audit (wallet_id, old_balance, new_balance)
        select
            d.wallet_id,
            d.balance,
            i.balance
        from deleted d
        join inserted i on d.wallet_id = i.wallet_id
        where d.balance <> i.balance;
    end
end;
go