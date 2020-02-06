;;; composure-test.el --- Track how org-superstar primitives modify the buffer.  -*- lexical-binding: t; -*-

;;; Commentary:

;; This file purposefully breaks naming conventions to indicate that
;; it is *NOT* part of the main package.

;; WARNING: This testing package is *not* suitable for any purpose
;; other than testing org-superstar-mode.  ONLY use this code on a
;; clean Emacs install ("emacs -Q") and ONLY keep the Emacs session
;; running for as long as you need to.  DO NOT use an Emacs session
;; loading this file for everyday editing.

;; THIS FILE ADVISES EMACS INTERNALS FOR DEBUGGING PURPOSES ONLY.
;; USE AT YOUR OWN RISK.

;;; Code:

(require 'cl-macs)
(require 'subr-x)
(require 'linum)

(defvar-local org-superstar/listen nil
  "If t, activate the advice ‘org-superstar/comp-test’.
The idea is to only let ‘org-superstar/comp-test’ listen in on
‘compose-region’ when another function is advised to let-bind
this variable.  You can control which functions are currently
active listeners by calling ‘org-superstar/toggle-listener’.")


(defconst org-superstar/comp-listeners
  '(org-superstar--prettify-ibullets
    org-superstar--prettify-main-hbullet
    org-superstar--prettify-other-hbullet
    org-superstar--prettify-leading-hbullets)
  "List of functions ‘org-superstar/comp-test’ can be applied to.")

;;; Hooks

(add-hook 'org-mode-hook
          (lambda ()
            (linum-mode 1)
            (column-number-mode 1)))

;;; Advice definitions

(defun org-superstar/comp-test (start end &optional components mod-func)
  "Advise ‘compose-region’ to log modifications made to buffer.
START, END, COMPONENTS and MOD-FUNC correspond to the arguments
of ‘compose-region’."
  (when org-superstar/listen
    ;; I currently *do not* want to touch more than one character at a
    ;; time.  This test will only fail when I mess up regex grouping,
    ;; but it serves as a reminder that composing a region is not as
    ;; trivial as making the region bigger.
    (cl-assert (= 1 (- end start)))
    (let ((line (line-number-at-pos start))
          (col (save-excursion (goto-char start) (current-column)))
          (composed-string (buffer-substring-no-properties start end)))
    (cond
     ((stringp components)
      (message
       "line %s, column %s: composing ‘%s’ using string ‘%s’"
       line col composed-string
       components))
     ((characterp components)
      (message
       "line %s, column %s: composing ‘%s’ using character ‘%c’"
       line col composed-string
       components))
     (t
      (message
       "composing ‘%s’ using a sequence"
       (buffer-substring-no-properties start end)))))))

(defun org-superstar/wrap-prettify (face-function &rest args)
  "Wrap FACE-FUNCTION and call with ARGS.
Ensure the return value is a face or nil.  Also toggle
‘compose-region’ calls to log behavior."
  (let ((org-superstar/listen t)
         (returned-face nil))
    (prog1 (setq returned-face (apply face-function args))
      (cl-assert (or (facep returned-face)
                     (null returned-face)))
      (when (facep returned-face)
        (message "Applied face ‘%s’ to group (line %d)"
                 returned-face
                 (line-number-at-pos (match-beginning 0)))))))


;;; Helper functions
(defun org-superstar/read-listener ()
  "Return an argument list for ‘org-superstar/toggle-silence’."
  (let ((answer (completing-read
                 "Toggle silence for: "
                 org-superstar/comp-listeners nil t)))
    (unless (string-empty-p answer)
      (list (read answer)))))

;;; Adding and removing advice

(defun org-superstar/toggle-listener (&optional symbol)
  "Toggle listening to ‘compose-region’ for listener SYMBOL."
  (interactive (org-superstar/read-listener))
  (when symbol
    (let ((is-adviced
           (advice-member-p #'org-superstar/wrap-prettify symbol)))
      (cond (is-adviced
             (message "‘%s’ listening: OFF" symbol)
             (advice-remove symbol #'org-superstar/wrap-prettify))
            (t
             (message "‘%s’ listening: ON" symbol)
             (advice-add symbol
                         :around #'org-superstar/wrap-prettify))))))

;; listen in on compose-region
(advice-add 'compose-region :before #'org-superstar/comp-test)

;; advise prettifyers

(dolist (symbol org-superstar/comp-listeners)
  (org-superstar/toggle-listener symbol))
