;;; ghelp-helpful.el --- Ghelp+Helpful      -*- lexical-binding: t; -*-

;;; This file is NOT part of GNU Emacs

;;; Commentary:
;;

;;; Code:
;;

(require 'helpful)
(require 'ghelp-builtin)

(defun ghelp-helpful-backend (&optional no-prompt refresh)
  (let* ((mode (ghelp-get-mode))
         (default-symbol (symbol-at-point))
         (symbol (intern-soft
                  (if refresh
                      (ghelp-page-store-get 'refresh-symbol)
                    (if no-prompt
                        default-symbol
                      (ghelp-completing-read ; I can also use ‘completing-read’
                       default-symbol
                       obarray
                       (lambda (s) (let ((s (intern-soft s)))
                                     (or (fboundp s)
                                         (boundp s)
                                         (facep s)
                                         (cl--class-p s)))))))))
         (callable-doc (ghelp-helpful-callable symbol))
         (variable-doc (ghelp-helpful-variable symbol))
         (entry-list (remove
                      nil
                      (list
                       (when callable-doc
                         (list (format "%s (callable)" symbol) callable-doc))
                       (when variable-doc
                         (list (format "%s (variable)" symbol) variable-doc))
                       (ghelp-face-describe-symbol symbol)
                       (ghelp-cl-type-describe-symbol symbol)))))
    (list symbol
          entry-list
          `((refresh-symbol ,symbol)))))

(defun ghelp-helpful-callable (symbol)
  (when (fboundp symbol)
    (let ((buf (helpful--buffer symbol t)))
      (with-current-buffer buf
        ;; use our hacked ‘helpful--button’ to insert
        ;; hacked describe buttons
        (cl-letf (((symbol-function 'helpful--button)
                   #'ghelp-helpful--button))
          (helpful-update))
        ;; insert an ending newline
        (let ((inhibit-read-only t))
          (goto-char (point-max))
          (insert "\n"))
        (prog1 (buffer-string)
          (kill-buffer buf))))))

(defun ghelp-helpful-variable (symbol)
  (when (helpful--variable-p symbol)
    (let ((buf (helpful--buffer symbol nil)))
      (with-current-buffer buf
        ;; use our hacked ‘helpful--button’ to insert
        ;; hacked describe buttons
        (cl-letf (((symbol-function 'helpful--button)
                   #'ghelp-helpful--button))
          (helpful-update))
        ;; insert an ending newline
        (let ((inhibit-read-only t))
          (goto-char (point-max))
          (insert "\n"))
        (prog1 (let ((yank-excluded-properties nil))
                 (buffer-string))
          (kill-buffer buf))))))

;;; Modified helpful.el code

;; hack this function to insert our hacked buttons
(defun ghelp-helpful--button (text type &rest properties)
  ;; `make-text-button' mutates our string to add properties. Copy
  ;; TEXT to prevent mutating our arguments, and to support 'pure'
  ;; strings, which are read-only.
  (setq text (substring-no-properties text))
  (apply #'make-text-button
         text nil
         :type (cond ((eq type 'helpful-describe-button)
                      'ghelp-helpful-describe-button)
                     ((eq type 'helpful-describe-exactly-button)
                      'ghelp-helpful-describe-exactly-button)
                     (t type))
         properties))

;; hacked buttons invoke ghelp functions instead of helpful ones

(define-button-type 'ghelp-helpful-describe-button
  'action #'ghelp-helpful--describe
  'symbol nil
  'follow-link t
  'help-echo "Describe this symbol")

(defun ghelp-helpful--describe (button)
  "Describe the symbol that this BUTTON represents."
  (let* ((sym (button-get button 'symbol))
         (doc-v (ghelp-helpful-variable sym nil))
         (doc-f (ghelp-helpful-callable sym nil))
         (ev (when doc-v (list
                          (format "%s (variable)" sym)
                          doc-v)))
         (ef (when doc-f (list
                          (format "%s (callable)" sym)
                          doc-f)))
         (entry-list (remove nil (list ev ef))))
    (ghelp--show-page sym entry-list nil ghelp-page--mode
                      (selected-window))))

(define-button-type 'ghelp-helpful-describe-exactly-button
  'action #'ghelp-helpful--describe-exactly
  'symbol nil
  'callable-p nil
  'follow-link t
  'help-echo "Describe this symbol")

(defun helpful--describe-exactly (button)
  "Describe the symbol that this BUTTON represents.
This differs from `helpful--describe' because here we know
whether the symbol represents a variable or a callable."
  (let ((sym (button-get button 'symbol))
        (callable-p (button-get button 'callable-p))
        (doc-v (ghelp-helpful-variable sym nil))
        (doc-f (ghelp-helpful-callable sym nil))
        (ev (when doc-v (make-ghelp-entry
                         :name (format "%s (variable)" sym)
                         :text doc-v)))
        (ef (when doc-f (make-ghelp-entry
                         :name (format "%s (callable)" sym)
                         :text doc-f)))
        (entry-list (list (if callable-p ef ev))))
    (ghelp--show-page sym ghelp-page--mode nil nil
                      entry-list (selected-window))))

(provide 'ghelp-helpful)

;;; ghelp-helpful.el ends here
