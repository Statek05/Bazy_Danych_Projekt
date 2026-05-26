create table Assets_types
(
    type_id int identity
        primary key,
    name    nvarchar(50) not null
        unique
)
go

create table Assets
(
    asset_id   int identity
        primary key,
    symbol     nvarchar(10) not null
        unique,
    name       nvarchar(50) not null,
    asset_type int          not null
        references Assets_types
)
go

create table Exchange_rates
(
    rate_id     int identity
        primary key,
    asset_id    int                        not null
        references Assets,
    rate_to_usd decimal(18, 8)             not null
        constraint chk_rate_positive
            check ([rate_to_usd] > 0),
    valid_since datetime default getdate() not null,
    valid_until datetime,
    constraint uq_asset_id_valid_until
        unique (asset_id, valid_until)
)
go

create table Transaction_statuses
(
    status_id int identity
        primary key,
    name      nvarchar(50) not null
        unique
)
go

create table Users
(
    user_id    int identity
        primary key,
    first_name nvarchar(50)               not null,
    last_name  nvarchar(100)              not null,
    user_name  nvarchar(50)               not null
        unique,
    email      nvarchar(255)              not null
        unique
        constraint chk_users_email_format
            check ([email] like '%_@__%.__%'),
    phone      nvarchar(20)
        constraint chk_users_phone_format
            check (NOT [phone] like '%[^0-9+]%'),
    created_at datetime default getdate() not null,
    constraint chk_users_names_not_empty
        check (len(Trim([first_name])) > 0 AND len(Trim([last_name])) > 0)
)
go

create table Transactions
(
    transaction_id         int identity
        primary key,
    user_id                int                              not null
        references Users,
    from_asset_id          int                              not null
        references Assets,
    to_asset_id            int                              not null
        references Assets,
    amount_from            decimal(18, 8)                   not null,
    amount_to              decimal(18, 8)                   not null,
    requested_rate         decimal(18, 8)                   not null,
    executed_rate          decimal(18, 8)                   not null,
    fee_amount             decimal(18, 8) default 0.0       not null
        constraint chk_fee
            check ([fee_amount] >= 0.0),
    slippage_tolerance_pct decimal(5, 2)  default 0.01      not null,
    status                 int                              not null
        references Transaction_statuses,
    created_at             datetime       default getdate() not null,
    constraint chk_amounts
        check ([amount_from] > 0 AND [amount_to] > 0),
    constraint chk_rates
        check ([requested_rate] > 0 AND [executed_rate] > 0)
)
go

create table Wallets
(
    wallet_id int identity
        primary key,
    user_id   int                        not null
        references Users,
    asset_id  int                        not null
        references Assets,
    balance   decimal(18, 8) default 0.0 not null
        constraint chk_balance_not_negative
            check ([balance] >= 0.0),
    constraint uq_user_asset
        unique (user_id, asset_id)
)
go

