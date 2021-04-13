//
//  cms_sign_wrapper.h
//  OpenSSL
//
//  Created by Alex - SEEMOO on 28.10.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

#ifndef cms_sign_wrapper_h
#define cms_sign_wrapper_h

#include <stdio.h>
#include "./include/openssl/pem.h"
#include "./include/openssl/err.h"
#include "./include/openssl/cms.h"
#include "./include/openssl/x509.h"

int signCMS(const char* data_file_path, const char* sign_cert_path, const char* cert_password, const char* cms_out_file_path);

#endif /* cms_sign_wrapper_h */
