#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#ifndef CopFILEGV_set
#define CopFILEGV_set(c, gv) ;; /* noop */
#endif

#define APPLY_TO_ALL_FN(m,t) \
    static void cop_ ## m ## _r(OP *op, t value) \
    {                                            \
        do {                                     \
            if (op->op_type == OP_NEXTSTATE) {   \
                COP *cop = (COP*)op;             \
                cop_ ## m(cop, value, 1, 0);     \
            }                                    \
        } while (op = op->op_next);              \
    }

static void cop_stashpv_r(OP *op, char *value);
static void cop_stash_r(OP *op, HV *value);
static void cop_file_r(OP *op, char *value);
static void cop_filegv_r(OP *op, GV *value);
static void cop_seq_r(OP *op, UV value);
static void cop_arybase_r(OP *op, I32 value);
static void cop_line_r(OP *op, U16 value);
static void cop_warnings_r(OP *op, SV *value);
static void cop_io_r(OP *op, SV *value);

COP* mycop(SV* code)
{
    if (code && SvROK(code)) {
        if (SvTYPE(SvRV(code)) == SVt_PVCV) {
            code = SvRV(code);
            return (COP*)CvSTART(code);
        }
        else {
            croak("unknown reference type");
        }
    }
    else {
        int count;

        count = code ? SvIV(code) : 0;
        if (count <= 0) {
            return PL_curcop;
        }
        else {
            return cxstack[cxstack_ix - count + 1].blk_oldcop;
        }
    }
}

char *cop_label(COP *cop, char *value, int set)
{
#ifdef CopLABEL
    return (char *) CopLABEL(cop);
#else
    if (set)
        cop->cop_label = save_pv(value);

    return cop->cop_label ? cop->cop_label : Nullch;
#endif
}

char *cop_stashpv(COP *cop, char *value, int set, int apply_to_all)
{
    if (set) {
        if (apply_to_all) {
            cop_stashpv_r((OP*)cop, value);
        }
        else {
            CopSTASHPV_set(cop, value);
        }
    }

    return CopSTASHPV(cop);
}

HV *cop_stash(COP *cop, HV *value, int set, int apply_to_all)
{
    if (set) {
        if (apply_to_all) {
            cop_stash_r((OP*)cop, value);
        }
        else {
            CopSTASH_set(cop, value);
        }
    }

    return CopSTASH(cop);
}

char *cop_file(COP *cop, char *value, int set, int apply_to_all)
{

    if (set) {
        if (apply_to_all) {
            cop_file_r((OP*)cop, value);
        }
        else {
            CopFILE_set(cop, value);
        }
    }

    return CopFILE(cop);
}

GV *cop_filegv(COP *cop, GV *value, int set, int apply_to_all)
{
    if (set) {
        if (apply_to_all) {
            cop_filegv_r((OP*)cop, value);
        }
        else {
            CopFILEGV_set(cop, value);
        }
    }

    return CopFILEGV(cop);
}

UV cop_seq(COP *cop, UV value, int set, int apply_to_all)
{
    if (set) {
        if (apply_to_all) {
            cop_seq_r((OP*)cop, value);
        }
        else {
            cop->cop_seq = value;
        }
    }

    return cop->cop_seq;
}

I32 cop_arybase(COP *cop, I32 value, int set, int apply_to_all)
{
#ifdef CopARYBASE_get
	return (I32) CopARYBASE_get(cop);
#else
        if (set) {
            if (apply_to_all) {
                cop_arybase_r((OP*)cop, value);
            }
            else {
                cop->cop_arybase = value;
            }
        }

        return cop->cop_arybase;
#endif
}

U16 cop_line(COP *cop, U16 value, int set, int apply_to_all)
{
    if (set) {
        if (apply_to_all) {
            cop_line_r((OP*)cop, value);
        }
        else {
            cop->cop_line = value;
        }
    }

    return cop->cop_line;
}

SV *cop_warnings(COP *cop, SV *value, int set, int apply_to_all)
{
#if PERL_REVISION == 5 && (PERL_VERSION >= 10)
	return &PL_sv_undef;
#else
        if (set) {
            if (apply_to_all) {
                cop_warnings_r((OP*)cop, value);
            }
            else {
                mycop(c)->cop_warnings = newSVsv(value);
            }
        }

	if ( PTR2UV(mycop(c)->cop_warnings) > 255 ) {
	    /* pointer to the lexical SV */
	    return SvREFCNT_inc(cop->cop_warnings);
	}
	else {
	    /* UV of global warnings flags */
	    return newSVuv( PTR2UV(cop->cop_warnings) );
	}
#endif
}

SV *cop_io(COP *cop, SV *value, int set, int apply_to_all)
{
#if PERL_REVISION == 5 && (PERL_VERSION >= 7 && PERL_VERSION < 10)
        if (set) {
            if (apply_to_all) {
                cop_io_r((OP*)cop, value);
            }
            else {
                cop->cop_io = newSVsv(value);
            }
        }

        return cop->cop_io ? SvREFCNT_inc(cop->cop_io) : newSVpvn("", 0);
#else
	return &PL_sv_undef;
#endif
}

APPLY_TO_ALL_FN(stashpv, char*)
APPLY_TO_ALL_FN(stash, HV*)
APPLY_TO_ALL_FN(file, char*)
APPLY_TO_ALL_FN(filegv, GV*)
APPLY_TO_ALL_FN(seq, UV)
APPLY_TO_ALL_FN(arybase, I32)
APPLY_TO_ALL_FN(warnings, SV*)
APPLY_TO_ALL_FN(io, SV*)

/* needs some custom behavior */
static void cop_line_r(OP *op, U16 value)
{
    U16 base_value = cop_line((COP*)op, 0, 0, 0);
    char *base_file = cop_file((COP*)op, NULL, 0, 0);
    do {
        if (op->op_type == OP_NEXTSTATE &&
            !strcmp(base_file, cop_file((COP*)op, NULL, 0, 0))) {
            COP *cop = (COP*)op;
            cop_line(cop, value - base_value + cop_line(cop, 0, 0, 0), 1, 0);
        }
    } while (op = op->op_next);
}

MODULE = Devel::Hints	PACKAGE = Devel::Hints

char *
cop_label(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_label(mycop(code), value, items >= 2);
    OUTPUT:
	RETVAL

char *
cop_stashpv(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_stashpv(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

HV *
cop_stash(code=NULL, value=NULL)
	SV*		code
	HV*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_stash(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

char *
cop_file(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_file(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

GV *
cop_filegv(code=NULL, value=NULL)
	SV*		code
	GV*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_filegv(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

UV
cop_seq(code=NULL, value=0)
	SV*		code
	UV		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_seq(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

I32
cop_arybase(code=NULL, value=0)
	SV*		code
	I32		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_arybase(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

U16
cop_line(code=NULL, value=0)
	SV*		code
	U16		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_line(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

SV *
cop_warnings(code=NULL, value=NULL)
	SV*		code
	SV*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_warnings(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

SV *
cop_io(code=NULL, value=NULL)
	SV*		code
	SV*		value
    CODE:
        if (GIMME_V == G_VOID)
            XSRETURN(0);

        RETVAL = cop_io(mycop(code), value, items >= 2, 1);
    OUTPUT:
	RETVAL

