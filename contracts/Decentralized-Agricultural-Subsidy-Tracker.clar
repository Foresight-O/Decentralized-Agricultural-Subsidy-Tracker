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
(define-data-var next-application-id uint u1)

(define-map subsidy-applications
  { application-id: uint }
  {
    farmer-id: uint,
    subsidy-id: uint,
    application-date: uint,
    status: (string-ascii 20),
    justification: (string-ascii 500),
    admin-notes: (string-ascii 500),
    review-date: (optional uint)
  }
)

(define-map farmer-application-history
  { farmer-id: uint }
  {
    total-applications: uint,
    approved-applications: uint,
    rejected-applications: uint,
    pending-applications: uint
  }
)

(define-public (apply-for-subsidy (farmer-id uint) (subsidy-id uint) (justification (string-ascii 500)))
  (let (
    (farmer-info (map-get? farmers { farmer-id: farmer-id }))
    (subsidy-info (map-get? subsidies { subsidy-id: subsidy-id }))
    (application-id (var-get next-application-id))
    (farmer-history (default-to { total-applications: u0, approved-applications: u0, rejected-applications: u0, pending-applications: u0 }
                                (map-get? farmer-application-history { farmer-id: farmer-id })))
  )
    (asserts! (is-some farmer-info) (err u404))
    (asserts! (is-some subsidy-info) (err u404))
    (asserts! (is-eq tx-sender (get principal (unwrap-panic farmer-info))) (err u403))
    (asserts! (get verified (unwrap-panic farmer-info)) (err u400))
    (asserts! (get active (unwrap-panic subsidy-info)) (err u400))
    (asserts! (<= stacks-block-height (get end-date (unwrap-panic subsidy-info))) (err u400))
    (asserts! (is-none (map-get? farmer-subsidies { farmer-id: farmer-id, subsidy-id: subsidy-id })) (err u400))
    (map-set subsidy-applications
      { application-id: application-id }
      {
        farmer-id: farmer-id,
        subsidy-id: subsidy-id,
        application-date: stacks-block-height,
        status: "pending",
        justification: justification,
        admin-notes: "",
        review-date: none
      }
    )
    (map-set farmer-application-history
      { farmer-id: farmer-id }
      {
        total-applications: (+ (get total-applications farmer-history) u1),
        approved-applications: (get approved-applications farmer-history),
        rejected-applications: (get rejected-applications farmer-history),
        pending-applications: (+ (get pending-applications farmer-history) u1)
      }
    )
    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

(define-public (review-application (application-id uint) (approve bool) (admin-notes (string-ascii 500)))
  (let (
    (application-info (map-get? subsidy-applications { application-id: application-id }))
    (farmer-history (unwrap-panic (map-get? farmer-application-history { farmer-id: (get farmer-id (unwrap-panic application-info)) })))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some application-info) (err u404))
    (asserts! (is-eq (get status (unwrap-panic application-info)) "pending") (err u400))
    (if approve
      (begin
        (try! (distribute-subsidy (get farmer-id (unwrap-panic application-info)) (get subsidy-id (unwrap-panic application-info))))
        (map-set subsidy-applications
          { application-id: application-id }
          (merge (unwrap-panic application-info) { status: "approved", admin-notes: admin-notes, review-date: (some stacks-block-height) })
        )
        (map-set farmer-application-history
          { farmer-id: (get farmer-id (unwrap-panic application-info)) }
          {
            total-applications: (get total-applications farmer-history),
            approved-applications: (+ (get approved-applications farmer-history) u1),
            rejected-applications: (get rejected-applications farmer-history),
            pending-applications: (- (get pending-applications farmer-history) u1)
          }
        )
      )
      (begin
        (map-set subsidy-applications
          { application-id: application-id }
          (merge (unwrap-panic application-info) { status: "rejected", admin-notes: admin-notes, review-date: (some stacks-block-height) })
        )
        (map-set farmer-application-history
          { farmer-id: (get farmer-id (unwrap-panic application-info)) }
          {
            total-applications: (get total-applications farmer-history),
            approved-applications: (get approved-applications farmer-history),
            rejected-applications: (+ (get rejected-applications farmer-history) u1),
            pending-applications: (- (get pending-applications farmer-history) u1)
          }
        )
      )
    )
    (ok approve)
  )
)

(define-read-only (get-application (application-id uint))
  (map-get? subsidy-applications { application-id: application-id })
)

(define-read-only (get-farmer-application-history (farmer-id uint))
  (map-get? farmer-application-history { farmer-id: farmer-id })
)
(define-data-var required-signatures uint u2)
(define-data-var next-proposal-id uint u1)
(define-data-var signature-threshold uint u1000000)

(define-map authorized-signers
  { signer: principal }
  {
    active: bool,
    added-at: uint
  }
)

(define-map proposals
  { proposal-id: uint }
  {
    proposal-type: (string-ascii 50),
    target-farmer-id: uint,
    target-subsidy-id: uint,
    amount: uint,
    created-by: principal,
    created-at: uint,
    executed: bool,
    signatures-count: uint,
    description: (string-ascii 255)
  }
)

(define-map proposal-signatures
  { proposal-id: uint, signer: principal }
  {
    signed: bool,
    signed-at: uint
  }
)

(define-public (add-authorized-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-none (map-get? authorized-signers { signer: signer })) (err u400))
    (map-set authorized-signers
      { signer: signer }
      {
        active: true,
        added-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (remove-authorized-signer (signer principal))
  (let ((signer-info (map-get? authorized-signers { signer: signer })))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some signer-info) (err u404))
    (map-set authorized-signers
      { signer: signer }
      (merge (unwrap-panic signer-info) { active: false })
    )
    (ok true)
  )
)

