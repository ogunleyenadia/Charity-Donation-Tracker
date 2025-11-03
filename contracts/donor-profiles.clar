(define-map profiles
  { who: principal }
  { name: (string-utf8 50), website: (string-utf8 100), message: (string-utf8 140), updated-at: uint }
)

(define-public (set-profile (name (string-utf8 50)) (website (string-utf8 100)) (message (string-utf8 140)))
  (begin
    (map-set profiles { who: tx-sender } { name: name, website: website, message: message, updated-at: block-height })
    (print { type: "profile-set", who: tx-sender, height: block-height })
    (ok true)
  )
)

(define-public (clear-profile)
  (begin
    (map-delete profiles { who: tx-sender })
    (print { type: "profile-cleared", who: tx-sender, height: block-height })
    (ok true)
  )
)

(define-read-only (get-profile (who principal))
  (map-get? profiles { who: who })
)

(define-read-only (has-profile (who principal))
  (is-some (map-get? profiles { who: who }))
)
