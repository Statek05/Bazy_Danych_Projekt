const API_URL = 'http://127.0.0.1:8000';
let currentUser = '';
let originalProfileData = { email: '', phone: '' };

const loginScreen = document.getElementById('login-screen');
const dashboardScreen = document.getElementById('dashboard-screen');
const loginInput = document.getElementById('username-input');
const loginBtn = document.getElementById('login-btn');
const loginError = document.getElementById('login-error');
const welcomeText = document.getElementById('welcome-text');

const walletsContainer = document.getElementById('wallets-container');
const ratesContainer = document.getElementById('rates-container');

const profileUsername = document.getElementById('profile-username');
const profileFirstName = document.getElementById('profile-first-name');
const profileLastName = document.getElementById('profile-last-name');
const profileEmail = document.getElementById('profile-email');
const profilePhone = document.getElementById('profile-phone');
const updateProfileBtn = document.getElementById('update-profile-btn');
const profileMessage = document.getElementById('profile-message');

const fundModal = document.getElementById('fund-modal');
const openFundModalBtn = document.getElementById('open-fund-modal-btn');
const closeModalBtn = document.getElementById('close-modal-btn');
const submitFundBtn = document.getElementById('submit-fund-btn');
const assetSelect = document.getElementById('asset-select');
const amountInput = document.getElementById('amount-input');
const modalError = document.getElementById('modal-error');

const tradeModal = document.getElementById('trade-modal');
const openTradeModalBtn = document.getElementById('open-trade-modal-btn');
const closeTradeModalBtn = document.getElementById('close-trade-modal-btn');
const submitTradeBtn = document.getElementById('submit-trade-btn');
const tradeFromSelect = document.getElementById('trade-from-select');
const tradeToSelect = document.getElementById('trade-to-select');
const tradeAmountInput = document.getElementById('trade-amount-input');
const tradeRateInput = document.getElementById('trade-rate-input');
const tradeSlippageInput = document.getElementById('trade-slippage-input');
const tradeModalError = document.getElementById('trade-modal-error');
const tradeModalSuccess = document.getElementById('trade-modal-success');

const transactionsTbody = document.getElementById('transactions-tbody');
const tabBtns = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');

async function fetchPortfolio() {
    try {
        const response = await fetch(`${API_URL}/user/portfolio`, { headers: { 'X-User-Name': currentUser } });
        if (!response.ok) throw new Error('No wallets found.');
        const data = await response.json();

        walletsContainer.innerHTML = '';
        data.wallets.forEach(wallet => {
            walletsContainer.innerHTML += `
                <div class="wallet-card">
                    <div class="wallet-symbol">${wallet.asset_name} (${wallet.symbol.toUpperCase()})</div>
                    <div class="wallet-balance">${wallet.balance.toFixed(2)}</div>
                </div>`;
        });
    } catch (error) {
        walletsContainer.innerHTML = `<p class="error-msg">${error.message}</p>`;
    }
}

async function fetchRates() {
    try {
        const response = await fetch(`${API_URL}/user/rates`, { headers: { 'X-User-Name': currentUser } });
        const data = await response.json();

        ratesContainer.innerHTML = '';
        assetSelect.innerHTML = '';
        tradeFromSelect.innerHTML = '';
        tradeToSelect.innerHTML = '';

        data.current_rates.forEach(rate => {
            ratesContainer.innerHTML += `
                <div class="rate-item">
                    <span><strong>${rate.symbol.toUpperCase()}</strong> - ${rate.name}</span>
                    <span>$${rate.rate_to_usd.toFixed(2)}</span>
                </div>`;

            const optionHTML = `<option value="${rate.symbol}">${rate.name} (${rate.symbol.toUpperCase()})</option>`;
            assetSelect.innerHTML += optionHTML;
            tradeFromSelect.innerHTML += optionHTML;
            tradeToSelect.innerHTML += optionHTML;
        });
    } catch (error) {
        ratesContainer.innerHTML = `<p class="error-msg">Failed to load market rates.</p>`;
    }
}

