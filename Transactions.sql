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


create procedure p_CreateTransaction (
    @user_name nvarchar(50),
    @from_symbol nvarchar(10),
    @to_symbol nvarchar(10),
    @amount_from decimal(18,8),
    @requested_rate decimal(18,8),
    @slippage_tolerance decimal(5,2) = 0.01
)
as
begin
    set nocount on;
    declare @user_id int;
    declare @from_asset_id int;
    declare @to_asset_id int;
    declare @from_rate decimal(18,8);
    declare @to_rate decimal(18,8);
    declare @executed_rate decimal(18,8);
    declare @amount_to decimal(18,8);
    declare @fee_amount decimal(18,8);
    declare @net_amount_to decimal(18,8);
    declare @current_balance decimal(18,8);
    declare @actual_slippage decimal(18,8);
    declare @target_status int;

    select @user_id = user_id from Users where user_name = @user_name;
    if @user_id is null
        throw 50010, 'Error: User profile not found.', 1;

    select @from_asset_id = asset_id from Assets where symbol = @from_symbol;
    select @to_asset_id = asset_id from Assets where symbol = @to_symbol;
    if @from_asset_id is null or @to_asset_id is null
        throw 50011, 'Error: One or both assets are unsupported.', 1;

    if @amount_from <= 0
        throw 50012, 'Error: Source amount must be greater than zero.', 1;

    select @from_rate = isnull((select rate_to_usd from Exchange_rates where asset_id = @from_asset_id and valid_until is null), 1.0);
    select @to_rate = isnull((select rate_to_usd from Exchange_rates where asset_id = @to_asset_id and valid_until is null), 1.0);

    set @executed_rate = @from_rate / @to_rate;

    set @actual_slippage = dbo.fn_CalculateSlippage(@requested_rate, @executed_rate);

    if @actual_slippage <= @slippage_tolerance
    begin
        set @target_status = 2;
    end
    else
    begin
        set @target_status = 1;
    end

    begin try
        begin tran;
        select @current_balance = balance
        from Wallets with (updlock)
        where user_id = @user_id and asset_id = @from_asset_id;

        if @current_balance is null or @current_balance < @amount_from
            throw 50014, 'Error: Insufficient funds to place this order.', 1;

        update Wallets
        set balance = balance - @amount_from
        where user_id = @user_id and asset_id = @from_asset_id;

        if @target_status = 2
        begin
            set @amount_to = @amount_from * @executed_rate;
            set @fee_amount = @amount_to * 0.001;
            set @net_amount_to = @amount_to - @fee_amount;

            if exists (select 1 from Wallets with (updlock, holdlock) where user_id = @user_id and asset_id = @to_asset_id)
            begin
                update Wallets
                set balance = balance + @net_amount_to
                where user_id = @user_id and asset_id = @to_asset_id;
            end
            else
            begin
                insert into Wallets (user_id, asset_id, balance)
                values (@user_id, @to_asset_id, @net_amount_to);
            end

            insert into Transactions (user_id, from_asset_id, to_asset_id, amount_from, amount_to, requested_rate, executed_rate, fee_amount, slippage_tolerance_pct, status)
            values (@user_id, @from_asset_id, @to_asset_id, @amount_from, @amount_to, @requested_rate, @executed_rate, @fee_amount, @slippage_tolerance, 2);

            print 'Success: Transaction executed and settled immediately.';
        end
        else
        begin
            insert into Transactions (user_id, from_asset_id, to_asset_id, amount_from, amount_to, requested_rate, executed_rate, fee_amount, slippage_tolerance_pct, status)
            values (@user_id, @from_asset_id, @to_asset_id, @amount_from, null, @requested_rate, null, 0.0, @slippage_tolerance, 1);

            print 'Notice: Market price changed or limit unmet. Order registered as PENDING.';
        end

        commit tran;
    end try
    begin catch
        if @@trancount > 0
            rollback tran;

        print 'Critical: Transaction execution failed and was rolled back safely.';
        throw;
    end catch;
end;
go



