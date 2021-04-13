//
//  relic_wrapper.h
//  PSI
//
//  Created by Alex - SEEMOO on 16.07.20.
//

#ifndef relic_wrapper_h
#define relic_wrapper_h

#include <stdio.h>
#include "./include/relic.h"


void ec_curve_get_order(bn_t bn);

/**
* Reduces a multiple precision integer modulo another integer. If the number
* of arguments is 3, then simple division is used. If the number of arguments
* is 4, then a modular reduction algorithm is used and the fourth argument
* is an auxiliary value derived from the modulus. The variant with 4 arguments
* should be used when several modular reductions are computed with the same
* modulus. Computes c = a mod m.
*
* @param[out] C            - the result.
* @param[in] A                - the multiple precision integer to reduce.
* @param[in] ...            - the modulus and an optional argument.
*/
void bn_w_modulus(bn_t c, bn_t a, bn_t m);

/**
* Multiplies the generator of a prime elliptic curve by an integer.
*
* @param[out] R                - the result.
* @param[in] K                    - the integer.
*/
void ec_multiply_gen(ec_t out, bn_t bn);

/**
* Multiplies an elliptic curve point by an integer. Computes R = kP.
*
* @param[out] R                - the result.
* @param[in] P                    - the point to multiply.
* @param[in] K                    - the integer.
*/
void ec_multiply(ec_t r, ec_t p, bn_t k);

/**
* Returns the number of bytes necessary to store an elliptic curve point with
* optional point compression.
*
* @param[in] A                    - the elliptic curve point.
* @param[in] P                    - the flag to indicate compression.
*/
int ec_binary_size(ec_t a, int p);

/**
* Adds two elliptic curve points. Computes R = P + Q.
*
* @param[out] R                - the result.
* @param[in] P                    - the first point to add.
* @param[in] Q                    - the second point to add.
*/
void ec_addition(ec_t r, ec_t p, ec_t q);

/**
* Writes an elliptic curve point to a byte vector in big-endian format with
* optional point compression.
*
* @param[out] B                - the byte vector.
* @param[in] L                    - the buffer capacity.
* @param[in] A                    - the prime elliptic curve point to write.
* @param[in] P                    - the flag to indicate point compression.
*/
void ec_write_binary(uint8_t *b, int l, ec_t a, int p);

/**
* Compares two elliptic curve points.
*
* @param[in] P                    - the first elliptic curve point.
* @param[in] Q                    - the second elliptic curve point.
* @return RLC_EQ if P == Q and RLC_NE if P != Q.
*/
int ec_compare(ec_t p, ec_t q);

void test_ec_curve_functions();

int ec_set_any_params();

void ep_set_params_compatibility();


/// Initialize a big number. Will null it first and then call bn_new
/// @param b an emtpy big number
void bn_initialize(bn_t b);

/**
* Reads an elliptic curve point from a byte vector in big-endian format.
*
* @param[out] A                - the result.
* @param[in] B                    - the byte vector.
* @param[in] L                    - the buffer capacity.
*/
void ec_read_binary(ec_t a, uint8_t *b, int len);

#endif /* relic_wrapper_h */
