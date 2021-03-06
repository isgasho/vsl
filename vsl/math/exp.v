// Copyright (c) 2019 Ulises Jeremias Cornejo Fandos. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module math

const (
	dbl_max_exp = f64(1024)
	dbl_min_exp = f64(-1021)

	othreshold = 7.09782712893383973096e+02 // 0x40862E42FEFA39EF
	ln2_x56 = 3.88162421113569373274e+01 // 0x4043687a9f1af2b1
	ln2_halfX3 = 1.03972077083991796413e+00 // 0x3ff0a2b23f3bab73
	ln2_half = 3.46573590279972654709e-01 // 0x3fd62e42fefa39ef
	ln2Hi = 6.93147180369123816490e-01 // 0x3fe62e42fee00000
	ln2Lo = 1.90821492927058770002e-10 // 0x3dea39ef35793c76
	inv_ln2 = 1.44269504088896338700e+00 // 0x3ff71547652b82fe
	tiny = 1.0 / (1<<54) // 2**-54 = 0x3c90000000000000
	// scaled coefficients related to expm1
	q1 = -3.33333333333331316428e-02 // 0xBFA11111111110F4
	q2 = 1.58730158725481460165e-03 // 0x3F5A01A019FE5585
	q3 = -7.93650757867487942473e-05 // 0xBF14CE199EAADBB7
	q4 = 4.00821782732936239552e-06 // 0x3ED0CFCA86E65239
	q5 = -2.01099218183624371326e-07 // 0xBE8AFDB76E09C32D
)

pub fn ldexp(x f64, e int) f64 {
	if x == 0.0 {
		return x
	}
	else {
		mut y,ex := frexp(x)
		mut e2 := f64(e + ex)
		if e2 >= dbl_max_exp {
			y *= pow(2.0, e2 - dbl_max_exp + 1.0)
			e2 = dbl_max_exp - 1.0
		}
		else if e2 <= dbl_min_exp {
			y *= pow(2.0, e2 - dbl_min_exp - 1.0)
			e2 = dbl_min_exp + 1.0
		}
		p2 := pow(2.0, e2)
		return y * p2
	}
}

// frexp breaks f into a normalized fraction
// and an integral power of two.
// It returns frac and exp satisfying f == frac × 2**exp,
// with the absolute value of frac in the interval [½, 1).
//
// Special cases are:
// frexp(±0) = ±0, 0
// frexp(±Inf) = ±Inf, 0
// frexp(NaN) = NaN, 0
pub fn frexp(x f64) (f64, int) {
	if x == 0.0 {
                return f64(0.0), 0
        }
        else if !is_finite(x) {
                return x, 0
        }
        else if abs(x) >= 0.5 && abs(x) < 1 {    /* Handle the common case */
                return x, 0
        }
        else {
                ex := ceil(log(abs(x)) / ln2)
                mut ei := int(ex)

                /* Prevent underflow and overflow of 2**(-ei) */
                if ei < int(dbl_min_exp) {
                        ei = int(dbl_min_exp)
                }

                if ei > -int(dbl_min_exp) {
                        ei = -int(dbl_min_exp)
                }

                mut f := x * pow (2.0, -ei)

                if !is_finite(f) {
                        /* This should not happen */
                        return f, 0
                }

                for abs(f) >= 1.0 {
                        ei++
                        f /= 2.0
                }

                for abs(f) > 0 && abs(f) < 0.5 {
                        ei--
                        f *= 2.0
                }

                return f, ei
        }
}

