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
(define-constant ERR_INVALID_RATING (err u110))
(define-constant ERR_ALREADY_RATED (err u111))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u112))
(define-constant ERR_REWARD_NOT_FOUND (err u113))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u114))
(define-constant ERR_RESOURCE_NOT_FOUND (err u115))
(define-constant ERR_RESOURCE_UNAVAILABLE (err u116))
(define-constant ERR_RESOURCE_BOOKING_NOT_FOUND (err u117))
(define-constant ERR_RESOURCE_BOOKING_CONFLICT (err u118))
(define-constant ERR_INVALID_MAINTENANCE_PERIOD (err u119))

(define-data-var next-space-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-reward-id uint u1)
(define-data-var next-resource-id uint u1)
(define-data-var next-resource-booking-id uint u1)
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

(define-map user-reputation
  { user: principal }
  {
    total-points: uint,
    level: uint,
    bookings-completed: uint,
    spaces-hosted: uint,
    positive-reviews: uint,
    negative-reviews: uint,
    community-contributions: uint
  }
)

(define-map space-ratings
  { space-id: uint, rater: principal }
  {
    rating: uint,
    comment: (string-ascii 200),
    created-at: uint
  }
)

(define-map reputation-rewards
  { reward-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    points-required: uint,
    reward-amount: uint,
    max-claims: uint,
    current-claims: uint,
    active: bool,
    created-by: principal
  }
)

(define-map user-rewards-claimed
  { user: principal, reward-id: uint }
  { claimed-at: uint }
)

(define-map shared-resources
  { resource-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    space-id: uint,
    hourly-rate: uint,
    available: bool,
    requires-approval: bool,
    max-booking-duration: uint,
    owner: principal,
    total-bookings: uint,
    maintenance-start: uint,
    maintenance-end: uint
  }
)

(define-map resource-bookings
  { booking-id: uint }
  {
    resource-id: uint,
    user: principal,
    start-time: uint,
    end-time: uint,
    total-cost: uint,
    approved: bool,
    active: bool,
    purpose: (string-ascii 100)
  }
)

(define-map resource-availability-schedule
  { resource-id: uint, time-slot: uint }
  { available: bool }
)

(define-map resource-approval-requests
  { resource-id: uint, user: principal }
  {
    requested-at: uint,
    approved: bool,
    expires-at: uint
  }
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
    (initialize-user-reputation tx-sender)
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
    (award-reputation-points tx-sender u10 "space-hosted")
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
    (award-reputation-points tx-sender u5 "booking-made")
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
    (award-reputation-points (get user booking) u3 "booking-completed")
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
    (award-reputation-points tx-sender u2 "proposal-created")
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
    (award-reputation-points tx-sender u1 "voted-on-proposal")
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

(define-public (rate-space (space-id uint) (rating uint) (comment (string-ascii 200)))
  (begin
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (asserts! (is-some (map-get? spaces { space-id: space-id })) ERR_SPACE_NOT_FOUND)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (is-none (map-get? space-ratings { space-id: space-id, rater: tx-sender })) ERR_ALREADY_RATED)
    
    (map-set space-ratings
      { space-id: space-id, rater: tx-sender }
      {
        rating: rating,
        comment: comment,
        created-at: stacks-block-height
      }
    )
    
    (begin
      (if (>= rating u4)
        (award-reputation-points tx-sender u2 "positive-review-given")
        true
      )
      (ok true)
    )
  )
)

(define-public (create-reputation-reward 
  (name (string-ascii 50)) 
  (description (string-ascii 200)) 
  (points-required uint) 
  (reward-amount uint) 
  (max-claims uint))
  (let ((reward-id (var-get next-reward-id)))
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (asserts! (> points-required u0) ERR_INVALID_RATING)
    (asserts! (> reward-amount u0) ERR_INVALID_RATING)
    (asserts! (> max-claims u0) ERR_INVALID_RATING)
    
    (map-set reputation-rewards
      { reward-id: reward-id }
      {
        name: name,
        description: description,
        points-required: points-required,
        reward-amount: reward-amount,
        max-claims: max-claims,
        current-claims: u0,
        active: true,
        created-by: tx-sender
      }
    )
    
    (var-set next-reward-id (+ reward-id u1))
    (award-reputation-points tx-sender u5 "reward-created")
    (ok reward-id)
  )
)

