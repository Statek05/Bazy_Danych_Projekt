use StockExchange;
go

insert into Assets_types (name)
values
    ('FIAT'),
    ('CRYPTO'),
    ('COMMODITY');
go

insert into Assets (symbol, name, asset_type)
values
    ('USD', 'US Dollar', 1),
    ('PLN', 'Polski Zloty', 1),
    ('EUR', 'Euro', 1),
    ('GBP', 'British Pound', 1),
    ('CHF', 'Swiss Franc', 1),
    ('JPY', 'Japanese Yen', 1),
    ('CAD', 'Canadian Dollar', 1),
    ('AUD', 'Australian Dollar', 1),
    ('BTC', 'Bitcoin', 2),
    ('ETH', 'Ethereum', 2),
    ('SOL', 'Solana', 2),
    ('ADA', 'Cardano', 2),
    ('XRP', 'Ripple', 2),
    ('DOT', 'Polkadot', 2),
    ('DOGE', 'Dogecoin', 2),
    ('MATIC', 'Polygon', 2),
    ('LINK', 'Chainlink', 2),
    ('AVAX', 'Avalanche', 2),
    ('XAU', 'Gold Ounce', 3),
    ('XAG', 'Silver Ounce', 3),
    ('WTI', 'Crude Oil', 3),
    ('BRENT', 'Brent Crude', 3);
go

use StockExchange;
go

insert into Users (first_name, last_name, user_name, email, phone)
values
    ('Anna', 'Kowalska', 'ania99', 'anna.kowalska@gmail.com', '+48500123456'),
    ('James', 'Smith', 'jsmith_trade', 'james.smith@proton.me', '+12125550198'),
    ('Yuki', 'Takahashi', 'yuki_tk', 'yuki.takahashi@yahoo.co.jp', '+819012345678'),
    ('Carlos', 'Mendoza', 'carlosm', 'c.mendoza@hotmail.com', '+34600112233'),
    ('Sophie', 'Martin', 'smartin88', 'sophie.martin@orange.fr', '+33612345678'),
    ('Liam', 'O''Connor', 'liam_oc', 'liam.oconnor@outlook.com', '+353876543210'),
    ('Chen', 'Wei', 'chenw_crypto', 'chen.wei@qq.com', '+8613912345678'),
    ('Maria', 'Rossi', 'mariar', 'maria.rossi@libero.it', '+393311234567'),
    ('Oliver', 'Muller', 'olimuller', 'oliver.muller@web.de', '+4915123456789'),
    ('Elena', 'Popova', 'epopova', 'elena.popova@yandex.ru', '+79161234567');
go


create procedure p_AddUser (
    @user_name nvarchar(50),
    @first_name nvarchar(50),
    @last_name nvarchar(50),
    @email nvarchar(100),
    @phone nvarchar(20)
)
as
begin
    set nocount on;

    if exists (select 1 from Users where user_name = @user_name)
        throw 50096, 'Error: User with this user_name already exists.', 1;

    begin try
        insert into Users (user_name, first_name, last_name, email, phone)
        values (@user_name, @first_name, @last_name, @email, @phone);

        print 'Success: User profile created. USD wallet automatically created.';
    end try
    begin catch
        print 'Error: Could not create user.';
        throw;
    end catch;
end;
go


create procedure p_DeleteUserComplete (
    @user_name nvarchar(50)
)
as
begin
    set nocount on;
    declare @user_id int;

    begin try
        begin tran;
        select @user_id = user_id
        from Users with (updlock, holdlock)
        where user_name = @user_name;
        if @user_id is null
            throw 50095, 'Error: User profile not found.', 1;
        delete wa
        from Wallets_Audit wa
        join Wallets w on wa.wallet_id = w.wallet_id
        where w.user_id = @user_id;
        delete from Transactions
        where user_id = @user_id;
        delete from Wallets
        where user_id = @user_id;
        delete from Users
        where user_id = @user_id;

        commit tran;
        print 'Success: User and all associated assets, transactions, and logs have been completely wiped.';
    end try
    begin catch
        if @@trancount > 0
            rollback tran;

        print 'Error: Deletion aborted. System state rolled back safely.';
        throw;
    end catch;
end;
go

create procedure p_UpdateUserDetails (
    @user_name nvarchar(50),
    @new_email nvarchar(100),
    @new_phone nvarchar(20)
)
as
begin
    set nocount on;

    update Users
    set email = @new_email,
        phone = @new_phone
    where user_name = @user_name;
end;
go
