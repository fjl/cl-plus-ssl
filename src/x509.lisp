(in-package :cl+ssl)

;; ffi
;; X509 *d2i_X509(X509 **px, const unsigned char **in, int len);

(cffi:defcfun ("X509_free" x509-free)
    :void
  (x509 :pointer))

(cffi:defcfun ("X509_NAME_oneline" x509-name-oneline)
    :pointer
  (x509-name :pointer)
  (buf :pointer)
  (size :int))

(cffi:defcfun ("X509_NAME_get_index_by_NID" x509-name-get-index-by-nid)
    :int
  (name :pointer)
  (nid :int)
  (lastpos :int))

(cffi:defcfun ("X509_NAME_get_entry" x509-name-get-entry)
    :pointer
  (name :pointer)
  (log :int))

(cffi:defcfun ("X509_NAME_ENTRY_get_data" x509-name-entry-get-data)
    :pointer
  (name-entry :pointer))

(cffi:defcfun ("X509_get_issuer_name" x509-get-issuer-name)
    :pointer                            ; *X509_NAME
  (x509 :pointer))

(cffi:defcfun ("X509_get_subject_name" x509-get-subject-name)
    :pointer                            ; *X509_NAME
  (x509 :pointer))

(cffi:defcfun ("X509_get_ext_d2i" x509-get-ext-d2i)
    :pointer
  (cert :pointer)
  (nid :int)
  (crit :pointer)
  (idx :pointer))

(cffi:defcfun ("X509_STORE_CTX_get_error" x509-store-ctx-get-error)
    :int
  (ctx :pointer))

(cffi:defcfun ("d2i_X509" d2i-x509)
    :pointer
  (*px :pointer)
  (in :pointer)
  (len :int))

;; GENERAL-NAME types
(defconstant +GEN-OTHERNAME+  0)
(defconstant +GEN-EMAIL+  1)
(defconstant +GEN-DNS+    2)
(defconstant +GEN-X400+ 3)
(defconstant +GEN-DIRNAME+  4)
(defconstant +GEN-EDIPARTY+ 5)
(defconstant +GEN-URI+    6)
(defconstant +GEN-IPADD+  7)
(defconstant +GEN-RID+    8)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +V-ASN1-OCTET-STRING+ 4)
  (defconstant +V-ASN1-UTF8STRING+ 12)
  (defconstant +V-ASN1-PRINTABLESTRING+ 19)
  (defconstant +V-ASN1-TELETEXSTRING+ 20)
  (defconstant +V-ASN1-IASTRING+ 22)
  (defconstant +V-ASN1-UNIVERSALSTRING+ 28)
  (defconstant +V-ASN1-BMPSTRING+ 30))


(defconstant +NID-subject-alt-name+ 85)
(defconstant +NID-commonName+   13)

(cffi:defcstruct general-name
  (type :int)
  (data :pointer))

(cffi:defcfun ("sk_value" sk-value)
    :pointer
  (stack :pointer)
  (index :int))

(cffi:defcfun ("sk_num" sk-num)
    :int
  (stack :pointer))

(declaim (ftype (function (cffi:foreign-pointer fixnum) cffi:foreign-pointer) sk-general-name-value))
(defun sk-general-name-value (names index)
  (sk-value names index))

(declaim (ftype (function (cffi:foreign-pointer) fixnum) sk-general-name-num))
(defun sk-general-name-num (names)
  (sk-num names))

(cffi:defcfun ("GENERAL_NAMES_free" general-names-free)
    :void
  (general-names :pointer))

(cffi:defcfun ("ASN1_STRING_data" asn1-string-data)
    :pointer
  (asn1-string :pointer))

(cffi:defcfun ("ASN1_STRING_length" asn1-string-length)
    :int
  (asn1-string :pointer))

(cffi:defcfun ("ASN1_STRING_type" asn1-string-type)
    :int
  (asn1-string :pointer))

(cffi:defcfun ("strlen" strlen)
    :int
  (string :string))

(cffi:defcfun (memcpy "memcpy") :pointer
  (dest :pointer)
  (src  :pointer)
  (count :int))

(cffi:defcstruct asn1_string_st
  (length :int)
  (type :int)
  (data :pointer)
  (flags :long))