(define-public (claim-reputation-reward (reward-id uint))
  (let (
    (reward (unwrap! (map-get? reputation-rewards { reward-id: reward-id }) ERR_REWARD_NOT_FOUND))
    (user-rep-data (get-user-reputation-data tx-sender))
    (user-points (get total-points user-rep-data))
  )
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (asserts! (get active reward) ERR_REWARD_NOT_FOUND)
    (asserts! (< (get current-claims reward) (get max-claims reward)) ERR_REWARD_NOT_FOUND)
    (asserts! (>= user-points (get points-required reward)) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (is-none (map-get? user-rewards-claimed { user: tx-sender, reward-id: reward-id })) ERR_REWARD_ALREADY_CLAIMED)
    
    (map-set user-rewards-claimed
      { user: tx-sender, reward-id: reward-id }
      { claimed-at: stacks-block-height }
    )
    
    (map-set reputation-rewards
      { reward-id: reward-id }
      (merge reward { current-claims: (+ (get current-claims reward) u1) })
    )
    
    (let ((current-balance (get-balance tx-sender)))
      (map-set user-balances
        { user: tx-sender }
        { balance: (+ current-balance (get reward-amount reward)) }
      )
    )
    
    (ok true)
  )
)

(define-public (toggle-reward-status (reward-id uint))
  (let ((reward (unwrap! (map-get? reputation-rewards { reward-id: reward-id }) ERR_REWARD_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get created-by reward)) ERR_NOT_AUTHORIZED)
    
    (map-set reputation-rewards
      { reward-id: reward-id }
      (merge reward { active: (not (get active reward)) })
    )
    (ok true)
  )
)

(define-public (add-shared-resource 
  (name (string-ascii 50)) 
  (description (string-ascii 200)) 
  (space-id uint) 
  (hourly-rate uint) 
  (requires-approval bool) 
  (max-booking-duration uint))
  (let ((resource-id (var-get next-resource-id)))
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (asserts! (is-some (map-get? spaces { space-id: space-id })) ERR_SPACE_NOT_FOUND)
    (asserts! (> max-booking-duration u0) ERR_INVALID_TIME)
    
    (map-set shared-resources
      { resource-id: resource-id }
      {
        name: name,
        description: description,
        space-id: space-id,
        hourly-rate: hourly-rate,
        available: true,
        requires-approval: requires-approval,
        max-booking-duration: max-booking-duration,
        owner: tx-sender,
        total-bookings: u0,
        maintenance-start: u0,
        maintenance-end: u0
      }
    )
    
    (var-set next-resource-id (+ resource-id u1))
    (award-reputation-points tx-sender u15 "resource-added")
    (ok resource-id)
  )
)

(define-public (book-shared-resource 
  (resource-id uint) 
  (start-time uint) 
  (duration uint) 
  (purpose (string-ascii 100)))
  (let (
    (resource (unwrap! (map-get? shared-resources { resource-id: resource-id }) ERR_RESOURCE_NOT_FOUND))
    (end-time (+ start-time duration))
    (total-cost (* (get hourly-rate resource) duration))
    (booking-id (var-get next-resource-booking-id))
  )
    (asserts! (is-member tx-sender) ERR_NOT_MEMBER)
    (asserts! (get available resource) ERR_RESOURCE_UNAVAILABLE)
    (asserts! (> duration u0) ERR_INVALID_TIME)
    (asserts! (<= duration (get max-booking-duration resource)) ERR_INVALID_TIME)
    (asserts! (is-resource-available-during-period resource-id start-time end-time) ERR_RESOURCE_BOOKING_CONFLICT)
    (try! (deduct-balance tx-sender total-cost))
    
    (map-set resource-bookings
      { booking-id: booking-id }
      {
        resource-id: resource-id,
        user: tx-sender,
        start-time: start-time,
        end-time: end-time,
        total-cost: total-cost,
        approved: (not (get requires-approval resource)),
        active: true,
        purpose: purpose
      }
    )
    
    (update-resource-booking-count resource-id)
    (block-resource-time-slots resource-id start-time end-time)
    (award-reputation-points tx-sender u3 "resource-booked")
    (var-set next-resource-booking-id (+ booking-id u1))
    (ok booking-id)
  )
)

