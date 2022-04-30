(defun reduce (f a i) 
    (if (eq a nil)
        i
        (reduce f (rest a) (f i (first a)))
    )
)
(defun sum (a b) (+ a b))
(defun test (f a b) (f a b))
(test + (test + 10 10) 10)