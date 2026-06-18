import time
import pyodbc
import yfinance as yf
import warnings
from datetime import datetime

warnings.filterwarnings('ignore')

CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost,1433;"
    "DATABASE=StockExchange;"
    "UID=sa;"
    "PWD=Prodzekt123;"
    "TrustServerCertificate=yes;"
)

def fetch_all_prices():
    prices = {}
    mapping = {
        'BTC-USD': 'BTC', 'ETH-USD': 'ETH', 'SOL-USD': 'SOL', 'ADA-USD': 'ADA',
        'XRP-USD': 'XRP', 'DOT-USD': 'DOT', 'DOGE-USD': 'DOGE',
        'LINK-USD': 'LINK', 'AVAX-USD': 'AVAX',
        'PLNUSD=X': 'PLN', 'EURUSD=X': 'EUR', 'GBPUSD=X': 'GBP', 'CHFUSD=X': 'CHF',
        'JPYUSD=X': 'JPY', 'CADUSD=X': 'CAD', 'AUDUSD=X': 'AUD',
        'GC=F': 'XAU',
        'SI=F': 'XAG'
    }

    try:
        tickers_list = list(mapping.keys())
        data = yf.download(tickers_list, period="1d", interval="3m", progress=False)

        for yf_ticker, db_symbol in mapping.items():
            try:
                latest_price = data['Close'][yf_ticker].dropna().iloc[-1]
                prices[db_symbol] = float(latest_price)
            except Exception:
                continue

    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] API Error: {e}")

    return prices

def update_database(prices):
    if not prices:
        return

    try:
        conn = pyodbc.connect(CONN_STR)
        cursor = conn.cursor()

        local_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        insert_query = """
        DECLARE @asset_id INT;
        SELECT @asset_id = asset_id FROM Assets WHERE symbol = ?;

        IF @asset_id IS NOT NULL
        BEGIN
            UPDATE Exchange_rates
            SET valid_until = ?
            WHERE asset_id = @asset_id AND valid_until IS NULL;

            INSERT INTO Exchange_rates (asset_id, rate_to_usd, valid_since)
            VALUES (@asset_id, ?, ?);
        END
        """

        for symbol, price in prices.items():
            cursor.execute(insert_query, symbol, local_time, price, local_time)

        conn.commit()
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Successfully added {len(prices)} new rows to the database.")

    except pyodbc.Error as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] Database Insert Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    print("Press CTRL+C to stop the execution.\n")

    while True:
        try:
            current_prices = fetch_all_prices()
            update_database(current_prices)

        except Exception as e:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] Unexpected error: {e}")

        time.sleep(300)