// The original C code, the long comment, and the constants
// below are from FreeBSD's /usr/src/lib/msun/src/s_expm1.c
// and came with this notice. The go code is a simplified
// version of the original C.
//
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunPro, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================
//
// expm1(x)
// Returns exp(x)-1, the exponential of x minus 1.
//
// Method
// 1. Argument reduction:
// Given x, find r and integer k such that
//
// x = k*ln2 + r,  |r| <= 0.5*ln2 ~ 0.34658
//
// Here a correction term c will be computed to compensate
// the error in r when rounded to a floating-point number.
//
// 2. Approximating expm1(r) by a special rational function on
// the interval [0,0.34658]:
// Since
// r*(exp(r)+1)/(exp(r)-1) = 2+ r**2/6 - r**4/360 + ...
// we define R1(r*r) by
// r*(exp(r)+1)/(exp(r)-1) = 2+ r**2/6 * R1(r*r)
// That is,
// R1(r**2) = 6/r *((exp(r)+1)/(exp(r)-1) - 2/r)
// = 6/r * ( 1 + 2.0*(1/(exp(r)-1) - 1/r))
// = 1 - r**2/60 + r**4/2520 - r**6/100800 + ...
// We use a special Reme algorithm on [0,0.347] to generate
// a polynomial of degree 5 in r*r to approximate R1. The
// maximum error of this polynomial approximation is bounded
// by 2**-61. In other words,
// R1(z) ~ 1.0 + q1*z + q2*z**2 + q3*z**3 + q4*z**4 + q5*z**5
// where   q1  =  -1.6666666666666567384E-2,
// q2  =   3.9682539681370365873E-4,
// q3  =  -9.9206344733435987357E-6,
// q4  =   2.5051361420808517002E-7,
// q5  =  -6.2843505682382617102E-9;
// (where z=r*r, and the values of q1 to q5 are listed below)
// with error bounded by
// |                  5           |     -61
// | 1.0+q1*z+...+q5*z   -  R1(z) | <= 2
// |                              |
//
// expm1(r) = exp(r)-1 is then computed by the following
// specific way which minimize the accumulation rounding error:
// 2     3
// r     r    [ 3 - (R1 + R1*r/2)  ]
// expm1(r) = r + --- + --- * [--------------------]
// 2     2    [ 6 - r*(3 - R1*r/2) ]
//
// To compensate the error in the argument reduction, we use
// expm1(r+c) = expm1(r) + c + expm1(r)*c
// ~ expm1(r) + c + r*c
// Thus c+r*c will be added in as the correction terms for
// expm1(r+c). Now rearrange the term to avoid optimization
// screw up:
// (      2                                    2 )
// ({  ( r    [ R1 -  (3 - R1*r/2) ]  )  }    r  )
// expm1(r+c)~r - ({r*(--- * [--------------------]-c)-c} - --- )
// ({  ( 2    [ 6 - r*(3 - R1*r/2) ]  )  }    2  )
// (                                             )
//
// = r - E
// 3. Scale back to obtain expm1(x):
// From step 1, we have
// expm1(x) = either 2**k*[expm1(r)+1] - 1
// = or     2**k*[expm1(r) + (1-2**-k)]
// 4. Implementation notes:
// (A). To save one multiplication, we scale the coefficient qi
// to qi*2**i, and replace z by (x**2)/2.
// (B). To achieve maximum accuracy, we compute expm1(x) by
// (i)   if x < -56*ln2, return -1.0, (raise inexact if x!=inf)
// (ii)  if k=0, return r-E
// (iii) if k=-1, return 0.5*(r-E)-0.5
// (iv)  if k=1 if r < -0.25, return 2*((r+0.5)- E)
// else          return  1.0+2.0*(r-E);
// (v)   if (k<-2||k>56) return 2**k(1-(E-r)) - 1 (or exp(x)-1)
// (vi)  if k <= 20, return 2**k((1-2**-k)-(E-r)), else
// (vii) return 2**k(1-((E+2**-k)-r))
//
// Special cases:
// expm1(INF) is INF, expm1(NaN) is NaN;
// expm1(-INF) is -1, and
// for finite argument, only expm1(0)=0 is exact.
//
// Accuracy:
// according to an error analysis, the error is always less than
// 1 ulp (unit in the last place).
//
// Misc. info.
// For IEEE double
// if x >  7.09782712893383973096e+02 then expm1(x) overflow
//
// Constants:
// The hexadecimal values are the intended ones for the following
// constants. The decimal values may be used, provided that the
// compiler will convert from decimal to binary accurately enough
// to produce the hexadecimal values shown.
//
// expm1 returns e**x - 1, the base-e exponential of x minus 1.
// It is more accurate than Exp(x) - 1 when x is near zero.
//
// Special cases are:
// expm1(+Inf) = +Inf
// expm1(-Inf) = -1
// expm1(NaN) = NaN
// Very large values overflow to -1 or +Inf.
pub fn expm1(x_ f64) f64 {
	mut x := x_
	// special cases
	if is_inf(x, 1) || is_nan(x) {
		return x
	}
	else if is_inf(x, -1) {
		return -1
	}
	mut absx := x
	mut sign := false
	if x < 0 {
		absx = -absx
		sign = true
	}
	// filter out huge argument
	if absx >= ln2_x56 {
		// if |x| >= 56 * ln2
		if sign {
			return -1 // x < -56*ln2, return -1
		}
		if absx >= othreshold {
			// if |x| >= 709.78...
			return inf(1)
		}
	}
	// argument reduction
	mut c := f64(0.0)
	mut k := 0
	if absx > ln2_half {
		// if  |x| > 0.5 * ln2
		mut hi := f64(0.0)
		mut lo := f64(0.0)
		if absx < ln2_halfX3 {
			// and |x| < 1.5 * ln2
			if !sign {
				hi = x - ln2Hi
				lo = ln2Lo
				k = 1
			}
			else {
				hi = x + ln2Hi
				lo = -ln2Lo
				k = -1
			}
		}
		else {
			if !sign {
				k = int(inv_ln2 * x + 0.5)
			}
			else {
				k = int(inv_ln2 * x - 0.5)
			}
			t := f64(k)
			hi = x - t * ln2Hi // t * ln2Hi is exact here
			lo = t * ln2Lo
		}
		x = hi - lo
		c = (hi - x) - lo
	}
	else if absx < tiny {
		// when |x| < 2**-54, return x
		return x
	}
	else {
		k = 0
	}
	// x is now in primary range
	hfx := 0.5 * x
	hxs := x * hfx
	r1 := 1.0 + hxs * (q1 + hxs * (q2 + hxs * (q3 + hxs * (q4 + hxs * q5))))
	mut t := 3.0 - r1 * hfx
	mut e := hxs * ((r1 - t) / (6.0 - x * t))
	if k == 0 {
		return x - (x * e - hxs) // c is 0
	}
	e = (x * (e - c) - c)
	e -= hxs
	if k == -1 {
		return 0.5 * (x - e) - 0.5
	}
	else if k == 1 {
		if x < -0.25 {
			return -2.0 * (e - (x + 0.5))
		}
		return 1.0 + 2.0 * (x - e)
	}
	else if k <= -2 || k > 56 {
		// suffice to return exp(x)-1
		mut y := 1.0 - (e - x)
		y = f64_from_bits(f64_bits(y) + (u64(k)<<52)) // add k to y's exponent
		return y - 1
	}
	if k < 20 {
		t = f64_from_bits(0x3ff0000000000000 - (0x20000000000000>>u32(k))) // t=1-2**-k
		mut y := t - (e - x)
		y = f64_from_bits(f64_bits(y) + (u64(k)<<52)) // add k to y's exponent
		return y
	}
	t = f64_from_bits(u64(0x3ff - k)<<52) // 2**-k
	mut y := x - (e + t)
	y++
	y = f64_from_bits(f64_bits(y) + (u64(k)<<52)) // add k to y's exponent
	return y
}