async function fetchTransactions() {
    try {
        const response = await fetch(`${API_URL}/user/transactions`, { headers: { 'X-User-Name': currentUser } });
        if (!response.ok) throw new Error('Error loading transaction history.');
        const data = await response.json();

        transactionsTbody.innerHTML = '';

        if (data.transactions.length === 0) {
            transactionsTbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color: #a0a0a0;">No transaction history found.</td></tr>`;
            return;
        }

        data.transactions.forEach(tx => {
            let statusClass = 'status-pending';
            const statusName = tx.status.toLowerCase();
            let actionHtml = '-';

            if (statusName.includes('complete') || statusName.includes('settle')) {
                statusClass = 'status-completed';
            } else if (statusName.includes('cancel') || statusName.includes('fail') || statusName.includes('reject')) {
                statusClass = 'status-cancelled';
            } else {
                actionHtml = `<button class="cancel-btn" onclick="cancelTransaction(${tx.transaction_id})">Cancel</button>`;
            }

            const dateObj = new Date(tx.created_at);
            const formattedDate = dateObj.toLocaleString('en-US');

            const amountTo = tx.amount_to ? tx.amount_to.toFixed(4) : '-';
            const execRate = tx.executed_rate ? tx.executed_rate.toFixed(4) : '-';

            transactionsTbody.innerHTML += `
                <tr>
                    <td>${formattedDate}</td>
                    <td><strong>${tx.from_asset} ➔ ${tx.to_asset}</strong></td>
                    <td>${tx.amount_from.toFixed(2)}</td>
                    <td>${amountTo}</td>
                    <td>${execRate}</td>
                    <td><span class="status-badge ${statusClass}">${tx.status}</span></td>
                    <td>${actionHtml}</td>
                </tr>
            `;
        });
    } catch (error) {
        transactionsTbody.innerHTML = `<tr><td colspan="7" class="error-msg" style="text-align:center;">${error.message}</td></tr>`;
    }
}

async function cancelTransaction(transactionId) {
    if (!confirm('Are you sure you want to cancel this pending order? Funds will be returned immediately.')) {
        return;
    }

    try {
        const response = await fetch(`${API_URL}/user/trade/${transactionId}/cancel`, {
            method: 'POST',
            headers: { 'X-User-Name': currentUser }
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.detail);

        alert(data.message);

        await fetchTransactions();
        await fetchPortfolio();

    } catch (error) {
        alert('Failed to cancel order: ' + error.message);
    }
}

function fillProfileForm(data) {
    profileUsername.value = data.user_name;
    profileFirstName.value = data.first_name;
    profileLastName.value = data.last_name;
    profileEmail.value = data.email;
    profilePhone.value = data.phone;

    originalProfileData.email = data.email;
    originalProfileData.phone = data.phone;
}

function showError(element, message) {
    element.textContent = message;
    element.className = 'error-msg';
}

function showMessage(element, message, className) {
    element.textContent = message;
    element.className = className;
    setTimeout(() => { element.classList.add('hidden'); }, 3000);
}

loginBtn.addEventListener('click', async () => {
    const username = loginInput.value.trim();
    if (!username) {
        showError(loginError, 'Enter your username!');
        return;
    }

    try {
        const response = await fetch(`${API_URL}/user/profile`, {
            headers: { 'X-User-Name': username }
        });

        if (!response.ok) {
            throw new Error('User does not exist on the exchange!');
        }

        const profileData = await response.json();
        fillProfileForm(profileData);

        currentUser = username;
        loginScreen.classList.add('hidden');
        dashboardScreen.classList.remove('hidden');
        welcomeText.innerText = `Welcome, ${currentUser}`;
        loginError.classList.add('hidden');

        await fetchRates();
        await fetchPortfolio();
        await fetchTransactions();

    } catch (error) {
        showError(loginError, error.message);
    }
});

document.getElementById('logout-btn').addEventListener('click', () => {
    currentUser = '';
    loginInput.value = '';
    dashboardScreen.classList.add('hidden');
    loginScreen.classList.remove('hidden');
});

tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        tabBtns.forEach(b => b.classList.remove('active'));
        tabContents.forEach(tc => tc.classList.add('hidden'));

        btn.classList.add('active');
        const targetId = btn.getAttribute('data-target');
        document.getElementById(targetId).classList.remove('hidden');
    });
});

