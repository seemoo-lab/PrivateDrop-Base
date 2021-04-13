//
//  cms_sign_wrapper.c
//  OpenSSL
//
//  Created by Alex - SEEMOO on 28.10.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

#include "cms_sign_wrapper.h"
#include <string.h>
#include "./include/openssl/provider.h"

int signCMS(const char* data_file_path, const char* sign_cert_path, const char* cert_password, const char* cms_out_file_path) {
    BIO *in = NULL, *out = NULL, *tbio = NULL;
    X509 *scert = NULL;
    EVP_PKEY *skey = NULL;
    PKCS7 *p7 = NULL;
    int ret = 1;
    
    /*
     * For simple S/MIME signing use PKCS7_DETACHED. On OpenSSL 0.9.9 only:
     * for streaming detached set PKCS7_DETACHED|PKCS7_STREAM for streaming
     * non-detached set PKCS7_STREAM
     */
    int flags = 0 ;
    
    OpenSSL_add_all_algorithms();
//    OSSL_PROVIDER *legacy = NULL;
//    legacy = OSSL_PROVIDER_load(NULL, "legacy");
//    if (legacy == NULL) {
//        printf("Failed to load legacy providers\n");
//    }
    
    ERR_load_crypto_strings();
    
    /* Read in signer certificate and private key */
    tbio = BIO_new_file(sign_cert_path, "r");
    
    if (!tbio)
        goto err;
    
    
    if (strstr(sign_cert_path, "pem") != NULL) {
        //Import PEM
        scert = PEM_read_bio_X509(tbio, NULL, 0, NULL);
        
        BIO_reset(tbio);
        
        if (cert_password != NULL) {
            void *pass = strdup(cert_password);
            skey = PEM_read_bio_PrivateKey(tbio, NULL, 0, pass);
            free(pass);
        }else {
            skey = PEM_read_bio_PrivateKey(tbio, NULL, 0, NULL);
        }
    }else if (strstr(sign_cert_path, "p12") != NULL) {
        // Import from PKCS12
        PKCS12 *p12 = NULL;
        p12 = d2i_PKCS12_bio(tbio, NULL);
        STACK_OF(X509) *ca = NULL;
        
        if (!PKCS12_parse(p12, cert_password, &skey, &scert, &ca)) {
            fprintf(stderr, "Error parsing PKCS#12 file\n");
            goto err;
        }
        PKCS12_free(p12);
        sk_X509_pop_free(ca, X509_free);
    }else {
        fprintf(stderr, "Could not load certificate\n");
        goto err;
    }
    
    
    if (!scert || !skey)
        goto err;
    
    /* Open content being signed */
    
    in = BIO_new_file(data_file_path, "r");
    
    if (!in)
        goto err;
    
    /* Sign content */
    p7 = PKCS7_sign(scert, skey, NULL, in, flags);
    
    if (!p7)
        goto err;
    
    out = BIO_new_file(cms_out_file_path, "w");
    if (!out)
        goto err;
    
    if (!(flags & PKCS7_STREAM))
        BIO_reset(in);
    
    
    /* Write out PKCS7 message */
    if (!i2d_PKCS7_bio(out, p7))
        goto err;
    
    
    ret = 0;
    
err:
    if (ret) {
        fprintf(stderr, "Error Signing Data\n");
        ERR_print_errors_fp(stderr);
    }
    PKCS7_free(p7);
    X509_free(scert);
    EVP_PKEY_free(skey);
    BIO_free(in);
    BIO_free(out);
    BIO_free(tbio);
    
    return ret;
}
