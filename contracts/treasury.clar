;; HiveGuard Treasury Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))

;; Data Variables
(define-data-var spending-limit uint u1000000) ;; 1M uSTX
(define-data-var required-approvals uint u2)

;; Maps
(define-map withdrawal-requests
  { request-id: uint }
  {
    amount: uint,
    recipient: principal,
    approvals: uint,
    status: (string-ascii 10)
  }
)

;; Events
(define-data-var request-nonce uint u0)

;; Read-only functions
(define-read-only (get-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-withdrawal-request (request-id uint))
  (map-get? withdrawal-requests {request-id: request-id})
)

;; Private functions
(define-private (is-authorized)
  (is-eq tx-sender contract-owner)
)

;; Public functions
(define-public (deposit)
  (begin
    (print {event: "treasury-deposit", amount: (stx-get-balance (as-contract tx-sender))})
    (ok true)
  )
)

(define-public (request-withdrawal (amount uint) (recipient principal))
  (let
    (
      (new-request-id (+ (var-get request-nonce) u1))
    )
    (asserts! (is-authorized) err-unauthorized)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount (var-get spending-limit)) err-unauthorized)
    
    (map-set withdrawal-requests
      {request-id: new-request-id}
      {
        amount: amount,
        recipient: recipient,
        approvals: u1,
        status: "pending"
      }
    )
    
    (var-set request-nonce new-request-id)
    (print {event: "withdrawal-requested", request-id: new-request-id, amount: amount, recipient: recipient})
    (ok new-request-id)
  )
)

(define-public (approve-withdrawal (request-id uint))
  (let
    (
      (request (unwrap! (map-get? withdrawal-requests {request-id: request-id}) err-unauthorized))
      (new-approvals (+ (get approvals request) u1))
    )
    (asserts! (is-authorized) err-unauthorized)
    (asserts! (is-eq (get status request) "pending") err-unauthorized)
    
    (map-set withdrawal-requests
      {request-id: request-id}
      (merge request {approvals: new-approvals})
    )
    
    (if (>= new-approvals (var-get required-approvals))
      (try! (execute-withdrawal request-id))
      (ok true)
    )
  )
)

(define-private (execute-withdrawal (request-id uint))
  (let
    (
      (request (unwrap! (map-get? withdrawal-requests {request-id: request-id}) err-unauthorized))
      (current-balance (stx-get-balance (as-contract tx-sender)))
    )
    (asserts! (<= (get amount request) current-balance) err-insufficient-balance)
    
    (try! (as-contract (stx-transfer? (get amount request) tx-sender (get recipient request))))
    
    (map-set withdrawal-requests
      {request-id: request-id}
      (merge request {status: "executed"})
    )
    
    (print {event: "withdrawal-executed", request-id: request-id, amount: (get amount request), recipient: (get recipient request)})
    (ok true)
  )
)
