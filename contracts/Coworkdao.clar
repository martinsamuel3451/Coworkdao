;; title: Coworkdao
;; version: 1.0.0
;; summary: Decentralized co-working space management system
;; description: A DAO for managing shared office spaces with booking, membership, and governance features

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_SPACE_NOT_FOUND (err u101))
(define-constant ERR_SPACE_OCCUPIED (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_BOOKING_NOT_FOUND (err u104))
(define-constant ERR_INVALID_TIME (err u105))
(define-constant ERR_NOT_MEMBER (err u106))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u107))
(define-constant ERR_ALREADY_VOTED (err u108))
(define-constant ERR_VOTING_ENDED (err u109))

(define-data-var next-space-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var membership-fee uint u1000000)
(define-data-var booking-fee-per-hour uint u100000)

(define-map spaces
  { space-id: uint }
  {
    name: (string-ascii 50),
    capacity: uint,
    hourly-rate: uint,
    available: bool,
    owner: principal
  }
)

(define-map bookings
  { booking-id: uint }
  {
    space-id: uint,
    user: principal,
    start-time: uint,
    end-time: uint,
    total-cost: uint,
    active: bool
  }
)

(define-map members
  { user: principal }
  {
    joined-at: uint,
    voting-power: uint,
    total-bookings: uint
  }
)

(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-public (join-dao)
  (let ((membership-cost (var-get membership-fee)))
    (try! (deduct-balance tx-sender membership-cost))
    (map-set members
      { user: tx-sender }
      {
        joined-at: stacks-block-height,
        voting-power: u1,
        total-bookings: u0
      }
    )
    (ok true)
  )
)

(define-public (add-space (name (string-ascii 50)) (capacity uint) (hourly-rate uint))
  (let ((space-id (var-get next-space-id)))
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (map-set spaces
      { space-id: space-id }
      {
        name: name,
        capacity: capacity,
        hourly-rate: hourly-rate,
        available: true,
        owner: tx-sender
      }
    )
    (var-set next-space-id (+ space-id u1))
    (ok space-id)
  )
)

(define-public (book-space (space-id uint) (start-time uint) (duration uint))
  (let (
    (space (unwrap! (map-get? spaces { space-id: space-id }) ERR_SPACE_NOT_FOUND))
    (end-time (+ start-time duration))
    (total-cost (* (get hourly-rate space) duration))
    (booking-id (var-get next-booking-id))
  )
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (asserts! (get available space) ERR_SPACE_OCCUPIED)
    (asserts! (> duration u0) ERR_INVALID_TIME)
    (try! (deduct-balance tx-sender total-cost))
    
    (map-set bookings
      { booking-id: booking-id }
      {
        space-id: space-id,
        user: tx-sender,
        start-time: start-time,
        end-time: end-time,
        total-cost: total-cost,
        active: true
      }
    )
    
    (map-set spaces
      { space-id: space-id }
      (merge space { available: false })
    )
    
    (update-member-stats tx-sender)
    (var-set next-booking-id (+ booking-id u1))
    (ok booking-id)
  )
)

(define-public (end-booking (booking-id uint))
  (let ((booking (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_BOOKING_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get user booking)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (asserts! (get active booking) ERR_BOOKING_NOT_FOUND)
    
    (map-set bookings
      { booking-id: booking-id }
      (merge booking { active: false })
    )
    
    (map-set spaces
      { space-id: (get space-id booking) }
      (merge (unwrap-panic (map-get? spaces { space-id: (get space-id booking) })) { available: true })
    )
    (ok true)
  )
)

(define-public (deposit-funds (amount uint))
  (let ((current-balance (get-balance tx-sender)))
    (map-set user-balances
      { user: tx-sender }
      { balance: (+ current-balance amount) }
    )
    (ok true)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        end-block: (+ stacks-block-height u1440),
        executed: false
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (member-data (unwrap! (map-get? members { user: tx-sender }) ERR_NOT_MEMBER))
    (voting-power (get voting-power member-data))
  )
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    (asserts! (< stacks-block-height (get end-block proposal)) ERR_VOTING_ENDED)
    
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for }
    )
    
    (if vote-for
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) voting-power) })
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) voting-power) })
      )
    )
    (ok true)
  )
)

(define-public (update-membership-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set membership-fee new-fee)
    (ok true)
  )
)

(define-public (update-booking-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set booking-fee-per-hour new-fee)
    (ok true)
  )
)

(define-read-only (get-space (space-id uint))
  (map-get? spaces { space-id: space-id })
)

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings { booking-id: booking-id })
)

(define-read-only (get-member (user principal))
  (map-get? members { user: user })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-membership-fee)
  (var-get membership-fee)
)

(define-read-only (get-booking-fee)
  (var-get booking-fee-per-hour)
)

(define-read-only (is-member (user principal))
  (is-some (map-get? members { user: user }))
)

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-private (deduct-balance (user principal) (amount uint))
  (let ((current-balance (get-balance user)))
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set user-balances
      { user: user }
      { balance: (- current-balance amount) }
    )
    (ok true)
  )
)

(define-private (update-member-stats (user principal))
  (let ((member-data (unwrap-panic (map-get? members { user: user }))))
    (map-set members
      { user: user }
      (merge member-data { 
        total-bookings: (+ (get total-bookings member-data) u1),
        voting-power: (+ (get voting-power member-data) u1)
      })
    )
  )
)