create procedure p_CancelTransaction (
    @user_name nvarchar(50),
    @transaction_id int
)
as
begin
    set nocount on;

    declare @user_id int;
    declare @current_status int;
    declare @refund_amount decimal(18,8);
    declare @from_asset_id int;

    select @user_id = user_id from Users where user_name = @user_name;
    if @user_id is null
        throw 50030, 'Error: User not found.', 1;

    begin try
        begin tran;

        select
            @current_status = status,
            @refund_amount = amount_from,
            @from_asset_id = from_asset_id
        from Transactions with (updlock)
        where transaction_id = @transaction_id and user_id = @user_id;

        if @current_status is null
            throw 50031, 'Error: Transaction does not exist or belongs to another user.', 1;

        if @current_status != 1
            throw 50032, 'Error: Only PENDING transactions can be cancelled.', 1;

        update Transactions
        set status = 3
        where transaction_id = @transaction_id;
        update Wallets
        set balance = balance + @refund_amount
        where user_id = @user_id and asset_id = @from_asset_id;

        commit tran;
        print 'Success: Transaction cancelled. Funds safely returned to your wallet.';
    end try
    begin catch
        if @@trancount > 0
            rollback tran;

        print 'Error: Cancellation failed. Operation aborted.';
        throw;
    end catch;
end;
go

create procedure p_HandlePendingTransaction (
    @transaction_id int,
    @executed_rate decimal(18,8)
)
as
begin
    set nocount on;
    declare @user_id int;
    declare @from_asset_id int;
    declare @to_asset_id int;
    declare @current_status int;
    declare @amount_from decimal(18,8);
    declare @amount_to decimal(18,8);
    declare @fee_amount decimal(18,8);
    declare @net_amount_to decimal(18,8);

    begin try
        begin tran;
        select
            @user_id = user_id,
            @from_asset_id = from_asset_id,
            @to_asset_id = to_asset_id,
            @amount_from = amount_from,
            @current_status = status
        from Transactions with (updlock)
        where transaction_id = @transaction_id;

        if @current_status is null
            throw 50040, 'Error: Transaction not found.', 1;

        if @current_status != 1
            throw 50041, 'Error: Transaction is already settled or cancelled.', 1;

        set @amount_to = @amount_from * @executed_rate;
        set @fee_amount = @amount_to * 0.001;
        set @net_amount_to = @amount_to - @fee_amount;

        if exists (select 1 from Wallets with (updlock, holdlock) where user_id = @user_id and asset_id = @to_asset_id)
      begin
            update Wallets
            set balance = balance + @net_amount_to
            where user_id = @user_id and asset_id = @to_asset_id;
        end
        else
        begin
            insert into Wallets (user_id, asset_id, balance)
            values (@user_id, @to_asset_id, @net_amount_to);
        end

        update Transactions
        set
            status = 2,
            amount_to = @amount_to,
            executed_rate = @executed_rate,
            fee_amount = @fee_amount
        where transaction_id = @transaction_id;

        commit tran;
        print 'Success: Pending transaction settled and assets distributed.';
    end try
    begin catch
        if @@trancount > 0
            rollback tran;

        print 'Error: Settlement failed. System rolled back securely.';
        throw;
    end catch;
end;
go



create trigger trg_MatchPendingOrders
on Exchange_rates
after insert
as
begin
    set nocount on;
    declare @tx_id int;
    declare @from_asset int;
    declare @to_asset int;
    declare @req_rate decimal(18,8);
    declare @tolerance decimal(5,2);
    declare @from_rate decimal(18,8);
    declare @to_rate decimal(18,8);
    declare @exec_rate decimal(18,8);

    declare order_cursor cursor local fast_forward for
    select transaction_id, from_asset_id, to_asset_id, requested_rate, slippage_tolerance_pct
    from Transactions
    where status = 1;

    open order_cursor;
    fetch next from order_cursor into @tx_id, @from_asset, @to_asset, @req_rate, @tolerance;

    while @@fetch_status = 0
    begin
        select @from_rate = isnull((select rate_to_usd from Exchange_rates where asset_id = @from_asset and valid_until is null), 1.0);
        select @to_rate = isnull((select rate_to_usd from Exchange_rates where asset_id = @to_asset and valid_until is null), 1.0);
        set @exec_rate = @from_rate / @to_rate;

        if @exec_rate >= @req_rate
        begin
            begin try
                exec p_HandlePendingTransaction
                    @transaction_id = @tx_id,
                    @executed_rate = @exec_rate;
            end try
            begin catch
                print 'skipped settlement for transaction id: ' + cast(@tx_id as nvarchar(10));
            end catch
        end

        fetch next from order_cursor into @tx_id, @from_asset, @to_asset, @req_rate, @tolerance;
    end;

    close order_cursor;
    deallocate order_cursor;
end;
go
