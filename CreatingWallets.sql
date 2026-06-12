
USE StockExchange;
GO

ALTER TABLE Transactions
ADD expires_at DATETIME NULL;
GO

USE StockExchange;
GO

CREATE TRIGGER trg_AutoCreateWallets
ON Users
AFTER INSERT
AS
BEGIN

    SET NOCOUNT ON;

    INSERT INTO Wallets (user_id, asset_id, balance)
    SELECT i.user_id, a.asset_id, 0.0
    FROM inserted i
    CROSS JOIN Assets a
    WHERE a.symbol IN ('USD');

    PRINT 'Created USD wallet for new user.';
END
GO


INSERT INTO Wallets (user_id, asset_id, balance)
SELECT u.user_id, a.asset_id, 0.0
FROM Users u
CROSS JOIN Assets a
WHERE a.symbol = 'USD'
  AND NOT EXISTS (
      SELECT 1
      FROM Wallets w
      WHERE w.user_id = u.user_id
        AND w.asset_id = a.asset_id
  );
GO

CREATE VIEW vw_UserWallets
AS
SELECT
    u.user_id,
    u.user_name,
    a.symbol,
    a.name AS asset_name,
    w.balance
FROM Wallets w
JOIN Users u ON w.user_id = u.user_id
JOIN Assets a ON w.asset_id = a.asset_id
GO

USE StockExchange;
GO

CREATE FUNCTION fn_CalculateSlippage (
    @requested_rate DECIMAL(18,8),
    @actual_rate DECIMAL(18,8)
)
RETURNS DECIMAL(18,8)
AS
BEGIN
    RETURN ABS((@actual_rate - @requested_rate) / @requested_rate);
END;
GO