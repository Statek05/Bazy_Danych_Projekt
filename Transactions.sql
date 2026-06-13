use StockExchange;
go

create procedure p_AddFunds (
    @user_name nvarchar(50),
    @asset_symbol nvarchar(10),
    @amount decimal(18,8)
)
as
begin
    set nocount on;

    declare @user_id int;
    declare @asset_id int;
    select @user_id = user_id from Users where user_name = @user_name;
    if @user_id is null
        throw 50001, 'Error: User not found.', 1;

    select @asset_id = asset_id from Assets where symbol = @asset_symbol;
    if @asset_id is null
        throw 50002, 'Error: Asset not in database.', 1;

    if @amount <= 0
        throw 50003, 'Error: Deposit amount must be greater than zero.', 1;

    begin try
        begin tran;
        if exists (
            select 1
            from Wallets with (updlock, holdlock)
            where user_id = @user_id and asset_id = @asset_id
        )
        begin
            update Wallets
            set balance = balance + @amount
            where user_id = @user_id and asset_id = @asset_id;
        end
        else
        begin
            insert into Wallets (user_id, asset_id, balance)
            values (@user_id, @asset_id, @amount);
        end
        commit tran;
        print 'Deposit completed successfully!';
    end try
    begin catch
        if @@trancount > 0
            rollback tran;

        print 'Transaction failed!';
        throw;
    end catch;
end;
go

alter table Transactions drop constraint chk_amounts;
alter table Transactions drop constraint chk_rates;
alter table Transactions alter column amount_to decimal(18, 8) null;
alter table Transactions alter column executed_rate decimal(18, 8) null;
alter table Transactions add constraint chk_amounts
    check ([amount_from] > 0 and ([amount_to] is null or [amount_to] > 0));
alter table Transactions add constraint chk_rates
    check ([requested_rate] > 0 and ([executed_rate] is null or [executed_rate] > 0));
go