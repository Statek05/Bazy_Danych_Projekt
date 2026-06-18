from fastapi import FastAPI, HTTPException, Security
from fastapi.security import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pyodbc
from datetime import datetime

app = FastAPI(
    title="StockExchange API",
    description="REST API for the Stock Exchange platform"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CONNECTION_STRING = (
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=localhost,1433;'
    r'DATABASE=StockExchange;'
    r'UID=sa;'
    r'PWD=Prodzekt123;'
    r'TrustServerCertificate=yes;'
)

api_key_header = APIKeyHeader(name="X-User-Name", description="Enter your Username to login", auto_error=True)

class UserCreate(BaseModel):
    user_name: str
    first_name: str
    last_name: str
    email: str
    phone: str

class TransactionCreate(BaseModel):
    from_symbol: str
    to_symbol: str
    amount_from: float
    requested_rate: float
    slippage_tolerance: float = 0.01

class FundWallet(BaseModel):
    asset_symbol: str
    amount: float

class UserUpdate(BaseModel):
    email: str
    phone: str

def get_db_connection():
    return pyodbc.connect(CONNECTION_STRING)

def execute_procedure(query: str, params: tuple, success_response: dict):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            return success_response
    except pyodbc.Error as e:
        error_str = str(e)
        if '[SQL Server]' in error_str:
            error_msg = error_str.split('[SQL Server]')[1]
            error_msg = error_msg.rsplit('(', 1)[0].strip()
        else:
            error_msg = error_str

        raise HTTPException(status_code=400, detail=error_msg)

def fetch_current_rates():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT asset_symbol, asset_name, rate_to_usd, valid_since FROM v_current_rates")

            rates_list = [{"symbol": row[0], "name": row[1], "rate_to_usd": float(row[2]), "valid_since": str(row[3])} for row in cursor.fetchall()]

            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            rates_list.insert(0, {
                "symbol": "usd",
                "name": "US Dollar",
                "rate_to_usd": 1.00,
                "valid_since": current_time
            })

            return {"current_rates": rates_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/admin/rates", tags=["Admin"])
def get_current_rates_admin():
    return fetch_current_rates()

@app.get("/admin/users", tags=["Admin"])
def get_all_users():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT user_name, symbol, balance FROM v_user_wallets")
            users_data = {}
            for row in cursor.fetchall():
                if row.user_name not in users_data:
                    users_data[row.user_name] = {"user_name": row.user_name, "wallets": []}
                users_data[row.user_name]["wallets"].append({"symbol": row.symbol, "balance": float(row.balance)})
            return {"users": list(users_data.values())}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/admin/users", tags=["Admin"])
def create_new_user(user: UserCreate):
    return execute_procedure(
        "EXEC p_AddUser @user_name=?, @first_name=?, @last_name=?, @email=?, @phone=?",
        (user.user_name, user.first_name, user.last_name, user.email, user.phone),
        {"message": f"User '{user.user_name}' has been successfully created."}
    )

@app.get("/user/rates", tags=["User"])
def get_current_rates_user():
    return fetch_current_rates()

@app.get("/user/portfolio", tags=["User"])
def get_my_portfolio(logged_in_user: str = Security(api_key_header)):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT symbol, asset_name, balance FROM v_user_wallets WHERE user_name = ?", (logged_in_user,))
            wallets = [{"symbol": row[0], "asset_name": row[1], "balance": float(row[2])} for row in cursor.fetchall()]
            if not wallets:
                raise HTTPException(status_code=404, detail="No wallets found. User might not exist or has no funds.")
            return {"user": logged_in_user, "wallets": wallets}
    except pyodbc.Error as e:
         raise HTTPException(status_code=500, detail=str(e))

@app.get("/user/profile", tags=["User"])
def get_my_profile(logged_in_user: str = Security(api_key_header)):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT user_name, first_name, last_name, email, phone FROM v_user_profile WHERE user_name = ?", (logged_in_user,))
            row = cursor.fetchone()

            if not row:
                raise HTTPException(status_code=404, detail="User does not exist!")

            return {
                "user_name": row[0],
                "first_name": row[1],
                "last_name": row[2],
                "email": row[3],
                "phone": row[4]
            }
    except pyodbc.Error as e:
         raise HTTPException(status_code=500, detail=str(e))

@app.get("/user/transactions", tags=["User"])
def get_my_transactions(logged_in_user: str = Security(api_key_header)):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT transaction_id, from_asset, to_asset, amount_from, amount_to, executed_rate, status_name, created_at 
                FROM v_transaction_history 
                WHERE user_name = ?
                ORDER BY created_at DESC
            """, (logged_in_user,))

            transactions_list = []
            for row in cursor.fetchall():
                transactions_list.append({
                    "transaction_id": row[0],
                    "from_asset": row[1].upper(),
                    "to_asset": row[2].upper(),
                    "amount_from": float(row[3]),
                    "amount_to": float(row[4]) if row[4] is not None else None,
                    "executed_rate": float(row[5]) if row[5] is not None else None,
                    "status": row[6],
                    "created_at": str(row[7])
                })

            return {"user": logged_in_user, "transactions": transactions_list}
    except pyodbc.Error as e:
         raise HTTPException(status_code=500, detail=str(e))

@app.put("/user/profile", tags=["User"])
def update_my_profile(profile_data: UserUpdate, logged_in_user: str = Security(api_key_header)):
    return execute_procedure(
        "EXEC p_UpdateUserDetails @user_name=?, @new_email=?, @new_phone=?",
        (logged_in_user, profile_data.email, profile_data.phone),
        {"message": "Your data has been updated."}
    )

@app.post("/user/fund", tags=["User"])
def add_funds(fund_data: FundWallet, logged_in_user: str = Security(api_key_header)):
    return execute_procedure(
        "EXEC p_AddFunds @user_name=?, @asset_symbol=?, @amount=?",
        (logged_in_user, fund_data.asset_symbol, fund_data.amount),
        {
            "message": f"Wallet successfully funded for user '{logged_in_user}'.",
            "details": f"Added {fund_data.amount} {fund_data.asset_symbol.upper()}"
        }
    )

@app.post("/user/trade", tags=["User"])
def create_trade(transaction: TransactionCreate, logged_in_user: str = Security(api_key_header)):
    return execute_procedure(
        """EXEC p_CreateTransaction 
           @user_name=?, @from_symbol=?, @to_symbol=?, 
           @amount_from=?, @requested_rate=?, @slippage_tolerance=?""",
        (logged_in_user, transaction.from_symbol, transaction.to_symbol,
         transaction.amount_from, transaction.requested_rate, transaction.slippage_tolerance),
        {"message": "Order has been successfully submitted to the exchange."}
    )

@app.post("/user/trade/{transaction_id}/cancel", tags=["User"])
def cancel_trade(transaction_id: int, logged_in_user: str = Security(api_key_header)):
    return execute_procedure(
        "EXEC p_CancelTransaction @user_name=?, @transaction_id=?",
        (logged_in_user, transaction_id),
        {"message": "Transaction cancelled. Money returned to wallet"}
    )