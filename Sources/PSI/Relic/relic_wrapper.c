//
//  relic_wrapper.c
//  PSI
//
//  Created by Alex - SEEMOO on 16.07.20.
//

#include "relic_wrapper.h"
#include "relic.h"

void test_ec_curve_functions(void) {
    //1. Get order
    bn_t n;
    bn_null(n);
    bn_new(n);
    
    ep_curve_get_ord(n);
    ec_curve_get_ord(n);
}

int ec_set_any_params(void) {
    return ec_param_set_any();
}

void ep_set_params_compatibility(void) {
    // default iOS 
    ep_param_set(BN_254);
    //default macOS
//    ep_param_set(NIST_P256);
    
//     common curve 25519
//    ep_param_set(CURVE_25519);
    
}

void ec_curve_get_order(bn_t bn) {
    ec_curve_get_ord(bn);
}

void ec_multiply_gen(ec_t out, bn_t bn) {
    ec_mul_gen(out, bn);
}

void ec_multiply(ec_t r, ec_t p, bn_t k) {
    ec_mul(r, p, k);
}

int ec_binary_size(ec_t a, int p) {
    return ec_size_bin(a, p);
}

void ec_write_binary(uint8_t *b, int l, ec_t a, int p) {
    ec_write_bin(b, l, a, p); 
}

void ec_read_binary(ec_t a, uint8_t *b, int len) {
    ec_read_bin(a, b, len);
}

void ec_addition(ec_t r, ec_t p, ec_t q) {
    ec_add(r, p, q);
}

int ec_compare(ec_t p, ec_t q) {
    return ec_cmp(p, q);
}

void bn_w_modulus(bn_t c, bn_t a, bn_t m){
    bn_mod(c, a, m);
}

void bn_initialize(bn_t b) {
    bn_null(b);
    bn_new(b);
}

