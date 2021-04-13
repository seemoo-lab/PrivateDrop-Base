////
////  d2i_wrapper.c
////  OpenSSL
////
////  Created by Alex - SEEMOO on 23.07.20.
////
//
//#include "d2i_wrapper.h"
//#include "./include/openssl/pkcs12.h"
//
//PKCS7 *d2i_PKCS7_wrapped(PKCS7 *out,const uint8_t *inp, size_t len) {
//    
//    return d2i_PKCS7(&out, &inp, len);
//}
//
//
//RSA *d2i_RSAPrivateKey_wrapped(RSA * a, const uint8_t *inp, size_t len) {
//    return d2i_RSAPrivateKey(&a, &inp, len);
//}
//
//int certificate_and_key_from_p12(PKCS12 *p12,  EVP_PKEY *pkey, X509 *x509, const char *pass, int passlen) {
//    
//    STACK_OF(PKCS7) *asafes = NULL;
//    STACK_OF(PKCS12_SAFEBAG) *bags;
//    int i, bagnid;
//    int ret = 0;
//    PKCS7 *p7;
//    
//    if ((asafes = PKCS12_unpack_authsafes(p12)) == NULL)
//        return 0;
//    for (i = 0; i < sk_PKCS7_num(asafes); i++) {
//        p7 = sk_PKCS7_value(asafes, i);
//        bagnid = OBJ_obj2nid(p7->type);
//        if (bagnid == NID_pkcs7_data) {
//            bags = PKCS12_unpack_p7data(p7);
//        } else if (bagnid == NID_pkcs7_encrypted) {
//            bags = PKCS12_unpack_p7encdata(p7, pass, passlen);
//        } else {
//            continue;
//        }
//        if (!bags) {
//            unsigned long error = ERR_get_error();
//            char errorString[1024];
//            ERR_error_string(error, errorString);
//            printf("Error occurred: %s\n", errorString);
//            
//            return 0;
//        }
//        
//        for (i = 0; i < sk_PKCS12_SAFEBAG_num(bags); i++) {
//            PKCS12_SAFEBAG *bag = sk_PKCS12_SAFEBAG_value(bags, i);
//            get_key_certificate_from(bag, pkey, x509, pass, -1);
//        }
//        
//        sk_PKCS12_SAFEBAG_pop_free(bags, PKCS12_SAFEBAG_free);
//        bags = NULL;
//    }
//    ret = 1;
//    
//    return ret; 
//}
//
//int get_key_certificate_from(PKCS12_SAFEBAG *bag, EVP_PKEY *pkey, X509 *x509, const char *pass, int passlen) {
//    PKCS8_PRIV_KEY_INFO *p8;
//    const PKCS8_PRIV_KEY_INFO *p8c;
//    
//    const STACK_OF(X509_ATTRIBUTE) *attrs;
//    int ret = 0;
//    
//    attrs = PKCS12_SAFEBAG_get0_attrs(bag);
//    
//    switch (PKCS12_SAFEBAG_get_nid(bag)) {
//    case NID_keyBag:
//        
//        p8c = PKCS12_SAFEBAG_get0_p8inf(bag);
//        if ((pkey = EVP_PKCS82PKEY(p8c)) == NULL)
//            return 0;
//        break;
//
//    case NID_pkcs8ShroudedKeyBag:
//            
//        if ((p8 = PKCS12_decrypt_skey(bag, pass, passlen)) == NULL){
//            unsigned long error = ERR_get_error();
//            char errorString[1024];
//            ERR_error_string(error, errorString);
//            printf("Error occurred: %s\n", errorString);
//            return 0;
//        }
//        if ((pkey = EVP_PKCS82PKEY(p8)) == NULL) {
//            PKCS8_PRIV_KEY_INFO_free(p8);
//            return 0;
//        }
//        PKCS8_PRIV_KEY_INFO_free(p8);
//        break;
//
//    case NID_certBag:
//        if (PKCS12_SAFEBAG_get0_attr(bag, NID_localKeyID)) {
//          
//        }
//            
//        if (PKCS12_SAFEBAG_get_bag_nid(bag) != NID_x509Certificate)
//            return 1;
//        if ((x509 = PKCS12_SAFEBAG_get1_cert(bag)) == NULL)
//            return 0;
//        break;
//
//    case NID_safeContentsBag:
//            break;
//    default:
//        return 1;
//    }
//    return ret;
//}
