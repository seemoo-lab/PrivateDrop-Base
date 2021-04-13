//
//  cms_verify_wrapper.h
//  OpenSSL
//
//  Created by Alex - SEEMOO on 27.10.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

#ifndef cms_verify_wrapper_h
#define cms_verify_wrapper_h

#include <stdio.h>
#include "./include/openssl/pem.h"
#include "./include/openssl/err.h"
#include "./include/openssl/cms.h"
#include "./include/openssl/x509.h"

int verifyCMS(const char* ca_file_path, const char* cms_file_path,const char *cms_out_path);

#endif /* cms_verify_wrapper_h */
