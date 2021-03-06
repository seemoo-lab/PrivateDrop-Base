/*
 * Generated by util/mkerr.pl DO NOT EDIT
 * Copyright 1995-2020 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the Apache License 2.0 (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#ifndef OPENSSL_COMPERR_H
# define OPENSSL_COMPERR_H
# pragma once

#include "opensslconf.h"
#include "symhacks.h"


#include "opensslconf.h"

# ifndef OPENSSL_NO_COMP

#  ifdef  __cplusplus
extern "C"
#  endif
int ERR_load_COMP_strings(void);

/*
 * COMP function codes.
 */
# ifndef OPENSSL_NO_DEPRECATED_3_0
#   define COMP_F_BIO_ZLIB_FLUSH                            0
#   define COMP_F_BIO_ZLIB_NEW                              0
#   define COMP_F_BIO_ZLIB_READ                             0
#   define COMP_F_BIO_ZLIB_WRITE                            0
#   define COMP_F_COMP_CTX_NEW                              0
# endif

/*
 * COMP reason codes.
 */
#  define COMP_R_ZLIB_DEFLATE_ERROR                        99
#  define COMP_R_ZLIB_INFLATE_ERROR                        100
#  define COMP_R_ZLIB_NOT_SUPPORTED                        101

# endif
#endif
