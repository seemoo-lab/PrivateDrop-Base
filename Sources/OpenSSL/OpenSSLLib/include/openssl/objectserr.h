/*
 * Generated by util/mkerr.pl DO NOT EDIT
 * Copyright 1995-2020 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the Apache License 2.0 (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#ifndef OPENSSL_OBJERR_H
# define OPENSSL_OBJERR_H
# pragma once

#include "opensslconf.h"
#include "symhacks.h"


# ifdef  __cplusplus
extern "C"
# endif
int ERR_load_OBJ_strings(void);

/*
 * OBJ function codes.
 */
# ifndef OPENSSL_NO_DEPRECATED_3_0
#  define OBJ_F_OBJ_ADD_OBJECT                             0
#  define OBJ_F_OBJ_ADD_SIGID                              0
#  define OBJ_F_OBJ_CREATE                                 0
#  define OBJ_F_OBJ_DUP                                    0
#  define OBJ_F_OBJ_NAME_NEW_INDEX                         0
#  define OBJ_F_OBJ_NID2LN                                 0
#  define OBJ_F_OBJ_NID2OBJ                                0
#  define OBJ_F_OBJ_NID2SN                                 0
#  define OBJ_F_OBJ_TXT2OBJ                                0
# endif

/*
 * OBJ reason codes.
 */
# define OBJ_R_OID_EXISTS                                 102
# define OBJ_R_UNKNOWN_NID                                101
# define OBJ_R_UNKNOWN_OBJECT_NAME                        103

#endif
