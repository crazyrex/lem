(defpackage :lem-rust-mode
  (:use :cl :lem :lem.language-mode)
  (:export :rust-mode
           :*rust-mode-hook*))
(in-package :lem-rust-mode)

(defvar *rust-mode-hook* '())

(defun tokens (boundary strings)
  (let ((alternation
          `(:alternation ,@(sort (copy-list strings) #'> :key #'length))))
    (if boundary
        `(:sequence ,boundary ,alternation ,boundary)
        alternation)))

(defun make-tmlanguage-rust ()
  (let* ((patterns (make-tm-patterns
                    (make-tm-region "//" "$" :name 'syntax-comment-attribute)
                    (make-tm-region '(:sequence "/*")
                                    '(:sequence "*/")
                                    :name 'syntax-comment-attribute)
                    (make-tm-region '(:sequence "#[")
                                    '(:sequence "]")
                                    :name 'syntax-builtin-attribute)
                    (make-tm-region '(:sequence "\"")
                                    '(:sequence "\"")
                                    :name 'syntax-string-attribute
                                    :patterns (make-tm-patterns
                                               (make-tm-match "\\\\.")))
                    (make-tm-match "'\\\\?.'"
                                   :name 'syntax-string-attribute)
                    (make-tm-match (tokens :word-boundary
                                           '("as"
                                             "box" "break"
                                             "const" "continue" "crate"
                                             "do" "dyn"
                                             "else" "enum" "extern"
                                             "false" "fn" "for"
                                             "if" "impl" "in"
                                             "let" "loop"
                                             "match" "mod" "move" "mut"
                                             "priv" "pub"
                                             "ref" "return"
                                             "self" "static" "struct" "super"
                                             "true" "trait" "type"
                                             "use"
                                             "virtual"
                                             "where" "while"
                                             "yield"))
                                   :name 'syntax-keyword-attribute)
                    (make-tm-match
                     (tokens :word-boundary
                             '("u8" "i8"
                               "u16" "i16"
                               "u32" "i32"
                               "u64" "i64"
                               "u128" "i128"

                               "f32" "f64"
                               "isize" "usize"
                               "bool"
                               "str" "char"))
                     :name 'syntax-type-attribute)
                    (make-tm-match "\\b[A-Z][a-zA-Z_0-9]*\\b"
                                   :name 'syntax-type-attribute)
                    (make-tm-match (tokens :word-boundary
                                           '("const" "extern" "register" "restrict"
                                             "static" "volatile" "inline"))
                                   :name 'syntax-builtin-attribute)
                    (make-tm-match (tokens :word-boundary
                                           '("NULL" "true" "false" "TRUE" "FALSE"))
                                   :name 'syntax-constant-attribute)
                    (make-tm-match (tokens nil '("+" "++" "+=" "-" "--" "-=" "*" "*=" "/" "/=" "%" "%=" 
                                                 "<" "<=" ">" ">=" "!=" "==" 
                                                 "!" "&&" "||"
                                                 "<<" "<<=" ">>" ">>=" "~" "&" "&=" "|" "|=" "^" "^=" 
                                                 "=" "->" "." "," "?" ":" "sizeof"))
                                   :name 'syntax-keyword-attribute)
                    (make-tm-match "\\b((0(x|X)[0-9a-fA-F_]*?)|(0(b|B)[01]([01_]*)?)|(([0-9]([0-9_]*)?\\.?[0-9_]*)|(\\.[0-9]([0-9_]*)?))((e|E)(\\+|-)?[0-9]([0-9']*[0-9])?)?)(u8|i8|u16|i16|u32|i32|u64|i64|u128|f32|f64)?\\b"
                                   :name 'syntax-constant-attribute)
                    
                    #+nil(make-tm-match `(:sequence
                                     :start-anchor
                                     (:greedy-repetition 0 nil :whitespace-char-class)
                                     "#"
                                     ,(tokens nil '("defined" "define" "undef" "include"
                                                    "ifdef" "ifndef" "if" "elif" "else" "endif"
                                                    "line" "error" "pragma"))
                                     :word-boundary)
                                   :name 'syntax-builtin-attribute))))
    (make-tmlanguage :patterns patterns)))

(defvar *rust-syntax-table*
  (let ((table (make-syntax-table
                :space-chars '(#\space #\tab #\newline #\: #\, #\;)
                :symbol-chars '(#\_)
                :paren-pairs '((#\( . #\))
                               (#\{ . #\})
                               (#\[ . #\]))
                :string-quote-chars '(#\")
                :expr-prefix-chars '(#\- #\+ #\*)
                :block-string-pairs '(("`" . "`"))
                :line-comment-string "//"
                :block-comment-pairs '(("/*" . "*/"))))
        (tmlanguage (make-tmlanguage-rust)))
    (set-syntax-parser table tmlanguage)
    table))

(define-major-mode rust-mode language-mode
    (:name "rust"
     :keymap *rust-mode-keymap*
     :syntax-table *rust-syntax-table*)
  (setf (variable-value 'enable-syntax-highlight) t
        (variable-value 'calc-indent-function) 'calc-indent
        (variable-value 'indent-tabs-mode) nil
        (variable-value 'beginning-of-defun-function) 'beginning-of-defun
        (variable-value 'end-of-defun-function) 'end-of-defun
        (variable-value 'line-comment) "//"
        (variable-value 'insertion-line-comment) "// "
        (variable-value 'tab-width :buffer) 4
        ;;(variable-value 'find-definitions-function) 'lem.gtags:find-definitions
        ;;(variable-value 'find-references-function) 'lem.gtags:find-references
        )
  (run-hooks *rust-mode-hook*))

(define-key *rust-mode-keymap* "C-c C-f" 'rust-format-buffer)
(define-key *rust-mode-keymap* "M-C-q" 'indent-exp)

(define-command indent-exp () ()
  (lem-lisp-mode:lisp-indent-sexp))

(defun beginning-of-defun (point n)
  (loop :repeat n :do (search-backward-regexp point "^\\w[^=(]*")))

(defun end-of-defun (point n)
  (if (minusp n)
      (beginning-of-defun point (- n))
      (search-forward-regexp point "^\\};*")))

(defvar *indent-line-function* nil)

(defun %indent (p indent)
  (when *indent-line-function*
    (funcall *indent-line-function* p indent)))

(defun delimiter-line-p (p)
  (multiple-value-bind (start)
      (ppcre:scan "[^\\\\]?;\\s*(?:/\\*.*?\\*/|//.*?)?\\s*$" (line-string p))
    (when start
      (with-point ((p p))
        (line-offset p 0 (1+ start))
        (not (in-string-or-comment-p p))))))

(defun end-block-line-p (p)
  (with-point ((p p))
    (loop :for start := 0 :then (1+ i)
          :for i := (let ((a (position #\} (line-string p) :start start))
                          (b (position #\] (line-string p) :start start)))
                      (cond ((and a b) (min a b))
                            (t (or a b))))
          :while i
          :do (unless (let ((p (character-offset (line-start p) i)))
                        (check-type p point)
                        (in-string-or-comment-p p))
                (return i)))))

(defun dangling-start-p (p)
  (let ((str (looking-at p "(?:do|else\\s+if|else|for|if|switch|while)\\s*")))
    (character-offset p (length str))
    (or (not (eql #\( (character-at p)))
        (scan-lists p 1 0 t))
    (let ((old-linenumber (line-number-at-point p)))
      (skip-space-and-comment-forward p)
      (/= old-linenumber (line-number-at-point p)))))

(defun unbalanced-p (state)
  (if (member #\( (pps-state-paren-stack state)) t nil))

(defun unbalanced-indent (p indent start)
  (flet ((jmp-start-paren (p)
           (loop
             (scan-lists p -1 1)
             (when (eql #\( (character-at p))
               (return)))))
    (let ((state))
      (%indent p indent)
      (jmp-start-paren p)
      (let ((indent1 (1+ (point-column p))))
        (loop
          (unless (line-offset p 1) (return-from unbalanced-indent nil))
          (%indent p indent1)
          (unless (unbalanced-p (setf state
                                      (parse-partial-sexp (copy-point start :temporary)
                                                          (line-end p))))
            (return))
          (with-point ((p p))
            (jmp-start-paren p)
            (setf indent1 (1+ (point-column p)))))
        state))))

(defun cond-op-line-p (p limit)
  (and (not (delimiter-line-p p))
       (search-forward (line-start p) "?" limit)
       (not (in-string-or-comment-p p))
       (not (syntax-escape-char-p (character-at p -2)))))

(defun indent-cond-op (p indent)
  (with-point ((tmp (line-end p)))
    (when (cond-op-line-p p tmp)
      (line-start tmp)
      (when (and (not (unbalanced-p (parse-partial-sexp tmp p)))
                 (not (delimiter-line-p p)))
        (loop
          (unless (line-offset p 1) (return-from indent-cond-op nil))
          (%indent-line p (+ indent tab-width))
          (when (delimiter-line-p p)
            (return))))))
  t)

(defun %indent-line (p indent)
  (let ((tab-width (variable-value 'tab-width :default p)))
    (back-to-indentation p)
    (loop :while (end-line-p p)
          :do (%indent p indent)
          :do (if (line-offset p 1)
                  (back-to-indentation p)
                  (return-from %indent-line nil)))
    (when (eql #\# (character-at p))
      (%indent p 0))
    (when (and (eql #\. (character-at p))
               (not (eql #\. (character-at p 1))))
      (%indent p (+ indent tab-width)))
    (when (eql #\} (character-at p))
      (character-offset p 1)
      (skip-whitespace-forward p t))
    (alexandria:when-let ((i (end-block-line-p p)))
      (with-point ((p p)
                   (start p))
        (line-start start)
        (character-offset (line-start p) (1+ i))
        (when (> 0 (pps-state-paren-depth (parse-partial-sexp start p)))
          (decf indent tab-width))))
    (let ((word (looking-at p "\\w+"))
          (word-point)
          (state)
          (unbalanced-flag nil))
      (when word
        (setf word-point (copy-point p :temporary))
        (character-offset p (length word))
        (skip-whitespace-forward p t))
      (with-point ((start p))
        (line-start start)
        (setf state (parse-partial-sexp (copy-point start :temporary)
                                        (line-end p)))
        (cond
          ((unbalanced-p state)
           (setf unbalanced-flag t)
           (unless (setf state (unbalanced-indent p indent start))
             (return-from %indent-line nil)))
          ((and word (ppcre:scan "^(?:case|default)$" word))
           (%indent p (- indent tab-width)))
          (t
           (%indent p indent)
           (unless (indent-cond-op p indent)
             (return-from %indent-line nil)))))
      (when (or (eql #\{ (car (pps-state-paren-stack state)))
                (eql #\[ (car (pps-state-paren-stack state))))
        (let ((indent (+ indent tab-width))
              (status))
          (loop
            (unless (line-offset p 1) (return-from %indent-line nil))
            (setf (values indent status) (%indent-line p indent))
            (when (and (not (eq status :block-end))
                       (end-block-line-p p))
              (return-from %indent-line (values indent :block-end))))))
      (when (and word-point (dangling-start-p word-point))
        (unless (line-offset p 1) (return-from %indent-line nil))
        (%indent-line p (+ indent tab-width))
        (return-from %indent-line indent))
      (return-from %indent-line indent))))

(defun calc-indent-region (start end)
  (with-point ((p start))
    (let ((indent (point-column (back-to-indentation p))))
      (loop
        (let ((next-indent (%indent-line p indent)))
          (unless next-indent (return))
          (unless (line-offset p 1) (return))
          (unless (point< start end) (return))
          (setf indent next-indent))))))

(defun calc-indent (point)
  (cond
    ((in-string-or-comment-p point)
     (with-point ((p point))
       (back-to-indentation p)
       (if (in-string-or-comment-p p)
           (point-column p)
           (calc-indent p))))
    ((with-point ((p point))
       (when (maybe-beginning-of-comment p)
         (if (eql #\* (character-at (back-to-indentation point)))
             (+ 1 (point-column p))
             (+ 2 (point-column p))))))
    (t
     (with-point ((start point))
       (line-offset start -1)
       (beginning-of-defun start 1)
       (let ((*indent-line-function*
               (lambda (p indent)
                 (when (same-line-p point p)
                   (return-from calc-indent indent)))))
         (calc-indent-region start point))))))

(pushnew (cons "\\.rs$" 'rust-mode) *auto-mode-alist* :test #'equal)