#|
ASN1 string validation references:
 - https://github.com/digitalbazaar/forge/blob/909e312878838f46ba6d70e90264650b05eb8bde/js/asn1.js
 - http://www.obj-sys.com/asn1tutorial/node128.html
 - https://github.com/deadtrickster/ssl_verify_hostname.erl/blob/master/src/ssl_verify_hostname.erl
 - https://golang.org/src/encoding/asn1/asn1.go?m=text
|#
(defgeneric decode-asn1-string (asn1-string type))

(defun copy-bytes-to-lisp-vector (src-ptr vector count)
  (cffi:with-pointer-to-vector-data (dst-ptr vector)
    (memcpy dst-ptr src-ptr count)))

(defun asn1-string-bytes-vector (asn1-string)
  (let* ((data (asn1-string-data asn1-string))
         (length (asn1-string-length asn1-string))
         (vector (cffi:make-shareable-byte-vector length)))
    (copy-bytes-to-lisp-vector data vector length)
    vector))

(defun asn1-iastring-char-p (byte)
  (declare (type (unsigned-byte 8) byte)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  (< byte #x80))

(defun asn1-iastring-p (bytes)
  (declare (type (simple-array (unsigned-byte 8)) bytes)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  (every #'asn1-iastring-char-p bytes))

(defmethod decode-asn1-string (asn1-string (type (eql #.+v-asn1-iastring+)))
  (let* ((data (asn1-string-data asn1-string))
         (length (asn1-string-length asn1-string))
         (strlen (strlen data)))
    (if (= strlen length)
        (let ((bytes (asn1-string-bytes-vector asn1-string)))
          (if (asn1-iastring-p bytes)
              (cffi:foreign-string-to-lisp data :encoding :ascii)
              (error 'invalid-asn1-string :type '+v-asn1-iastring+)))
        (error 'invalid-asn1-string :type '+v-asn1-iastring+))))

(defun asn1-printable-char-p (byte)
  (declare (type (unsigned-byte 8) byte)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  (cond
    ;; a-z
    ((and (>= byte #.(char-code #\a))
          (<= byte #.(char-code #\z)))
     t)
    ;; '-/
    ((and (>= byte #.(char-code #\'))
          (<= byte #.(char-code #\/)))
     t)
    ;; 0-9
    ((and (>= byte #.(char-code #\0))
          (<= byte #.(char-code #\9)))
     t)
    ;; A-Z
    ((and (>= byte #.(char-code #\A))
          (<= byte #.(char-code #\Z)))
     t)
    ;; other
    ((= byte #.(char-code #\ )) t)
    ((= byte #.(char-code #\:)) t)
    ((= byte #.(char-code #\=)) t)
    ((= byte #.(char-code #\?)) t)))

(defun asn1-printable-string-p (bytes)
  (declare (type (simple-array (unsigned-byte 8)) bytes)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  (every #'asn1-printable-char-p bytes))

(defmethod decode-asn1-string (asn1-string (type (eql #.+v-asn1-printablestring+)))
  (let* ((bytes (asn1-string-bytes-vector asn1-string)))
    (if (asn1-printable-string-p bytes)
        (babel:octets-to-string bytes :encoding :ascii)
        (error 'invalid-asn1-string :type '+v-asn1-printablestring+))))

(defmethod decode-asn1-string (asn1-string (type (eql #.+v-asn1-utf8string+)))
  (let* ((data (asn1-string-data asn1-string))
         (length (asn1-string-length asn1-string))
         (strlen (strlen data)))
    (if (= strlen length)
        (cffi:foreign-string-to-lisp data)
        (error 'invalid-asn1-string :type '+v-asn1-utf8string+))))

(defmethod decode-asn1-string (asn1-string (type (eql #.+v-asn1-universalstring+)))
  (if (= 0 (mod (asn1-string-length asn1-string) 4))
      ;; cffi sometimes fails here on sbcl? idk why (maybe threading?)
      ;; fail: Illegal :UTF-32 character starting at position 48...
      ;; when (length bytes) is 48...
      ;; so I'm passing :count explicitly
      (or (ignore-errors (cffi:foreign-string-to-lisp (asn1-string-data asn1-string) :count (asn1-string-length asn1-string) :encoding :utf-32))
          (error 'invalid-asn1-string :type '+v-asn1-universalstring+))
      (error 'invalid-asn1-string :type '+v-asn1-universalstring+)))

(defun asn1-teletex-char-p (byte)
  (declare (type (unsigned-byte 8) byte)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  (and (>= byte #x20)
       (< byte #x80)))

(defun asn1-teletex-string-p (bytes)
  (declare (type (simple-array (unsigned-byte 8)) bytes)
           (optimize (speed 3)
                     (debug 0)
                     (safety 0)))
  (every #'asn1-teletex-char-p bytes))

(defmethod decode-asn1-string (asn1-string (type (eql #.+v-asn1-teletexstring+)))
  (let* ((data (asn1-string-data asn1-string))
         (length (asn1-string-length asn1-string))
         (strlen (strlen data)))
    (if (= strlen length)
        (let ((bytes (asn1-string-bytes-vector asn1-string)))
          (if (asn1-teletex-string-p bytes)
              (cffi:foreign-string-to-lisp data :encoding :ascii)
              (error 'invalid-asn1-string :type '+v-asn1-teletexstring+)))
        (error 'invalid-asn1-string :type '+v-asn1-teletexstring+))))

(defmethod decode-asn1-string (asn1-string (type (eql #.+v-asn1-bmpstring+)))
  (if (= 0 (mod (asn1-string-length asn1-string) 2))
      (or (ignore-errors (cffi:foreign-string-to-lisp (asn1-string-data asn1-string) :count (asn1-string-length asn1-string) :encoding :utf-16/be))
          (error 'invalid-asn1-string :type '+v-asn1-bmpstring+))
      (error 'invalid-asn1-string :type '+v-asn1-bmpstring+)))

;; TODO: respect asn1-string type
(defun try-get-asn1-string-data (asn1-string allowed-types)
  (let ((type (asn1-string-type asn1-string)))
    (assert (member (asn1-string-type asn1-string) allowed-types) nil "Invalid asn1 string type")
    (decode-asn1-string asn1-string type)))

(defun slurp-stream (stream)
  (let ((seq (make-array (file-length stream) :element-type '(unsigned-byte 8))))
    (read-sequence seq stream)
    seq))

(defmethod decode-certificate ((format (eql :der)) bytes)
  (cffi:with-pointer-to-vector-data (buf* bytes)
    (cffi:with-foreign-object (buf** :pointer)
      (setf (cffi:mem-ref buf** :pointer) buf*)
      (d2i-x509 (cffi:null-pointer) buf** (length bytes)))))

(defun cert-format-from-path (path)
  ;; or match "pem" type too and raise unknown format error?
  (if (equal "der" (pathname-type path))
      :der
      :pem))

(defun decode-certificate-from-file (path &key format)
  (let ((bytes (with-open-file (stream path :element-type '(unsigned-byte 8))
                 (slurp-stream stream)))
        (format (or format (cert-format-from-path path))))
    (decode-certificate format bytes)))

(defun certificate-alt-names (cert)
  (x509-get-ext-d2i cert +NID-subject-alt-name+ (cffi:null-pointer) (cffi:null-pointer)))

(defun certificate-dns-alt-names (cert)
  (let ((altnames (certificate-alt-names cert)))
    (unless (cffi:null-pointer-p altnames)
      (unwind-protect
           (flet ((alt-name-to-string (alt-name)
                    (cffi:with-foreign-slots ((type data) alt-name (:struct general-name))
                      (when (= type +GEN-DNS+)
                        (if-let ((string (try-get-asn1-string-data data '(#.+v-asn1-iastring+))))
                          string
                          (error "Malformed certificate: possibly NULL in dns-alt-name"))))))
             (let ((altnames-count (sk-general-name-num altnames)))
               (loop for i from 0 below altnames-count
                     as alt-name = (sk-general-name-value altnames i)
                     collect (alt-name-to-string alt-name))))
        (general-names-free altnames)))))

(defun certificate-subject-common-names (cert)
  (let ((i -1)
        (subject-name (x509-get-subject-name cert)))
    (flet ((extract-cn ()
             (setf i (x509-name-get-index-by-nid subject-name +NID-commonName+ i))
             (when (>= i 0)
               (let* ((entry (x509-name-get-entry subject-name i)))
                 (try-get-asn1-string-data (x509-name-entry-get-data entry) '(#.+v-asn1-utf8string+
                                                                              #.+v-asn1-bmpstring+
                                                                              #.+v-asn1-printablestring+
                                                                              #.+v-asn1-universalstring+
                                                                              #.+v-asn1-teletexstring+))))))
      (loop
        as cn = (extract-cn)
        if cn collect cn
        if (not cn) do
           (loop-finish)))))
