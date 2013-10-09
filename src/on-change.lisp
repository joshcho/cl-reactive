;;;; on-change.lisp

(in-package #:cl-reactive)

(defun signal-on-change (sig &key
                               (test #'equal)
                               documentation)
  "Create a signal function that returns the value of SIG but that only triggers dependents to update when its value has actually changed.  The given TEST function is used to tell if two values are equal.  The default TEST is #'EQUAL."
  (let* ((documentation (or documentation
                            (format nil "~A" `(ON-CHANGE ,sig))))
         (int-doc (concatenate 'string "Internal: " documentation))
         (value (signal-value sig))
         (sig-internal (signal-variable value
                                         :type (signal-type sig)
                                         :documentation int-doc)))
    (signal-flet ((sig-update ((v sig))
                              (unless (funcall test value v)
                                (with-signal-values ((int sig-internal))
                                  (setf value v
                                        int v)))
                              v))
      ;; Here, it would be nice to just return sig-internal and
      ;; be done with it.  But, if we did that, then no one would
      ;; be referencing sig-update and the garbage collector will
      ;; reap it.  So, we artificially reference it here as a second
      ;; value for the signal-function which will never be looked at.
      (signal-function (lambda ()
                         (with-signal-values ((int sig-internal)
                                              (upd sig-update))
                           (values int upd)))
                       (list sig-internal)
                       :type (signal-type sig)
                       :documentation documentation))))
