(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CHARITY_NOT_FOUND (err u101))
(define-constant ERR_CHARITY_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_CHARITY_NOT_ACTIVE (err u105))
(define-constant ERR_SELF_DONATION (err u106))
(define-constant ERR_GOAL_NOT_FOUND (err u107))
(define-constant ERR_GOAL_EXPIRED (err u108))
(define-constant ERR_GOAL_ALREADY_ACHIEVED (err u109))

(define-data-var charity-counter uint u0)
(define-data-var donation-counter uint u0)
(define-data-var total-donations uint u0)
(define-data-var goal-counter uint u0)

(define-map charities
    { charity-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        wallet: principal,
        registration-block: uint,
        total-received: uint,
        total-withdrawn: uint,
        is-active: bool,
        category: (string-ascii 30),
        donation-count: uint,
    }
)

(define-map charity-by-wallet
    { wallet: principal }
    { charity-id: uint }
)

(define-map donations
    { donation-id: uint }
    {
        donor: principal,
        charity-id: uint,
        amount: uint,
        block-height: uint,
        message: (optional (string-ascii 100)),
    }
)

(define-map donor-stats
    { donor: principal }
    {
        total-donated: uint,
        donation-count: uint,
        first-donation-block: uint,
        last-donation-block: uint,
    }
)

(define-map charity-withdrawals
    {
        charity-id: uint,
        withdrawal-id: uint,
    }
    {
        amount: uint,
        block-height: uint,
        recipient: principal,
    }
)

(define-map withdrawal-counters
    { charity-id: uint }
    { count: uint }
)

(define-map charity-goals
    { goal-id: uint }
    {
        charity-id: uint,
        title: (string-ascii 100),
        description: (string-ascii 300),
        target-amount: uint,
        deadline-block: uint,
        current-amount: uint,
        created-block: uint,
        is-active: bool,
        achieved-block: (optional uint),
    }
)

(define-map charity-goal-list
    {
        charity-id: uint,
        goal-index: uint,
    }
    { goal-id: uint }
)

(define-map charity-goal-counts
    { charity-id: uint }
    { count: uint }
)

(define-public (register-charity
        (name (string-ascii 50))
        (description (string-ascii 200))
        (category (string-ascii 30))
    )
    (let (
            (charity-id (+ (var-get charity-counter) u1))
            (current-block stacks-block-height)
        )
        (asserts! (is-none (map-get? charity-by-wallet { wallet: tx-sender }))
            ERR_CHARITY_ALREADY_EXISTS
        )
        (asserts! (> (len name) u0) ERR_INVALID_AMOUNT)
        (asserts! (> (len description) u0) ERR_INVALID_AMOUNT)
        (map-set charities { charity-id: charity-id } {
            name: name,
            description: description,
            wallet: tx-sender,
            registration-block: current-block,
            total-received: u0,
            total-withdrawn: u0,
            is-active: true,
            category: category,
            donation-count: u0,
        })
        (map-set charity-by-wallet { wallet: tx-sender } { charity-id: charity-id })
        (var-set charity-counter charity-id)
        (ok charity-id)
    )
)

