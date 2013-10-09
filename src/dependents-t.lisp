;;;; dependents-t.lisp

(in-package #:cl-reactive-tests)

(nst:def-test-group dependents-tests ()
  (nst:def-test signal-function-evaluates-immediately (:equal 2)
    (let ((calls 0))
      (with-signal-values ((x *sig-x-int*))
        (setf x 0)
        (signal-flet ((sig-y ((x *sig-x-int*)) (incf calls) x))
          (declare (ignore sig-y))
          (setf x 1)
          (setf x 0)))
      calls))

  (nst:def-test defer-updates-does-defer (:equal 1)
    (let ((calls 0))
      (with-signal-values ((x *sig-x-int*))
        (setf x 0)
        (signal-flet ((sig-y ((x *sig-x-int*)) (incf calls) x))
          (declare (ignore sig-y))
          (with-signal-updates-deferred ()
            (setf x 1)
            (setf x 0))))
      calls))

  (nst:def-test defer-updates-does-not-defer-at-end (:equal 1)
    (let ((calls 0))
      (signal-let ((sig-x 0)
                   (sig-y 0))
        (signal-flet ((sig-a ((x sig-x))
                        (with-signal-values ((y sig-y))
                          (setf y x)))
                      (sig-b ((y sig-y))
                          (declare (ignore y))
                          (incf calls)))
          (declare (ignore sig-a sig-b))
          (with-signal-updates-deferred ()
            (with-signal-values ((x sig-x))
              (setf x 1)))))
      calls)))
