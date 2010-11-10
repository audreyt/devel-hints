#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "ptable.h"

#ifndef CopFILEGV_set
#define CopFILEGV_set(c, gv) ;; /* noop */
#endif
#ifndef CopARYBASE_get
#define CopARYBASE_get(c) c->cop_arybase
#endif
#ifndef CopARYBASE_set
#define CopARYBASE_set(c,v) c->cop_arybase = v
#endif

#if PERL_REVISION == 5 && (PERL_VERSION >= 10)
#define DH_PMOP_STASHSTARTU(o) o->op_pmstashstartu.op_pmreplstart
#else
#define DH_PMOP_STASHSTARTU(o) o->op_pmreplstart
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

typedef void (*walk_optree_cb_t)(OP*);

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
/* XXX: should cop_seq be incremented, like cop_line is? */
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

static void _walk_optree(OP *o, walk_optree_cb_t cb, ptable *visited)
{
    for (; o; o = o->op_next) {
        if (ptable_fetch(visited, o))
            return;

        ptable_store(visited, o, o);

        cb(o);

        switch (PL_opargs[o->op_type] & OA_CLASS_MASK) {
        case OA_LOGOP:
            _walk_optree(cLOGOPo->op_other, cb, visited);
            break;
        case OA_LOOP:
            _walk_optree(cLOOPo->op_redoop, cb, visited);
            _walk_optree(cLOOPo->op_nextop, cb, visited);
            _walk_optree(cLOOPo->op_lastop, cb, visited);
            break;
        case OA_PMOP:
            if (o->op_type == OP_SUBST)
                _walk_optree(DH_PMOP_STASHSTARTU(cPMOPo), cb, visited);
            break;
        }
    }
}

void walk_optree(OP *o, walk_optree_cb_t cb)
{
    ptable *visited = ptable_new();
    _walk_optree(o, cb, visited);
    ptable_free(visited);
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
            walk_optree((OP*)cop, cop_stashpv_r);
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
            walk_optree((OP*)cop, cop_stash_r);
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
            walk_optree((OP*)cop, cop_file_r);
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
            walk_optree((OP*)cop, cop_filegv_r);
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
            walk_optree((OP*)cop, cop_seq_r);
        }
        else {
            cop->cop_seq = value;
        }
    }

    return cop->cop_seq;
}

I32 cop_arybase(COP *cop, I32 value, int set, int apply_to_all)
{
        if (set) {
            if (apply_to_all) {
                arybase_value = value;
                walk_optree((OP*)cop, cop_arybase_r);
            }
            else {
                CopARYBASE_set(cop, value);
            }
        }

        return CopARYBASE_get(cop);
}

U16 cop_line(COP *cop, U16 value, int set, int apply_to_all)
{
    if (set) {
        if (apply_to_all) {
            line_value = value;
            line_base_value = cop_line(cop, 0, 0, 0);
            line_base_file = cop_file(cop, NULL, 0, 0);
            walk_optree((OP*)cop, cop_line_r);
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
                walk_optree((OP*)cop, cop_warnings_r);
            }
            else {
                cop->cop_warnings = newSVsv(value);
            }
        }

	if ( PTR2UV(cop->cop_warnings) > 255 ) {
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
                walk_optree((OP*)cop, cop_io_r);
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