(define-public (deactivate-charity (charity-id uint))
    (let ((charity (unwrap! (map-get? charities { charity-id: charity-id })
            ERR_CHARITY_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (map-set charities { charity-id: charity-id }
            (merge charity { is-active: false })
        )
        (ok true)
    )
)

(define-public (reactivate-charity (charity-id uint))
    (let ((charity (unwrap! (map-get? charities { charity-id: charity-id })
            ERR_CHARITY_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (map-set charities { charity-id: charity-id }
            (merge charity { is-active: true })
        )
        (ok true)
    )
)

(define-public (donate
        (charity-id uint)
        (amount uint)
        (message (optional (string-ascii 100)))
    )
    (let (
            (charity (unwrap! (map-get? charities { charity-id: charity-id })
                ERR_CHARITY_NOT_FOUND
            ))
            (donation-id (+ (var-get donation-counter) u1))
            (current-block stacks-block-height)
            (charity-wallet (get wallet charity))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (get is-active charity) ERR_CHARITY_NOT_ACTIVE)
        (asserts! (not (is-eq tx-sender charity-wallet)) ERR_SELF_DONATION)

        (try! (stx-transfer? amount tx-sender charity-wallet))

        (map-set donations { donation-id: donation-id } {
            donor: tx-sender,
            charity-id: charity-id,
            amount: amount,
            block-height: current-block,
            message: message,
        })

        (map-set charities { charity-id: charity-id }
            (merge charity {
                total-received: (+ (get total-received charity) amount),
                donation-count: (+ (get donation-count charity) u1),
            })
        )

        (update-donor-stats tx-sender amount current-block)

        (var-set donation-counter donation-id)
        (var-set total-donations (+ (var-get total-donations) amount))
        (ok donation-id)
    )
)

(define-private (update-donor-stats
        (donor principal)
        (amount uint)
        (current-block uint)
    )
    (let ((existing-stats (map-get? donor-stats { donor: donor })))
        (match existing-stats
            existing (map-set donor-stats { donor: donor } {
                total-donated: (+ (get total-donated existing) amount),
                donation-count: (+ (get donation-count existing) u1),
                first-donation-block: (get first-donation-block existing),
                last-donation-block: current-block,
            })
            (map-set donor-stats { donor: donor } {
                total-donated: amount,
                donation-count: u1,
                first-donation-block: current-block,
                last-donation-block: current-block,
            })
        )
    )
)

(define-public (withdraw-funds (amount uint))
    (let (
            (charity-data (unwrap! (map-get? charity-by-wallet { wallet: tx-sender })
                ERR_NOT_AUTHORIZED
            ))
            (charity-id (get charity-id charity-data))
            (charity (unwrap! (map-get? charities { charity-id: charity-id })
                ERR_CHARITY_NOT_FOUND
            ))
            (available-balance (- (get total-received charity) (get total-withdrawn charity)))
            (withdrawal-count (default-to u0
                (get count
                    (map-get? withdrawal-counters { charity-id: charity-id })
                )))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount available-balance) ERR_INSUFFICIENT_BALANCE)
        (asserts! (get is-active charity) ERR_CHARITY_NOT_ACTIVE)

        (map-set charities { charity-id: charity-id }
            (merge charity { total-withdrawn: (+ (get total-withdrawn charity) amount) })
        )

        (map-set charity-withdrawals {
            charity-id: charity-id,
            withdrawal-id: withdrawal-count,
        } {
            amount: amount,
            block-height: stacks-block-height,
            recipient: tx-sender,
        })

        (map-set withdrawal-counters { charity-id: charity-id } { count: (+ withdrawal-count u1) })

        (ok true)
    )
)

(define-public (update-charity-info
        (charity-id uint)
        (name (string-ascii 50))
        (description (string-ascii 200))
        (category (string-ascii 30))
    )
    (let ((charity (unwrap! (map-get? charities { charity-id: charity-id })
            ERR_CHARITY_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (asserts! (> (len name) u0) ERR_INVALID_AMOUNT)
        (asserts! (> (len description) u0) ERR_INVALID_AMOUNT)
        (map-set charities { charity-id: charity-id }
            (merge charity {
                name: name,
                description: description,
                category: category,
            })
        )
        (ok true)
    )
)

(define-public (create-charity-goal
        (charity-id uint)
        (title (string-ascii 100))
        (description (string-ascii 300))
        (target-amount uint)
        (deadline-block uint)
    )
    (let (
            (charity (unwrap! (map-get? charities { charity-id: charity-id })
                ERR_CHARITY_NOT_FOUND
            ))
            (goal-id (+ (var-get goal-counter) u1))
            (current-block stacks-block-height)
            (goal-count (default-to u0
                (get count
                    (map-get? charity-goal-counts { charity-id: charity-id })
                )))
        )
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> deadline-block current-block) ERR_INVALID_AMOUNT)
        (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
        (asserts! (get is-active charity) ERR_CHARITY_NOT_ACTIVE)

        (map-set charity-goals { goal-id: goal-id } {
            charity-id: charity-id,
            title: title,
            description: description,
            target-amount: target-amount,
            deadline-block: deadline-block,
            current-amount: u0,
            created-block: current-block,
            is-active: true,
            achieved-block: none,
        })

        (map-set charity-goal-list {
            charity-id: charity-id,
            goal-index: goal-count,
        } { goal-id: goal-id }
        )

        (map-set charity-goal-counts { charity-id: charity-id } { count: (+ goal-count u1) })

        (var-set goal-counter goal-id)
        (ok goal-id)
    )
)

(define-public (deactivate-charity-goal (goal-id uint))
    (let (
            (goal (unwrap! (map-get? charity-goals { goal-id: goal-id })
                ERR_GOAL_NOT_FOUND
            ))
            (charity (unwrap! (map-get? charities { charity-id: (get charity-id goal) })
                ERR_CHARITY_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (map-set charity-goals { goal-id: goal-id }
            (merge goal { is-active: false })
        )
        (ok true)
    )
)

(define-public (update-charity-goal
        (goal-id uint)
        (title (string-ascii 100))
        (description (string-ascii 300))
    )
    (let (
            (goal (unwrap! (map-get? charity-goals { goal-id: goal-id })
                ERR_GOAL_NOT_FOUND
            ))
            (charity (unwrap! (map-get? charities { charity-id: (get charity-id goal) })
                ERR_CHARITY_NOT_FOUND
            ))
        )
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active goal) ERR_GOAL_NOT_FOUND)
        (asserts! (is-none (get achieved-block goal)) ERR_GOAL_ALREADY_ACHIEVED)
        (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
        (map-set charity-goals { goal-id: goal-id }
            (merge goal {
                title: title,
                description: description,
            })
        )
        (ok true)
    )
)

(define-read-only (get-charity (charity-id uint))
    (ok (map-get? charities { charity-id: charity-id }))
)

(define-read-only (get-charity-by-wallet (wallet principal))
    (match (map-get? charity-by-wallet { wallet: wallet })
        charity-data (get-charity (get charity-id charity-data))
        (ok none)
    )
)

(define-read-only (get-donation (donation-id uint))
    (ok (map-get? donations { donation-id: donation-id }))
)

(define-read-only (get-donor-stats (donor principal))
    (ok (map-get? donor-stats { donor: donor }))
)

(define-read-only (get-charity-balance (charity-id uint))
    (match (map-get? charities { charity-id: charity-id })
        charity (ok (- (get total-received charity) (get total-withdrawn charity)))
        ERR_CHARITY_NOT_FOUND
    )
)

(define-read-only (get-charity-withdrawal
        (charity-id uint)
        (withdrawal-id uint)
    )
    (ok (map-get? charity-withdrawals {
        charity-id: charity-id,
        withdrawal-id: withdrawal-id,
    }))
)

(define-read-only (get-charity-withdrawal-count (charity-id uint))
    (ok (default-to u0
        (get count (map-get? withdrawal-counters { charity-id: charity-id }))
    ))
)

(define-read-only (get-total-charities)
    (ok (var-get charity-counter))
)

(define-read-only (get-total-donations-amount)
    (ok (var-get total-donations))
)

(define-read-only (get-total-donations-count)
    (ok (var-get donation-counter))
)

(define-read-only (get-charity-stats (charity-id uint))
    (match (map-get? charities { charity-id: charity-id })
        charity (ok {
            charity: charity,
            available-balance: (- (get total-received charity) (get total-withdrawn charity)),
            withdrawal-count: (default-to u0
                (get count
                    (map-get? withdrawal-counters { charity-id: charity-id })
                )),
        })
        ERR_CHARITY_NOT_FOUND
    )
)

(define-read-only (is-charity-registered (wallet principal))
    (is-some (map-get? charity-by-wallet { wallet: wallet }))
)

(define-read-only (get-contract-stats)
    (ok {
        total-charities: (var-get charity-counter),
        total-donations-amount: (var-get total-donations),
        total-donations-count: (var-get donation-counter),
        contract-block: stacks-block-height,
    })
)

(define-read-only (verify-donation
        (donation-id uint)
        (expected-donor principal)
        (expected-amount uint)
    )
    (match (map-get? donations { donation-id: donation-id })
        donation (ok {
            is-valid: (and
                (is-eq (get donor donation) expected-donor)
                (is-eq (get amount donation) expected-amount)
            ),
            donation: (some donation),
        })
        (ok {
            is-valid: false,
            donation: none,
        })
    )
)

(define-read-only (get-donation-receipt (donation-id uint))
    (match (map-get? donations { donation-id: donation-id })
        donation (let ((charity (unwrap!
                (map-get? charities { charity-id: (get charity-id donation) })
                ERR_CHARITY_NOT_FOUND
            )))
            (ok {
                donation-id: donation-id,
                donor: (get donor donation),
                charity-name: (get name charity),
                amount: (get amount donation),
                block-height: (get block-height donation),
                message: (get message donation),
            })
        )
        ERR_CHARITY_NOT_FOUND
    )
)

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok true)
    )
)

(define-read-only (get-charity-efficiency (charity-id uint))
    (match (map-get? charities { charity-id: charity-id })
        charity (let (
                (total-received (get total-received charity))
                (total-withdrawn (get total-withdrawn charity))
            )
            (ok {
                charity-id: charity-id,
                total-received: total-received,
                total-withdrawn: total-withdrawn,
                efficiency-ratio: (if (> total-received u0)
                    (/ (* total-withdrawn u100) total-received)
                    u0
                ),
            })
        )
        ERR_CHARITY_NOT_FOUND
    )
)

(define-read-only (is-charity-active (charity-id uint))
    (match (map-get? charities { charity-id: charity-id })
        charity (ok (get is-active charity))
        ERR_CHARITY_NOT_FOUND
    )
)

(define-read-only (get-donation-summary (donor principal))
    (match (map-get? donor-stats { donor: donor })
        stats (ok {
            donor: donor,
            total-donated: (get total-donated stats),
            donation-count: (get donation-count stats),
            first-donation-block: (get first-donation-block stats),
            last-donation-block: (get last-donation-block stats),
            average-donation: (if (> (get donation-count stats) u0)
                (/ (get total-donated stats) (get donation-count stats))
                u0
            ),
        })
        (ok {
            donor: donor,
            total-donated: u0,
            donation-count: u0,
            first-donation-block: u0,
            last-donation-block: u0,
            average-donation: u0,
        })
    )
)

(define-read-only (check-charity-status (charity-id uint))
    (match (map-get? charities { charity-id: charity-id })
        charity (ok {
            exists: true,
            is-active: (get is-active charity),
            name: (get name charity),
            category: (get category charity),
            blocks-since-registration: (- stacks-block-height (get registration-block charity)),
        })
        (ok {
            exists: false,
            is-active: false,
            name: "",
            category: "",
            blocks-since-registration: u0,
        })
    )
)

(define-read-only (get-platform-metrics)
    (ok {
        total-charities: (var-get charity-counter),
        total-donations-amount: (var-get total-donations),
        total-donations-count: (var-get donation-counter),
        current-block: stacks-block-height,
        average-donation: (if (> (var-get donation-counter) u0)
            (/ (var-get total-donations) (var-get donation-counter))
            u0
        ),
    })
)

(define-read-only (calculate-donation-impact
        (amount uint)
        (charity-id uint)
    )
    (match (map-get? charities { charity-id: charity-id })
        charity (let (
                (current-total (get total-received charity))
                (new-total (+ current-total amount))
            )
            (ok {
                charity-id: charity-id,
                current-total: current-total,
                new-total: new-total,
                percentage-increase: (if (> current-total u0)
                    (/ (* amount u100) current-total)
                    u100
                ),
            })
        )
        ERR_CHARITY_NOT_FOUND
    )
)

(define-public (batch-verify-charities (charity-ids (list 10 uint)))
    (ok (map check-single-charity charity-ids))
)

(define-private (check-single-charity (charity-id uint))
    {
        charity-id: charity-id,
        exists: (is-some (map-get? charities { charity-id: charity-id })),
        is-active: (match (map-get? charities { charity-id: charity-id })
            charity (get is-active charity)
            false
        ),
    }
)

(define-read-only (get-charity-performance (charity-id uint))
    (match (map-get? charities { charity-id: charity-id })
        charity (let (
                (blocks-active (- stacks-block-height (get registration-block charity)))
                (total-received (get total-received charity))
                (donation-count (get donation-count charity))
            )
            (ok {
                charity-id: charity-id,
                blocks-active: blocks-active,
                total-received: total-received,
                donation-count: donation-count,
                donations-per-block: (if (> blocks-active u0)
                    (/ donation-count blocks-active)
                    u0
                ),
                average-donation: (if (> donation-count u0)
                    (/ total-received donation-count)
                    u0
                ),
            })
        )
        ERR_CHARITY_NOT_FOUND
    )
)

(define-read-only (validate-charity-wallet
        (charity-id uint)
        (expected-wallet principal)
    )
    (match (map-get? charities { charity-id: charity-id })
        charity (ok (is-eq (get wallet charity) expected-wallet))
        ERR_CHARITY_NOT_FOUND
    )
)

(define-public (transfer-charity-ownership
        (charity-id uint)
        (new-wallet principal)
    )
    (let ((charity (unwrap! (map-get? charities { charity-id: charity-id })
            ERR_CHARITY_NOT_FOUND
        )))
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (asserts! (not (is-eq tx-sender new-wallet)) ERR_INVALID_AMOUNT)
        (asserts! (is-none (map-get? charity-by-wallet { wallet: new-wallet }))
            ERR_CHARITY_ALREADY_EXISTS
        )

        (map-delete charity-by-wallet { wallet: tx-sender })
        (map-set charity-by-wallet { wallet: new-wallet } { charity-id: charity-id })
        (map-set charities { charity-id: charity-id }
            (merge charity { wallet: new-wallet })
        )
        (ok true)
    )
)

(define-read-only (estimate-gas-cost
        (operation (string-ascii 20))
        (amount uint)
    )
    (if (is-eq operation "donate")
        (ok (+ u1000 (/ amount u1000000)))
        (if (is-eq operation "register")
            (ok u2000)
            (if (is-eq operation "withdraw")
                (ok (+ u800 (/ amount u1000000)))
                (ok u500)
            )
        )
    )
)

(define-public (update-goal-progress
        (goal-id uint)
        (new-amount uint)
    )
    (let (
            (goal (unwrap! (map-get? charity-goals { goal-id: goal-id })
                ERR_GOAL_NOT_FOUND
            ))
            (charity (unwrap! (map-get? charities { charity-id: (get charity-id goal) })
                ERR_CHARITY_NOT_FOUND
            ))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get wallet charity)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active goal) ERR_GOAL_NOT_FOUND)
        (asserts! (> (get deadline-block goal) current-block) ERR_GOAL_EXPIRED)
        (map-set charity-goals { goal-id: goal-id }
            (merge goal {
                current-amount: new-amount,
                achieved-block: (if (>= new-amount (get target-amount goal))
                    (some current-block)
                    none
                ),
            })
        )
        (ok true)
    )
)

(define-read-only (get-charity-goal (goal-id uint))
    (ok (map-get? charity-goals { goal-id: goal-id }))
)

(define-read-only (get-charity-goals (charity-id uint))
    (let ((goal-count (default-to u0
            (get count (map-get? charity-goal-counts { charity-id: charity-id }))
        )))
        (ok {
            charity-id: charity-id,
            total-goals: goal-count,
        })
    )
)

(define-read-only (get-goal-progress (goal-id uint))
    (match (map-get? charity-goals { goal-id: goal-id })
        goal (let ((progress-percentage (if (> (get target-amount goal) u0)
                (/ (* (get current-amount goal) u100) (get target-amount goal))
                u0
            )))
            (ok {
                goal-id: goal-id,
                title: (get title goal),
                current-amount: (get current-amount goal),
                target-amount: (get target-amount goal),
                progress-percentage: progress-percentage,
                is-achieved: (is-some (get achieved-block goal)),
                is-active: (get is-active goal),
                deadline-block: (get deadline-block goal),
                blocks-remaining: (if (> (get deadline-block goal) stacks-block-height)
                    (- (get deadline-block goal) stacks-block-height)
                    u0
                ),
                is-expired: (<= (get deadline-block goal) stacks-block-height),
            })
        )
        ERR_GOAL_NOT_FOUND
    )
)

(define-read-only (get-charity-goal-by-index
        (charity-id uint)
        (goal-index uint)
    )
    (match (map-get? charity-goal-list {
        charity-id: charity-id,
        goal-index: goal-index,
    })
        goal-ref (ok (some (get goal-id goal-ref)))
        (ok none)
    )
)

(define-read-only (get-total-goals)
    (ok (var-get goal-counter))
)

(define-read-only (get-block-info)
    (ok {
        current-block: stacks-block-height,
        contract-deployment-block: u1,
    })
)
