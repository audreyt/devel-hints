#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#ifndef CopFILEGV_set
#define CopFILEGV_set(c, gv) ;; /* noop */
#endif

#define CALL_IMPL(m)                                      \
    if (GIMME_V == G_VOID)                                \
        XSRETURN(0);                                      \
    RETVAL = cop_ ## m(mycop(code), value, items >= 2, 1)

#define WALK_OPTREE_CB(m,t)                    \
    static t m ## _value;                      \
    static void cop_ ## m ## _r(OP *op)        \
    {                                          \
        if (op->op_type == OP_NEXTSTATE) {     \
            COP *cop = (COP*)op;               \
            cop_ ## m(cop, m ## _value, 1, 0); \
        }                                      \
    }

char *cop_stashpv(COP *cop, char *value, int set, int apply_to_all);
HV *cop_stash(COP *cop, HV *value, int set, int apply_to_all);
char *cop_file(COP *cop, char *value, int set, int apply_to_all);
GV *cop_filegv(COP *cop, GV *value, int set, int apply_to_all);
UV cop_seq(COP *cop, UV value, int set, int apply_to_all);
I32 cop_arybase(COP *cop, I32 value, int set, int apply_to_all);
U16 cop_line(COP *cop, U16 value, int set, int apply_to_all);
SV *cop_warnings(COP *cop, SV *value, int set, int apply_to_all);
SV *cop_io(COP *cop, SV *value, int set, int apply_to_all);

WALK_OPTREE_CB(stashpv, char*)
WALK_OPTREE_CB(stash, HV*)
WALK_OPTREE_CB(file, char*)
WALK_OPTREE_CB(filegv, GV*)
WALK_OPTREE_CB(seq, UV)
WALK_OPTREE_CB(arybase, I32)
WALK_OPTREE_CB(warnings, SV*)
WALK_OPTREE_CB(io, SV*)

/* needs some custom behavior */
static U16 line_value;
static U16 line_base_value;
static char *line_base_file;
static void cop_line_r(OP *op)
{
    if (op->op_type == OP_NEXTSTATE &&
        !strcmp(line_base_file, cop_file((COP*)op, NULL, 0, 0))) {
        COP *cop = (COP*)op;
        cop_line(cop, line_value - line_base_value + cop_line(cop, 0, 0, 0),
                 1, 0);
    }
}

static int initial_state;
static void (*walk_optree_r)(OP*);

static void _walk_optree(OP *o)
{
    for (; o; o = o->op_next) {
        if (o->op_opt != initial_state)
            break;
        o->op_opt = !initial_state;

        walk_optree_r(o);

        switch (PL_opargs[o->op_type] & OA_CLASS_MASK) {
        case OA_LOGOP:
            _walk_optree(cLOGOPo->op_other);
            break;
        case OA_LOOP:
            _walk_optree(cLOOPo->op_redoop);
            _walk_optree(cLOOPo->op_nextop);
            _walk_optree(cLOOPo->op_lastop);
            break;
        case OA_PMOP:
            if (o->op_type == OP_SUBST)
                _walk_optree(cPMOPo->op_pmstashstartu.op_pmreplstart);
            break;
        }
    }
}

void walk_optree(OP *o)
{
    initial_state = o->op_opt;
    _walk_optree(o);
}

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

char *cop_label(COP *cop, char *value, int set, int apply_to_all)
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
            stashpv_value = value;
            walk_optree_r = cop_stashpv_r;
            walk_optree((OP*)cop);
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
            stash_value = value;
            walk_optree_r = cop_stash_r;
            walk_optree((OP*)cop);
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
            file_value = value;
            walk_optree_r = cop_file_r;
            walk_optree((OP*)cop);
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
            filegv_value = value;
            walk_optree_r = cop_filegv_r;
            walk_optree((OP*)cop);
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
            seq_value = value;
            walk_optree_r = cop_seq_r;
            walk_optree((OP*)cop);
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
                arybase_value = value;
                walk_optree_r = cop_arybase_r;
                walk_optree((OP*)cop);
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
            line_value = value;
            line_base_value = cop_line(cop, 0, 0, 0);
            line_base_file = cop_file(cop, NULL, 0, 0);
            walk_optree_r = cop_line_r;
            walk_optree((OP*)cop);
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
                warnings_value = value;
                walk_optree_r = cop_warnings_r;
                walk_optree((OP*)cop);
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
                io_value = value;
                walk_optree_r = cop_io_r;
                walk_optree((OP*)cop);
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

MODULE = Devel::Hints	PACKAGE = Devel::Hints

char *
cop_label(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
        if (items >= 2 && SvROK(code))
            croak("Can't set the label of a coderef");
        CALL_IMPL(label);
    OUTPUT:
	RETVAL

char *
cop_stashpv(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
        CALL_IMPL(stashpv);
    OUTPUT:
	RETVAL

HV *
cop_stash(code=NULL, value=NULL)
	SV*		code
	HV*		value
    CODE:
        CALL_IMPL(stash);
    OUTPUT:
	RETVAL

char *
cop_file(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
        CALL_IMPL(file);
    OUTPUT:
	RETVAL

GV *
cop_filegv(code=NULL, value=NULL)
	SV*		code
	GV*		value
    CODE:
        CALL_IMPL(filegv);
    OUTPUT:
	RETVAL

UV
cop_seq(code=NULL, value=0)
	SV*		code
	UV		value
    CODE:
        CALL_IMPL(seq);
    OUTPUT:
	RETVAL

I32
cop_arybase(code=NULL, value=0)
	SV*		code
	I32		value
    CODE:
        CALL_IMPL(arybase);
    OUTPUT:
	RETVAL

U16
cop_line(code=NULL, value=0)
	SV*		code
	U16		value
    CODE:
        CALL_IMPL(line);
    OUTPUT:
	RETVAL

SV *
cop_warnings(code=NULL, value=NULL)
	SV*		code
	SV*		value
    CODE:
        CALL_IMPL(warnings);
    OUTPUT:
	RETVAL

SV *
cop_io(code=NULL, value=NULL)
	SV*		code
	SV*		value
    CODE:
        CALL_IMPL(io);
    OUTPUT:
	RETVAL