(define-public (create-subsidy-proposal (farmer-id uint) (subsidy-id uint) (description (string-ascii 255)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (subsidy-info (map-get? subsidies { subsidy-id: subsidy-id }))
    (signer-info (map-get? authorized-signers { signer: tx-sender }))
  )
    (asserts! (is-some signer-info) (err u403))
    (asserts! (get active (unwrap-panic signer-info)) (err u403))
    (asserts! (is-some subsidy-info) (err u404))
    (asserts! (>= (get amount (unwrap-panic subsidy-info)) (var-get signature-threshold)) (err u400))
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposal-type: "subsidy-distribution",
        target-farmer-id: farmer-id,
        target-subsidy-id: subsidy-id,
        amount: (get amount (unwrap-panic subsidy-info)),
        created-by: tx-sender,
        created-at: stacks-block-height,
        executed: false,
        signatures-count: u0,
        description: description
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (sign-proposal (proposal-id uint))
  (let (
    (proposal-info (map-get? proposals { proposal-id: proposal-id }))
    (signer-info (map-get? authorized-signers { signer: tx-sender }))
    (existing-signature (map-get? proposal-signatures { proposal-id: proposal-id, signer: tx-sender }))
  )
    (asserts! (is-some signer-info) (err u403))
    (asserts! (get active (unwrap-panic signer-info)) (err u403))
    (asserts! (is-some proposal-info) (err u404))
    (asserts! (not (get executed (unwrap-panic proposal-info))) (err u400))
    (asserts! (is-none existing-signature) (err u400))
    (map-set proposal-signatures
      { proposal-id: proposal-id, signer: tx-sender }
      {
        signed: true,
        signed-at: stacks-block-height
      }
    )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge (unwrap-panic proposal-info) { signatures-count: (+ (get signatures-count (unwrap-panic proposal-info)) u1) })
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal-info (map-get? proposals { proposal-id: proposal-id }))
    (signer-info (map-get? authorized-signers { signer: tx-sender }))
  )
    (asserts! (is-some signer-info) (err u403))
    (asserts! (get active (unwrap-panic signer-info)) (err u403))
    (asserts! (is-some proposal-info) (err u404))
    (asserts! (not (get executed (unwrap-panic proposal-info))) (err u400))
    (asserts! (>= (get signatures-count (unwrap-panic proposal-info)) (var-get required-signatures)) (err u400))
    (try! (if (is-eq (get proposal-type (unwrap-panic proposal-info)) "subsidy-distribution")
      (distribute-subsidy (get target-farmer-id (unwrap-panic proposal-info)) (get target-subsidy-id (unwrap-panic proposal-info)))
      (err u400)
    ))
    (map-set proposals
      { proposal-id: proposal-id }
      (merge (unwrap-panic proposal-info) { executed: true })
    )
    (ok true)
  )
)

(define-public (set-required-signatures (new-requirement uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (> new-requirement u0) (err u400))
    (var-set required-signatures new-requirement)
    (ok true)
  )
)

(define-public (set-signature-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set signature-threshold new-threshold)
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-signature (proposal-id uint) (signer principal))
  (map-get? proposal-signatures { proposal-id: proposal-id, signer: signer })
)

(define-read-only (is-authorized-signer (signer principal))
  (match (map-get? authorized-signers { signer: signer })
    signer-info (get active signer-info)
    false
  )
)

(define-data-var next-fraud-report-id uint u1)

(define-map fraud-reports
  { report-id: uint }
  {
    reporter: principal,
    target-farmer-id: uint,
    target-subsidy-id: uint,
    report-type: (string-ascii 50),
    description: (string-ascii 500),
    evidence-hash: (string-ascii 64),
    status: (string-ascii 20),
    reported-at: uint,
    reviewed-at: (optional uint),
    reviewer: (optional principal),
    admin-notes: (string-ascii 500)
  }
)

