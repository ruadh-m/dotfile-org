#!/usr/bin/env chibi-scheme
;;; dotfiles.scm -- Idempotent dotfile symlink manager
;;;
;;; Usage: chibi-scheme dotfiles.scm [DOTDIR]
;;;
;;; DOTDIR defaults to the current working directory. It must contain a
;;; plain-text file named "manifest".  Each non-empty, non-comment line
;;; contains two whitespace-separated fields:
;;;
;;;   # this is a comment
;;;   bash/bashrc               /home/alice/.bashrc
;;;   emacs/config.org          /home/alice/.emacs.d/config.org
;;;
;;; The first field is the source path relative to DOTDIR.
;;; The second field is the absolute destination path.
;;; Neither field may contain embedded whitespace.

(import (scheme base)
	(scheme char)
        (scheme file)
        (scheme write)
        (scheme process-context)
        (prefix (chibi filesystem) fs:))

;; String utilities

(define (string-null? s)
  (string=? s ""))

(define (string-trim-left s)
  (let ((len (string-length s)))
    (let loop ((i 0))
      (cond ((>= i len) "")
            ((char-whitespace? (string-ref s i)) (loop (+ i 1)))
            (else (substring s i len))))))

(define (string-trim-right s)
  (let ((len (string-length s)))
    (let loop ((i (- len 1)))
      (cond ((< i 0) "")
            ((char-whitespace? (string-ref s i)) (loop (- i 1)))
            (else (substring s 0 (+ i 1)))))))

(define (string-trim s)
  (string-trim-left (string-trim-right s)))

;; Path utilities

(define (path-join a b)
  (cond
    ((and (string-null? a) (string-null? b)) "/")
    ((string-null? a)
     (if (char=? (string-ref b 0) #\/)
         b
         (string-append "/" b)))
    ((string-null? b) a)
    (else
     (let ((a-len (string-length a))
           (b-len (string-length b)))
       (let ((a-slash? (char=? (string-ref a (- a-len 1)) #\/))
             (b-slash? (char=? (string-ref b 0) #\/)))
         (cond
           ((and a-slash? b-slash?)
            (string-append a (substring b 1 b-len)))
           ((or a-slash? b-slash?)
            (string-append a b))
           (else
            (string-append a "/" b))))))))

(define (path-split path)
  (if (string=? path "/")
      '("")
      (let ((len (string-length path)))
        (let loop ((i 0) (start 0) (parts '()))
          (cond
            ((>= i len)
             (reverse (if (= start i)
                          parts
                          (cons (substring path start i) parts))))
            ((char=? (string-ref path i) #\/)
             (loop (+ i 1)
                   (+ i 1)
                   (cons (substring path start i) parts)))
            (else
             (loop (+ i 1) start parts)))))))

(define (dirname path)
  (let ((len (string-length path)))
    (let loop ((i (- len 1)))
      (cond ((< i 0) ".")
            ((char=? (string-ref path i) #\/)
             (if (= i 0) "/" (substring path 0 i)))
            (else (loop (- i 1)))))))

(define (absolute-path path)
  (if (and (> (string-length path) 0)
           (char=? (string-ref path 0) #\/))
      path
      (path-join (fs:current-directory) path)))

;; Filesystem operations

(define (mkdir-p path)
  (let ((parts (path-split path)))
    (let loop ((current (car parts)) (rest (cdr parts)))
      (if (null? rest)
          #t
          (let ((next (path-join current (car rest))))
            (cond
              ((not (file-exists? next))
               (fs:create-directory next))
              ((fs:file-directory? next)
               #t)
              (else
               (error "mkdir-p: path component is not a directory" next)))
            (loop next (cdr rest)))))))

(define (symbolic-link-target path)
  (guard (ex (else #f))
    (fs:read-link path)))

(define (ensure-symlink source dest)
  (let ((current-target (symbolic-link-target dest)))
    (cond
      ;; Destination is already a symlink (valid or broken)
      (current-target
       (if (string=? current-target source)
           (begin
             (display "  OK    ")
             (display dest)
             (newline))
           (begin
             (delete-file dest)
             (fs:symbolic-link-file source dest)
             (display "  UPD   ")
             (display dest)
             (newline))))

      ;; Destination does not exist at all
      ((not (file-exists? dest))
       (mkdir-p (dirname dest))
       (fs:symbolic-link-file source dest)
       (display "  NEW   ")
       (display dest)
       (newline))

      ;; Destination is a real file or directory -- refuse to clobber
      (else
       (display "  SKIP  ")
       (display dest)
       (display " (exists and is not a symlink)")
       (newline)))))

;; Manifest parsing

(define (split-line line)
  (let ((line (string-trim line)))
    (if (or (string-null? line)
            (char=? (string-ref line 0) #\#))
        #f
        (let ((len (string-length line)))
          (let loop ((i 0))
            (cond
              ((>= i len)
               (values line ""))
              ((char-whitespace? (string-ref line i))
               (let ((src (string-trim-right (substring line 0 i)))
                     (dst (string-trim-left (substring line i len))))
                 (values src dst)))
              (else
               (loop (+ i 1)))))))))

(define (process-manifest dotdir manifest-file)
  (let ((manifest-path (path-join dotdir manifest-file)))
    (call-with-input-file manifest-path
      (lambda (port)
        (let loop ()
          (let ((line (read-line port)))
            (unless (eof-object? line)
              (let ((result (split-line line)))
                (when result
                  (let-values (((src dst) result))
                    (if (or (string-null? src) (string-null? dst))
                        (begin
                          (display "  ERR   invalid line: ")
                          (display line)
                          (newline))
                        (let ((abs-src (path-join dotdir src))
                              (abs-dst (absolute-path dst)))
                          (ensure-symlink abs-src abs-dst))))))
              (loop))))))))

;; Entry point

(define (main args)
  (let ((dotdir (absolute-path (if (null? args) "." (car args))))
        (manifest "manifest"))
    (display "Dotdir: ")
    (display dotdir)
    (newline)
    (process-manifest dotdir manifest)))

(main (cdr (command-line)))
