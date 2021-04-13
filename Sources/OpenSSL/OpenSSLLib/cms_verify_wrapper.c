//
//  cms_verify_wrapper.c
//  OpenSSL
//
//  Created by Alex - SEEMOO on 27.10.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

#include "cms_verify_wrapper.h"
#include <string.h>

int verifyCMS(const char* ca_file_path, const char* cms_file_path,const char *cms_out_path) {
    BIO *in = NULL, *out = NULL, *tbio = NULL;
    X509_STORE *st = NULL;
    X509 *cacert = NULL;
    CMS_ContentInfo *cms = NULL;
    PKCS7 *p7 = NULL;

    int ret = 1;

    OpenSSL_add_all_algorithms();
    ERR_load_crypto_strings();

    /* Set up trusted CA certificate store */

    st = X509_STORE_new();

    /* Read in CA certificate */
    tbio = BIO_new_file(ca_file_path, "r");

    if (!tbio)
        goto err;

    if (strstr(ca_file_path, "pem") != NULL) {
        cacert = PEM_read_bio_X509(tbio, NULL, 0, NULL);
    }else {
        cacert = d2i_X509_bio(tbio, NULL);
    }

    if (!cacert)
        goto err;

    if (!X509_STORE_add_cert(st, cacert))
        goto err;

    /* Open message being verified */

    in = BIO_new_file(cms_file_path, "r");

    if (!in)
        goto err;

    /* parse message */
//    cms = SMIME_read_CMS(in, &cont);
    
//    p7 = SMIME_read_PKCS7(in, &cont);
    p7 = d2i_PKCS7_bio(in, NULL);

    if (!p7)
        goto err;

    /* File to output verified content to */
    out = BIO_new_file(cms_out_path, "w");
    if (!out)
        goto err;

    if (!PKCS7_verify(p7, NULL, st, NULL, out, 0)) {
        fprintf(stderr, "Verification Failure\n");
        goto err;
    }
//
//    if (!CMS_verify(cms, NULL, st, cont, out, 0)) {
//        fprintf(stderr, "Verification Failure\n");
//        goto err;
//    }

    BIO_set_close(out, BIO_CLOSE); 
    fprintf(stderr, "Verification Successful\n");

    ret = 0;

 err:

    if (ret) {
        fprintf(stderr, "Error Verifying Data\n");
        ERR_print_errors_fp(stderr);
    }

    CMS_ContentInfo_free(cms);
    X509_free(cacert);
    BIO_free(in);
    BIO_free(out);
    BIO_free(tbio);
    return ret;
}