(define-map fraud-statistics
  { farmer-id: uint }
  {
    total-reports: uint,
    verified-reports: uint,
    pending-reports: uint,
    dismissed-reports: uint,
    fraud-score: uint
  }
)

(define-public (report-fraud 
  (target-farmer-id uint) 
  (target-subsidy-id uint) 
  (report-type (string-ascii 50)) 
  (description (string-ascii 500)) 
  (evidence-hash (string-ascii 64)))
  (let (
    (report-id (var-get next-fraud-report-id))
    (farmer-info (map-get? farmers { farmer-id: target-farmer-id }))
    (subsidy-info (map-get? subsidies { subsidy-id: target-subsidy-id }))
    (fraud-stats (default-to { total-reports: u0, verified-reports: u0, pending-reports: u0, dismissed-reports: u0, fraud-score: u0 }
                              (map-get? fraud-statistics { farmer-id: target-farmer-id })))
  )
    (asserts! (is-some farmer-info) (err u404))
    (asserts! (is-some subsidy-info) (err u404))
    (asserts! (not (is-eq tx-sender (get principal (unwrap-panic farmer-info)))) (err u400))
    (map-set fraud-reports
      { report-id: report-id }
      {
        reporter: tx-sender,
        target-farmer-id: target-farmer-id,
        target-subsidy-id: target-subsidy-id,
        report-type: report-type,
        description: description,
        evidence-hash: evidence-hash,
        status: "pending",
        reported-at: stacks-block-height,
        reviewed-at: none,
        reviewer: none,
        admin-notes: ""
      }
    )
    (map-set fraud-statistics
      { farmer-id: target-farmer-id }
      {
        total-reports: (+ (get total-reports fraud-stats) u1),
        verified-reports: (get verified-reports fraud-stats),
        pending-reports: (+ (get pending-reports fraud-stats) u1),
        dismissed-reports: (get dismissed-reports fraud-stats),
        fraud-score: (get fraud-score fraud-stats)
      }
    )
    (var-set next-fraud-report-id (+ report-id u1))
    (ok report-id)
  )
)

(define-public (review-fraud-report (report-id uint) (approve bool) (admin-notes (string-ascii 500)))
  (let (
    (report-info (map-get? fraud-reports { report-id: report-id }))
    (fraud-stats (unwrap-panic (map-get? fraud-statistics { farmer-id: (get target-farmer-id (unwrap-panic report-info)) })))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some report-info) (err u404))
    (asserts! (is-eq (get status (unwrap-panic report-info)) "pending") (err u400))
    (if approve
      (begin
        (map-set fraud-reports
          { report-id: report-id }
          (merge (unwrap-panic report-info) { 
            status: "verified", 
            reviewed-at: (some stacks-block-height), 
            reviewer: (some tx-sender), 
            admin-notes: admin-notes 
          })
        )
        (map-set fraud-statistics
          { farmer-id: (get target-farmer-id (unwrap-panic report-info)) }
          {
            total-reports: (get total-reports fraud-stats),
            verified-reports: (+ (get verified-reports fraud-stats) u1),
            pending-reports: (- (get pending-reports fraud-stats) u1),
            dismissed-reports: (get dismissed-reports fraud-stats),
            fraud-score: (+ (get fraud-score fraud-stats) u10)
          }
        )
      )
      (begin
        (map-set fraud-reports
          { report-id: report-id }
          (merge (unwrap-panic report-info) { 
            status: "dismissed", 
            reviewed-at: (some stacks-block-height), 
            reviewer: (some tx-sender), 
            admin-notes: admin-notes 
          })
        )
        (map-set fraud-statistics
          { farmer-id: (get target-farmer-id (unwrap-panic report-info)) }
          {
            total-reports: (get total-reports fraud-stats),
            verified-reports: (get verified-reports fraud-stats),
            pending-reports: (- (get pending-reports fraud-stats) u1),
            dismissed-reports: (+ (get dismissed-reports fraud-stats) u1),
            fraud-score: (get fraud-score fraud-stats)
          }
        )
      )
    )
    (ok approve)
  )
)

(define-read-only (get-fraud-report (report-id uint))
  (map-get? fraud-reports { report-id: report-id })
)

(define-read-only (get-fraud-statistics (farmer-id uint))
  (map-get? fraud-statistics { farmer-id: farmer-id })
)

(define-read-only (get-farmer-fraud-score (farmer-id uint))
  (match (map-get? fraud-statistics { farmer-id: farmer-id })
    stats (get fraud-score stats)
    u0
  )
)