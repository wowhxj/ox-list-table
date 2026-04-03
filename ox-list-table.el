;;; ox-list-table.el --- Convert org-mode list-table to HTML table -*- lexical-binding: t; -*-

;; Author: Randolph <xiaojianghuang@gmail.com>
;; URL: https://github.com/wowhxj/ox-list-table
;; Version: 0.2.0
;; Keywords: outlines, hypermedia
;; Package-Requires: ((emacs "27.1") (org "9.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Convert org-mode list-table (a plain-list with `:list-table t' in
;; `#+ATTR_ODT') into proper HTML <table> elements during export.
;;
;; Cell content is exported through org's own export engine, so all
;; org markup (bold, italic, links, tables, images, etc.) is supported.
;;
;; Usage:
;;   (require 'ox-list-table)
;;   (org-list-table-enable)

;;; Code:

(require 'org)
(require 'ox-html)
(require 'cl-lib)

(defgroup org-list-table nil
  "Options for org-list-table export."
  :group 'org-export)

(defcustom org-list-table-html-table-class "dark-table"
  "CSS class applied to converted list-table <table> elements."
  :type 'string
  :group 'org-list-table)

(defun org-list-table--attr-list-table-p (line)
  "Non-nil if LINE is an ATTR_ODT keyword with :list-table t."
  (and (string-match-p "^#[+][ \t]*ATTR_ODT:" line)
       (string-match-p ":list-table[ \t]+t" line)))

(defun org-list-table--separator-line-p (line)
  "Non-nil if LINE is a row separator (dash followed by more dashes)."
  (string-match-p "^-[ \t]+-+" line))

(defun org-list-table--top-item-p (line)
  "Non-nil if LINE starts a zero-indent top-level list item (- or *)."
  (string-match-p "^[-*]\\([ \t]\\|$\\)" line))

(defun org-list-table--indent-of (line)
  "Return the leading whitespace string of LINE."
  (let ((end (string-match "[^ \t]" line)))
    (if end (substring line 0 end) "")))

(defun org-list-table--parse-cell-text (line)
  "Extract cell text from a sub-item LINE, stripping the bullet."
  (when (string-match "^[ \t]*-[ \t]+\\(.*\\)$" line)
    (match-string 1 line)))

(defun org-list-table--strip-common-indent (text)
  "Strip the common leading whitespace from all non-empty lines in TEXT."
  (let* ((lines (split-string text "\n"))
         (non-empty (cl-remove-if
                     (lambda (l) (string-match-p "^[ \t]*$" l))
                     lines))
         (min-indent (if non-empty
                         (apply #'min
                                (mapcar (lambda (l)
                                          (if (string-match "^\\([ \t]*\\)" l)
                                              (length (match-string 1 l))
                                            0))
                                        non-empty))
                       0)))
    (mapconcat (lambda (l)
                 (if (>= (length l) min-indent)
                     (substring l min-indent)
                   l))
               lines "\n")))

(defun org-list-table--export-org-to-html (org-src)
  "Export ORG-SRC string to HTML body using org's export engine.
Returns trimmed HTML string, or empty string for nil/blank input."
  (if (or (null org-src) (string= (string-trim org-src) ""))
      ""
    (let ((html (org-export-string-as
                 org-src 'html t
                 '(:with-toc nil :section-numbers nil))))
      (string-trim html))))

(defun org-list-table--scan-region (beg end)
  "Scan list-table region BEG..END in current buffer.
Returns (CAPTION . ROWS).  Each ROW is a list of cell-plists
with :org-src and :in-header."
  (let ((region-text (buffer-substring-no-properties beg end)))
    (with-temp-buffer
      (insert region-text)
      (goto-char (point-min))
      (let (caption rows current-row in-header)
        (setq in-header t)
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (cond
             ((string-match "^#[+][ \t]*CAPTION:[ \t]*\\(.*\\)$" line)
              (setq caption (match-string 1 line))
              (forward-line 1))
             ((string-match "^#[+][ \t]*NAME:[ \t]*" line)
              (forward-line 1))
             ((org-list-table--attr-list-table-p line)
              (forward-line 1))
             ((org-list-table--top-item-p line)
              (when current-row
                (push (nreverse current-row) rows)
                (setq current-row nil))
              (when (org-list-table--separator-line-p line)
                (setq in-header nil))
              (forward-line 1)
              (let* ((top-indent (org-list-table--indent-of line))
                     (sub-indent (concat top-indent "  "))
                     (keep-going t))
                (while (and keep-going (not (eobp)))
                  (let ((nl (buffer-substring-no-properties
                             (line-beginning-position) (line-end-position))))
                    (cond
                     ((string= nl "")
                      (forward-line 1))
                     ((string-match-p
                       (concat "^" (regexp-quote sub-indent) "[ \t]*-") nl)
                      (let ((cell-text (org-list-table--parse-cell-text nl)))
                        (forward-line 1)
                        ;; Collect deeper-parts (lines indented beyond sub-indent)
                        (let (deeper-parts)
                          (while
                              (and (not (eobp))
                                   (let ((dl (buffer-substring-no-properties
                                              (line-beginning-position)
                                              (line-end-position))))
                                     (and (> (length dl) (+ (length sub-indent) 1))
                                          (not (string-match-p
                                                (concat "^" (regexp-quote sub-indent) "-")
                                                dl))
                                          (not (org-list-table--separator-line-p dl))
                                          (not (org-list-table--top-item-p dl)))))
                            (push (buffer-substring-no-properties
                                   (line-beginning-position) (line-end-position))
                                  deeper-parts)
                            (forward-line 1))
                          ;; Build org-src: cell-text + deeper content
                          (let* ((deeper-str
                                  (when deeper-parts
                                    (org-list-table--strip-common-indent
                                     (mapconcat #'identity
                                                (nreverse deeper-parts) "\n"))))
                                 (org-src
                                  (cond
                                   ((and cell-text deeper-str)
                                    (concat cell-text "\n" deeper-str))
                                   (cell-text cell-text)
                                   (deeper-str deeper-str)
                                   (t ""))))
                            (push (list :org-src org-src :in-header in-header)
                                  current-row)))))
                     (t (setq keep-going nil))))))
                (push (nreverse current-row) rows)
                (setq current-row nil))
             (t (forward-line 1)))))
        (when current-row
          (push (nreverse current-row) rows))
        (cons caption (nreverse rows))))))

(defun org-list-table--rows-to-html (caption all-rows)
  "Convert CAPTION and ALL-ROWS to HTML export block string."
  (let* ((header-rows
          (cl-remove-if-not
           (lambda (r) (cl-some (lambda (c) (plist-get c :in-header)) r))
           all-rows))
         (body-rows
          (cl-remove-if
           (lambda (r) (cl-some (lambda (c) (plist-get c :in-header)) r))
           all-rows))
         (tbl-class org-list-table-html-table-class))
    (cl-labels
        ((cell-html (cell)
                    (let ((tag (if (plist-get cell :in-header) "th" "td"))
                          (html (org-list-table--export-org-to-html
                                 (plist-get cell :org-src))))
                      (concat "<" tag ">" html "</" tag ">")))
         (row-html (row)
                   (concat "<tr>" (mapconcat #'cell-html row "") "</tr>\n")))
      (concat "#+BEGIN_EXPORT html\n"
              (format "<table class=\"%s\">" tbl-class)
              (when caption
                (format "<caption>%s</caption>"
                        (org-html-encode-plain-text caption)))
              "\n"
              (when header-rows
                (concat "<thead>\n"
                        (mapconcat #'row-html header-rows "")
                        "</thead>\n"))
              (when body-rows
                (concat "<tbody>\n"
                        (mapconcat #'row-html body-rows "")
                        "</tbody>\n"))
              "</table>\n"
               "#+END_EXPORT\n"))))

(defun org-list-table--supported-backend-p (backend)
  "Non-nil if BACKEND is html, md, reveal, or any html-derived backend."
  (org-export-derived-backend-p backend 'html))

(defun org-list-table-convert-buffer (backend)
  "Convert all list-tables in current buffer to export blocks.
Intended for `org-export-before-parsing-functions'."
  (when (org-list-table--supported-backend-p backend)
    (goto-char (point-min))
      (let (regions)
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (if (org-list-table--attr-list-table-p line)
                (let ((region-start (line-beginning-position)))
                  (save-excursion
                    (catch 'scan-done
                      (while (not (bobp))
                        (forward-line -1)
                        (let ((prev (buffer-substring-no-properties
                                     (line-beginning-position) (line-end-position))))
                          (if (or (string-match "^#[+][ \t]*CAPTION:" prev)
                                  (string-match "^#[+][ \t]*NAME:" prev))
                              (setq region-start (line-beginning-position))
                            (throw 'scan-done nil))))))
                  (goto-char region-start)
                  (while (and (not (eobp))
                              (let ((l (buffer-substring-no-properties
                                       (line-beginning-position) (line-end-position))))
                                (or (string-match "^#[+]" l)
                                    (string= l ""))))
                    (forward-line 1))
                  (let ((keep-going t))
                    (while (and keep-going (not (eobp)))
                      (let ((nl (buffer-substring-no-properties
                                 (line-beginning-position) (line-end-position))))
                        (cond
                         ((string= nl "")
                          (forward-line 1))
                         ((string-match-p "^[ \t]*-" nl)
                          (forward-line 1))
                         ((string-match-p "^[ \t]" nl)
                          (forward-line 1))
                         (t (setq keep-going nil))))))
                  (push (cons region-start (point)) regions))
              (forward-line 1))))
        (dolist (region (nreverse regions))
          (let* ((beg (car region))
                 (end (cdr region))
                 (parsed (org-list-table--scan-region beg end))
                 (caption (car parsed))
                 (rows (cdr parsed))
                 (fmt (org-list-table--rows-to-html caption rows)))
            (delete-region beg end)
            (goto-char beg)
            (insert fmt))))))

;;;###autoload
(defun org-list-table-enable ()
  "Enable list-table conversion for HTML and derived backends (e.g. reveal)."
  (add-hook 'org-export-before-parsing-functions
            #'org-list-table-convert-buffer))

;;;###autoload
(defun org-list-table-disable ()
  "Disable list-table conversion."
  (remove-hook 'org-export-before-parsing-functions
               #'org-list-table-convert-buffer))

(provide 'ox-list-table)
;;; ox-list-table.el ends here
