;; Synthetic Asset Contract
;; Implements minting, burning, transfers, and price oracle functionality
;; With enhanced security and complete overflow protection

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-TOKEN-BALANCE (err u101))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u102))
(define-constant ERR-ORACLE-PRICE-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-COLLATERAL-DEPOSIT (err u104))
(define-constant ERR-BELOW-MINIMUM-COLLATERAL-THRESHOLD (err u105))
(define-constant ERR-INVALID-PRICE (err u106))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u107))
(define-constant ERR-INVALID-RECIPIENT (err u108))
(define-constant ERR-ZERO-AMOUNT (err u109))
(define-constant ERR-NO-VAULT-EXISTS (err u110))

;; Constants
(define-constant CONTRACT-ADMINISTRATOR tx-sender)
(define-constant ORACLE-PRICE-EXPIRY-BLOCKS u900) ;; 15 minutes in blocks
(define-constant REQUIRED-COLLATERAL-RATIO u150) ;; 150%
(define-constant LIQUIDATION-THRESHOLD-RATIO u120) ;; 120%
(define-constant MINIMUM-SYNTHETIC-TOKEN-MINT u100000000) ;; 1.00 tokens (8 decimals)
(define-constant MAXIMUM-PRICE u1000000000000) ;; Set reasonable maximum price
(define-constant MAXIMUM-UINT u340282366920938463463374607431768211455) ;; 2^128 - 1

;; Data variables
(define-data-var oracle-price-last-update-block uint u0)
(define-data-var oracle-current-asset-price uint u0)
(define-data-var synthetic-token-total-supply uint u0)

;; Data maps
(define-map synthetic-token-holder-balances principal uint)
(define-map user-collateral-vault
    principal
    {
        deposited-collateral-amount: uint,
        minted-synthetic-tokens: uint,
        collateral-locked-at-price: uint
    }
)

;; Safe math functions
(define-private (safe-multiply (a uint) (b uint))
    (let ((result (* a b)))
        (asserts! (or (is-eq a u0) (is-eq (/ result a) b)) ERR-ARITHMETIC-OVERFLOW)
        (ok result)))

(define-private (safe-add (a uint) (b uint))
    (let ((result (+ a b)))
        (asserts! (>= result a) ERR-ARITHMETIC-OVERFLOW)
        (ok result)))

(define-private (safe-subtract (a uint) (b uint))
    (begin
        (asserts! (>= a b) ERR-ARITHMETIC-OVERFLOW)
        (ok (- a b))))

;; Read-only functions
(define-read-only (get-synthetic-token-balance (token-holder principal))
    (default-to u0 (map-get? synthetic-token-holder-balances token-holder))
)

(define-read-only (get-synthetic-token-supply)
    (var-get synthetic-token-total-supply)
)

(define-read-only (get-oracle-asset-price)
    (var-get oracle-current-asset-price)
)

(define-read-only (get-user-vault-details (vault-owner principal))
    (map-get? user-collateral-vault vault-owner)
)

(define-read-only (calculate-vault-collateral-ratio (vault-owner principal))
    (let (
        (vault-details (unwrap! (get-user-vault-details vault-owner) (err u0)))
        (current-market-price (var-get oracle-current-asset-price))
    )
    (if (> (get minted-synthetic-tokens vault-details) u0)
        (match (safe-multiply (get deposited-collateral-amount vault-details) u100)
            success1 (match (safe-multiply success1 u100)
                success2 (match (safe-multiply (get minted-synthetic-tokens vault-details) current-market-price)
                    denom (ok (/ success2 denom))
                    error ERR-ARITHMETIC-OVERFLOW)
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW)
        (err u0)))
)

;; Private functions
(define-private (process-token-transfer (sender-address principal) (recipient-address principal) (transfer-amount uint))
    (let (
        (sender-token-balance (get-synthetic-token-balance sender-address))
    )
    ;; Secondary validations in case this function is called directly
    (asserts! (> transfer-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq sender-address recipient-address)) ERR-INVALID-RECIPIENT)
    (asserts! (>= sender-token-balance transfer-amount) ERR-INSUFFICIENT-TOKEN-BALANCE)
    (asserts! (is-some (map-get? synthetic-token-holder-balances sender-address)) ERR-UNAUTHORIZED-ACCESS)

    (match (safe-add (get-synthetic-token-balance recipient-address) transfer-amount)
        recipient-new-balance
            (match (safe-subtract sender-token-balance transfer-amount)
                sender-new-balance
                    (begin
                        (map-set synthetic-token-holder-balances sender-address sender-new-balance)
                        (map-set synthetic-token-holder-balances recipient-address recipient-new-balance)
                        (ok true))
                error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

;; Public functions
(define-public (update-oracle-price (new-asset-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMINISTRATOR) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (> new-asset-price u0) ERR-INVALID-PRICE)
        (asserts! (< new-asset-price MAXIMUM-PRICE) ERR-INVALID-PRICE)
        (var-set oracle-current-asset-price new-asset-price)
        (var-set oracle-price-last-update-block block-height)
        (ok true))
)

(define-public (mint-synthetic-tokens (token-amount uint))
    (let (
        (current-price (var-get oracle-current-asset-price))
    )
    (asserts! (> token-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= token-amount MINIMUM-SYNTHETIC-TOKEN-MINT) ERR-INVALID-TOKEN-AMOUNT)
    (asserts! (<= (- block-height (var-get oracle-price-last-update-block)) 
                 ORACLE-PRICE-EXPIRY-BLOCKS) 
              ERR-ORACLE-PRICE-EXPIRED)

    (match (safe-multiply token-amount (/ current-price u100))
        required-base-collateral 
        (match (safe-multiply required-base-collateral (/ REQUIRED-COLLATERAL-RATIO u100))
            minimum-required-collateral
            (match (stx-transfer? minimum-required-collateral tx-sender (as-contract tx-sender))
                success
                (begin
                    (map-set user-collateral-vault tx-sender
                        {
                            deposited-collateral-amount: minimum-required-collateral,
                            minted-synthetic-tokens: token-amount,
                            collateral-locked-at-price: current-price
                        })
                    (match (safe-add (get-synthetic-token-balance tx-sender) token-amount)
                        new-balance
                        (begin
                            (map-set synthetic-token-holder-balances tx-sender new-balance)
                            (match (safe-add (var-get synthetic-token-total-supply) token-amount)
                                new-supply
                                (begin
                                    (var-set synthetic-token-total-supply new-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-INSUFFICIENT-COLLATERAL-DEPOSIT)
            error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)
