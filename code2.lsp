(defun reduce (f a i) 
    (if (eq a nil)
        i
        (reduce f (rest a) (f i (first a)))
    )
)
(defun sum (a b) (+ a b))
(reduce sum (quote (1 2 3 4)) 0)