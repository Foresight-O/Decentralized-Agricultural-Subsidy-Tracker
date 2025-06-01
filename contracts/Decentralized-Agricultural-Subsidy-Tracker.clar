(define-data-var admin principal tx-sender)
(define-data-var next-farmer-id uint u1)
(define-data-var next-subsidy-id uint u1)
(define-data-var total-subsidies-distributed uint u0)
(define-data-var total-farmers-registered uint u0)

(define-map farmers
  { farmer-id: uint }
  {
    principal: principal,
    name: (string-ascii 100),
    location: (string-ascii 100),
    farm-size: uint,
    crop-type: (string-ascii 50),
    verified: bool,
    registration-time: uint
  }
)

(define-map subsidies
  { subsidy-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 255),
    amount: uint,
    start-date: uint,
    end-date: uint,
    active: bool,
    eligibility-criteria: (string-ascii 255)
  }
)

(define-map farmer-subsidies
  { farmer-id: uint, subsidy-id: uint }
  {
    amount-received: uint,
    date-received: uint,
    status: (string-ascii 20)
  }
)

(define-map verifiers
  { verifier-id: principal }
  {
    name: (string-ascii 100),
    active: bool,
    verification-count: uint
  }
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (var-set admin new-admin))
  )
)

(define-public (register-farmer (name (string-ascii 100)) (location (string-ascii 100)) (farm-size uint) (crop-type (string-ascii 50)))
  (let ((id (var-get next-farmer-id)))
    (asserts! (is-none (map-get? farmers { farmer-id: id })) (err u400))
    (map-set farmers
      { farmer-id: id }
      {
        principal: tx-sender,
        name: name,
        location: location,
        farm-size: farm-size,
        crop-type: crop-type,
        verified: false,
        registration-time: stacks-block-height
      }
    )
    (var-set total-farmers-registered (+ (var-get total-farmers-registered) u1))
    (var-set next-farmer-id (+ id u1))
    (ok id)
  )
)

(define-public (add-verifier (verifier principal) (name (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-none (map-get? verifiers { verifier-id: verifier })) (err u400))
    (map-set verifiers
      { verifier-id: verifier }
      {
        name: name,
        active: true,
        verification-count: u0
      }
    )
    (ok true)
  )
)

(define-public (verify-farmer (farmer-id uint))
  (let (
    (verifier-info (map-get? verifiers { verifier-id: tx-sender }))
    (farmer-info (map-get? farmers { farmer-id: farmer-id }))
  )
    (asserts! (is-some verifier-info) (err u403))
    (asserts! (is-some farmer-info) (err u404))
    (asserts! (get active (unwrap-panic verifier-info)) (err u403))
    (asserts! (not (get verified (unwrap-panic farmer-info))) (err u400))
    (map-set farmers
      { farmer-id: farmer-id }
      (merge (unwrap-panic farmer-info) { verified: true })
    )
    (map-set verifiers
      { verifier-id: tx-sender }
      (merge (unwrap-panic verifier-info) { verification-count: (+ (get verification-count (unwrap-panic verifier-info)) u1) })
    )
    (ok true)
  )
)

(define-public (create-subsidy (name (string-ascii 100)) (description (string-ascii 255)) (amount uint) (start-date uint) (end-date uint) (eligibility-criteria (string-ascii 255)))
  (let ((id (var-get next-subsidy-id)))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (>= end-date start-date) (err u400))
    (map-set subsidies
      { subsidy-id: id }
      {
        name: name,
        description: description,
        amount: amount,
        start-date: start-date,
        end-date: end-date,
        active: true,
        eligibility-criteria: eligibility-criteria
      }
    )
    (var-set next-subsidy-id (+ id u1))
    (ok id)
  )
)

(define-public (deactivate-subsidy (subsidy-id uint))
  (let ((subsidy-info (map-get? subsidies { subsidy-id: subsidy-id })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some subsidy-info) (err u404))
    (map-set subsidies
      { subsidy-id: subsidy-id }
      (merge (unwrap-panic subsidy-info) { active: false })
    )
    (ok true)
  )
)

(define-public (distribute-subsidy (farmer-id uint) (subsidy-id uint))
  (let (
    (farmer-info (map-get? farmers { farmer-id: farmer-id }))
    (subsidy-info (map-get? subsidies { subsidy-id: subsidy-id }))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some farmer-info) (err u404))
    (asserts! (is-some subsidy-info) (err u404))
    (asserts! (get verified (unwrap-panic farmer-info)) (err u400))
    (asserts! (get active (unwrap-panic subsidy-info)) (err u400))
    (asserts! (is-none (map-get? farmer-subsidies { farmer-id: farmer-id, subsidy-id: subsidy-id })) (err u400))
    (map-set farmer-subsidies
      { farmer-id: farmer-id, subsidy-id: subsidy-id }
      {
        amount-received: (get amount (unwrap-panic subsidy-info)),
        date-received: stacks-block-height,
        status: "distributed"
      }
    )
    (var-set total-subsidies-distributed (+ (var-get total-subsidies-distributed) (get amount (unwrap-panic subsidy-info))))
    (ok true)
  )
)
