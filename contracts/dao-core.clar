;; HiveGuard DAO Core Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-proposal (err u101))
(define-constant err-proposal-expired (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-not-member (err u104))

;; Data Variables
(define-data-var minimum-quorum uint u500)
(define-data-var voting-period uint u144) ;; ~24 hours in blocks
(define-data-var current-proposal-id uint u0)
(define-data-var paused bool false)

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    creator: principal,
    title: (string-ascii 50),
    description: (string-utf8 500),
    start-block: uint,
    end-block: uint,
    status: (string-ascii 10),
    votes-for: uint,
    votes-against: uint,
    executed: bool
  }
)

(define-map members
  { address: principal }
  { 
    voting-power: uint,
    delegate: (optional principal)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { voted: bool }
)

;; Private Functions
(define-private (is-member)
  (is-some (map-get? members {address: tx-sender}))
)

(define-private (check-proposal-state (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) err-invalid-proposal))
  )
    (asserts! (< block-height (get end-block proposal)) err-proposal-expired)
    (ok true)
  )
)

;; Public Functions
(define-public (create-proposal (title (string-ascii 50)) (description (string-utf8 500)))
  (let
    (
      (proposal-id (+ (var-get current-proposal-id) u1))
      (start-block block-height)
      (end-block (+ block-height (var-get voting-period)))
    )
    (asserts! (is-member) err-not-member)
    (asserts! (not (var-get paused)) err-unauthorized)
    
    (map-set proposals
      {proposal-id: proposal-id}
      {
        creator: tx-sender,
        title: title,
        description: description,
        start-block: start-block,
        end-block: end-block,
        status: "active",
        votes-for: u0,
        votes-against: u0,
        executed: false
      }
    )
    
    (var-set current-proposal-id proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) err-invalid-proposal))
      (voter-power (unwrap! (get voting-power (map-get? members {address: tx-sender})) err-not-member))
    )
    (asserts! (not (var-get paused)) err-unauthorized)
    (try! (check-proposal-state proposal-id))
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
    
    (map-set votes {proposal-id: proposal-id, voter: tx-sender} {voted: true})
    
    (if support
      (map-set proposals {proposal-id: proposal-id}
        (merge proposal {votes-for: (+ (get votes-for proposal) voter-power)}))
      (map-set proposals {proposal-id: proposal-id}
        (merge proposal {votes-against: (+ (get votes-against proposal) voter-power)}))
    )
    
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) err-invalid-proposal))
  )
    (asserts! (not (var-get paused)) err-unauthorized)
    (asserts! (>= block-height (get end-block proposal)) err-invalid-proposal)
    (asserts! (not (get executed proposal)) err-invalid-proposal)
    (asserts! (>= (get votes-for proposal) (var-get minimum-quorum)) err-invalid-proposal)
    
    (map-set proposals {proposal-id: proposal-id}
      (merge proposal {
        status: "executed",
        executed: true
      })
    )
    
    (ok true)
  )
)

;; Admin Functions
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (var-set paused new-paused)
    (ok true)
  )
)
