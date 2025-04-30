
# StacksSynth -  Synthetic Asset Smart Contract (Clarity)

This Clarity smart contract implements a synthetic asset protocol for the Stacks blockchain. It enables users to mint, burn, and transfer synthetic tokens backed by STX collateral, while relying on an oracle for real-time price data. The contract includes advanced features like collateral ratio enforcement, undercollateralization liquidation, and full overflow protection.

---

## 📜 Features

- ✅ **Minting** of synthetic tokens backed by collateral (STX).
- ✅ **Burning** of tokens to redeem underlying STX.
- ✅ **Transfers** between token holders.
- ✅ **Collateral vaults** with individual tracking.
- ✅ **Oracle price feed** with expiry validation.
- ✅ **Undercollateralized liquidation** mechanism.
- ✅ **Overflow-safe math operations**.
- ✅ **Minimum mint thresholds** and **oracle price validity enforcement**.

---

## 🏗 Contract Constants

| Constant                             | Description                                | Value         |
|--------------------------------------|--------------------------------------------|---------------|
| `REQUIRED-COLLATERAL-RATIO`          | Minimum required collateral (in %)         | `u150`        |
| `LIQUIDATION-THRESHOLD-RATIO`        | Collateral ratio for liquidation trigger   | `u120`        |
| `ORACLE-PRICE-EXPIRY-BLOCKS`         | Oracle price expiry duration in blocks     | `u900`        |
| `MINIMUM-SYNTHETIC-TOKEN-MINT`       | Minimum mintable token amount (8 decimals) | `u100000000`  |
| `MAXIMUM-PRICE`                      | Maximum allowed price input                | `u1000000000000` |
| `MAXIMUM-UINT`                       | Max uint value for overflow checks         | `2^128 - 1`   |

---

## 📚 Public Functions

### `update-oracle-price (new-asset-price uint)`

Updates the oracle price for the underlying asset. Callable only by contract admin.

### `mint-synthetic-tokens (token-amount uint)`

Allows users to mint synthetic tokens by locking up sufficient STX collateral.

### `burn-synthetic-tokens (token-amount uint)`

Burns synthetic tokens and returns proportional STX collateral.

### `transfer-synthetic-tokens (recipient principal, amount uint)`

Transfers synthetic tokens between users.

### `deposit-additional-collateral (collateral-amount uint)`

Lets users deposit more STX to their existing vault to avoid liquidation.

### `liquidate-undercollateralized-vault (vault-owner principal)`

Liquidates a vault that falls below the required collateral threshold and rewards the liquidator.

---

## 🔍 Read-Only Functions

### `get-synthetic-token-balance (holder principal)`

Returns the synthetic token balance for a user.

### `get-synthetic-token-supply ()`

Returns the total synthetic token supply.

### `get-oracle-asset-price ()`

Returns the current oracle asset price.

### `get-user-vault-details (owner principal)`

Fetches vault details of a user including STX collateral and tokens minted.

### `calculate-vault-collateral-ratio (owner principal)`

Returns the current collateral ratio of a user’s vault.

---

## ⚠️ Error Codes

| Code                          | Meaning                               |
|-------------------------------|----------------------------------------|
| `ERR-UNAUTHORIZED-ACCESS`     | Operation not permitted                |
| `ERR-INSUFFICIENT-TOKEN-BALANCE` | Not enough tokens to perform operation |
| `ERR-INVALID-TOKEN-AMOUNT`    | Mint amount too low                    |
| `ERR-ORACLE-PRICE-EXPIRED`    | Oracle price is outdated               |
| `ERR-INSUFFICIENT-COLLATERAL-DEPOSIT` | Not enough collateral deposited    |
| `ERR-BELOW-MINIMUM-COLLATERAL-THRESHOLD` | Collateral ratio too low         |
| `ERR-INVALID-PRICE`           | Invalid oracle price                   |
| `ERR-ARITHMETIC-OVERFLOW`     | Overflow in calculation                |
| `ERR-INVALID-RECIPIENT`       | Invalid address for transfer           |
| `ERR-ZERO-AMOUNT`             | Amount must be greater than zero       |
| `ERR-NO-VAULT-EXISTS`         | Vault not found                        |

---

## 🔐 Security Features

- **Arithmetic checks**: Custom safe-math functions to prevent overflow and underflow.
- **Oracle validation**: Price must be recent to be used for minting.
- **Collateral enforcement**: Mints only allowed with enough collateral based on real-time prices.
- **Liquidation**: Vaults that fall below 120% collateral ratio are eligible for liquidation.

---