updateProfileBtn.addEventListener('click', async () => {
    try {
        const response = await fetch(`${API_URL}/user/profile`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'X-User-Name': currentUser
            },
            body: JSON.stringify({
                email: profileEmail.value,
                phone: profilePhone.value
            })
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.detail);

        showMessage(profileMessage, data.message, 'success-msg');

        originalProfileData.email = profileEmail.value;
        originalProfileData.phone = profilePhone.value;

    } catch (error) {
        showMessage(profileMessage, error.message, 'error-msg');

        profileEmail.value = originalProfileData.email;
        profilePhone.value = originalProfileData.phone;
    }
});

openFundModalBtn.addEventListener('click', () => {
    fundModal.classList.remove('hidden');
    modalError.classList.add('hidden');
    amountInput.value = '';
});

closeModalBtn.addEventListener('click', () => fundModal.classList.add('hidden'));

submitFundBtn.addEventListener('click', async () => {
    const symbol = assetSelect.value;
    const amount = parseFloat(amountInput.value);

    if (isNaN(amount) || amount <= 0) {
        showError(modalError, 'Please enter a valid amount.');
        return;
    }

    submitFundBtn.disabled = true;
    submitFundBtn.textContent = 'Processing...';

    try {
        const response = await fetch(`${API_URL}/user/fund`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-User-Name': currentUser },
            body: JSON.stringify({ asset_symbol: symbol, amount: amount })
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.detail);

        fundModal.classList.add('hidden');
        await fetchPortfolio();
    } catch (error) {
        showError(modalError, error.message);
    } finally {
        submitFundBtn.disabled = false;
        submitFundBtn.textContent = 'Confirm Deposit';
    }
});

openTradeModalBtn.addEventListener('click', () => {
    tradeModal.classList.remove('hidden');
    tradeModalError.classList.add('hidden');
    tradeModalSuccess.classList.add('hidden');
    tradeAmountInput.value = '';
    tradeRateInput.value = '';
});

closeTradeModalBtn.addEventListener('click', () => {
    tradeModal.classList.add('hidden');
});

submitTradeBtn.addEventListener('click', async () => {
    const fromSymbol = tradeFromSelect.value;
    const toSymbol = tradeToSelect.value;
    const amount = parseFloat(tradeAmountInput.value);
    const rate = parseFloat(tradeRateInput.value);
    const slippageElem = document.getElementById('trade-slippage-input');
    const slippage = slippageElem ? parseFloat(slippageElem.value) : 0.01;

    if (fromSymbol === toSymbol) {
        showError(tradeModalError, 'Cannot trade the same asset!');
        return;
    }
    if (isNaN(amount) || amount <= 0 || isNaN(rate) || rate <= 0) {
        showError(tradeModalError, 'Amount and rate must be greater than zero.');
        return;
    }

    submitTradeBtn.disabled = true;
    submitTradeBtn.textContent = 'Processing...';

    try {
        const response = await fetch(`${API_URL}/user/trade`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-User-Name': currentUser
            },
            body: JSON.stringify({
                from_symbol: fromSymbol,
                to_symbol: toSymbol,
                amount_from: amount,
                requested_rate: rate,
                slippage_tolerance: slippage
            })
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.detail);

        tradeModalError.classList.add('hidden');
        showMessage(tradeModalSuccess, data.message, 'success-msg');

        await fetchPortfolio();
        await fetchTransactions();

        setTimeout(() => {
            tradeModal.classList.add('hidden');
            tradeModalSuccess.classList.add('hidden');
        }, 2000);

    } catch (error) {
        showError(tradeModalError, error.message);
    } finally {
        submitTradeBtn.disabled = false;
        submitTradeBtn.textContent = 'Submit Order';
    }
});