(define-public (cancel-resource-booking (booking-id uint))
  (let ((booking (unwrap! (map-get? resource-bookings { booking-id: booking-id }) ERR_RESOURCE_BOOKING_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get user booking)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
    (asserts! (get active booking) ERR_RESOURCE_BOOKING_NOT_FOUND)
    
    (map-set resource-bookings
      { booking-id: booking-id }
      (merge booking { active: false })
    )
    
    (free-resource-time-slots (get resource-id booking) (get start-time booking) (get end-time booking))
    (let ((current-balance (get-balance (get user booking))))
      (map-set user-balances
        { user: (get user booking) }
        { balance: (+ current-balance (get total-cost booking)) }
      )
    )
    (ok true)
  )
)

(define-public (approve-resource-booking (booking-id uint))
  (let (
    (booking (unwrap! (map-get? resource-bookings { booking-id: booking-id }) ERR_RESOURCE_BOOKING_NOT_FOUND))
    (resource (unwrap! (map-get? shared-resources { resource-id: (get resource-id booking) }) ERR_RESOURCE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get owner resource)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get approved booking)) ERR_NOT_AUTHORIZED)
    (asserts! (get active booking) ERR_RESOURCE_BOOKING_NOT_FOUND)
    
    (map-set resource-bookings
      { booking-id: booking-id }
      (merge booking { approved: true })
    )
    (ok true)
  )
)

(define-public (schedule-resource-maintenance (resource-id uint) (start-time uint) (end-time uint))
  (let ((resource (unwrap! (map-get? shared-resources { resource-id: resource-id }) ERR_RESOURCE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner resource)) ERR_NOT_AUTHORIZED)
    (asserts! (< start-time end-time) ERR_INVALID_MAINTENANCE_PERIOD)
    (asserts! (is-resource-available-during-period resource-id start-time end-time) ERR_RESOURCE_BOOKING_CONFLICT)
    
    (map-set shared-resources
      { resource-id: resource-id }
      (merge resource {
        maintenance-start: start-time,
        maintenance-end: end-time,
        available: false
      })
    )
    
    (block-resource-time-slots resource-id start-time end-time)
    (ok true)
  )
)

(define-public (complete-resource-maintenance (resource-id uint))
  (let ((resource (unwrap! (map-get? shared-resources { resource-id: resource-id }) ERR_RESOURCE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner resource)) ERR_NOT_AUTHORIZED)
    (asserts! (> (get maintenance-end resource) u0) ERR_INVALID_MAINTENANCE_PERIOD)
    
    (map-set shared-resources
      { resource-id: resource-id }
      (merge resource {
        maintenance-start: u0,
        maintenance-end: u0,
        available: true
      })
    )
    
    (free-resource-time-slots resource-id (get maintenance-start resource) (get maintenance-end resource))
    (ok true)
  )
)

(define-public (toggle-resource-availability (resource-id uint))
  (let ((resource (unwrap! (map-get? shared-resources { resource-id: resource-id }) ERR_RESOURCE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner resource)) ERR_NOT_AUTHORIZED)
    
    (map-set shared-resources
      { resource-id: resource-id }
      (merge resource { available: (not (get available resource)) })
    )
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

(define-read-only (get-user-reputation (user principal))
  (map-get? user-reputation { user: user })
)

(define-read-only (get-space-rating (space-id uint) (rater principal))
  (map-get? space-ratings { space-id: space-id, rater: rater })
)

(define-read-only (get-reputation-reward (reward-id uint))
  (map-get? reputation-rewards { reward-id: reward-id })
)

(define-read-only (get-user-reward-claim (user principal) (reward-id uint))
  (map-get? user-rewards-claimed { user: user, reward-id: reward-id })
)

(define-read-only (get-user-reputation-level (user principal))
  (let ((reputation-data (get-user-reputation-data user)))
    (get level reputation-data)
  )
)

(define-read-only (get-user-reputation-points (user principal))
  (let ((reputation-data (get-user-reputation-data user)))
    (get total-points reputation-data)
  )
)

(define-read-only (get-shared-resource (resource-id uint))
  (map-get? shared-resources { resource-id: resource-id })
)

(define-read-only (get-resource-booking (booking-id uint))
  (map-get? resource-bookings { booking-id: booking-id })
)

(define-read-only (get-resource-availability (resource-id uint) (time-slot uint))
  (default-to true (get available (map-get? resource-availability-schedule { resource-id: resource-id, time-slot: time-slot })))
)

(define-read-only (is-resource-under-maintenance (resource-id uint) (check-time uint))
  (let ((resource (map-get? shared-resources { resource-id: resource-id })))
    (match resource
      resource-data 
        (and 
          (> (get maintenance-end resource-data) u0)
          (>= check-time (get maintenance-start resource-data))
          (<= check-time (get maintenance-end resource-data))
        )
      false
    )
  )
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

(define-private (initialize-user-reputation (user principal))
  (map-set user-reputation
    { user: user }
    {
      total-points: u0,
      level: u1,
      bookings-completed: u0,
      spaces-hosted: u0,
      positive-reviews: u0,
      negative-reviews: u0,
      community-contributions: u0
    }
  )
)

(define-private (get-user-reputation-data (user principal))
  (default-to
    {
      total-points: u0,
      level: u1,
      bookings-completed: u0,
      spaces-hosted: u0,
      positive-reviews: u0,
      negative-reviews: u0,
      community-contributions: u0
    }
    (map-get? user-reputation { user: user })
  )
)

(define-private (calculate-reputation-level (points uint))
  (if (<= points u50)
    u1
    (if (<= points u150)
      u2
      (if (<= points u300)
        u3
        (if (<= points u500)
          u4
          u5
        )
      )
    )
  )
)

(define-private (award-reputation-points (user principal) (points uint) (activity (string-ascii 50)))
  (let (
    (current-reputation (get-user-reputation-data user))
    (new-total-points (+ (get total-points current-reputation) points))
    (new-level (calculate-reputation-level new-total-points))
  )
    (map-set user-reputation
      { user: user }
      (merge current-reputation {
        total-points: new-total-points,
        level: new-level,
        bookings-completed: (if (is-eq activity "booking-completed")
          (+ (get bookings-completed current-reputation) u1)
          (get bookings-completed current-reputation)
        ),
        spaces-hosted: (if (is-eq activity "space-hosted")
          (+ (get spaces-hosted current-reputation) u1)
          (get spaces-hosted current-reputation)
        ),
        positive-reviews: (if (is-eq activity "positive-review-given")
          (+ (get positive-reviews current-reputation) u1)
          (get positive-reviews current-reputation)
        ),
        community-contributions: (if (or (is-eq activity "proposal-created") (is-eq activity "reward-created"))
          (+ (get community-contributions current-reputation) u1)
          (get community-contributions current-reputation)
        )
      })
    )
  )
)

(define-private (is-resource-available-during-period (resource-id uint) (start-time uint) (end-time uint))
  (let ((resource (unwrap-panic (map-get? shared-resources { resource-id: resource-id }))))
    (and
      (get available resource)
      (or
        (is-eq (get maintenance-end resource) u0)
        (or
          (< end-time (get maintenance-start resource))
          (> start-time (get maintenance-end resource))
        )
      )
      (simple-availability-check resource-id start-time end-time)
    )
  )
)

(define-private (simple-availability-check (resource-id uint) (start-time uint) (end-time uint))
  (and
    (get-resource-availability resource-id start-time)
    (get-resource-availability resource-id end-time)
  )
)

(define-private (block-resource-time-slots (resource-id uint) (start-time uint) (end-time uint))
  (begin
    (map-set resource-availability-schedule
      { resource-id: resource-id, time-slot: start-time }
      { available: false }
    )
    (map-set resource-availability-schedule
      { resource-id: resource-id, time-slot: end-time }
      { available: false }
    )
    true
  )
)

(define-private (free-resource-time-slots (resource-id uint) (start-time uint) (end-time uint))
  (begin
    (map-set resource-availability-schedule
      { resource-id: resource-id, time-slot: start-time }
      { available: true }
    )
    (map-set resource-availability-schedule
      { resource-id: resource-id, time-slot: end-time }
      { available: true }
    )
    true
  )
)

(define-private (update-resource-booking-count (resource-id uint))
  (let ((resource (unwrap-panic (map-get? shared-resources { resource-id: resource-id }))))
    (map-set shared-resources
      { resource-id: resource-id }
      (merge resource { total-bookings: (+ (get total-bookings resource) u1) })
    )
  )
)



