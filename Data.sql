USE StockExchange;
GO

INSERT INTO Assets_types (name)
VALUES
    ('FIAT'),
    ('CRYPTO'),
    ('COMMODITY');
GO

INSERT INTO Assets (symbol, name, asset_type)
VALUES
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
GO

USE StockExchange;
GO

INSERT INTO Users (first_name, last_name, user_name, email, phone)
VALUES
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
GO