#ifndef lib_fp_h
#define lib_fp_h

#ifdef BUILD_MODE_HYBRID
    // Decalre the external variables
    extern uint8_t FP_FP1;
    extern uint8_t FP_FP2;

    // Declare the external assembly routine (no underscore in C)
    extern void FP_FADD(void);
    extern void FP_FSUB(void);
    extern void FP_FMUL(void);
    extern void FP_FDIV(void);
    extern void FP_FLOAT(void);
    extern void FP_FIX(void);
    extern void FP_SWAP(void);
    extern void FP_NORM(void);
    extern void FP_RTAR(void);
    extern void FP_NEGATE(void);
#endif /* !BUILD_MODE_HYBRID */

#endif // !lib_fp_h
