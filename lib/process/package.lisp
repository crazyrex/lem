(defpackage :lem-process
  (:use :cl :lem)
  (:export :run-process
           :delete-process
           :process-alive-p
           :make-process-stream
           :process-send-input)
  #+sbcl
  (:lock t))
