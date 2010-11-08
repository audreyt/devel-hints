#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#define SET(x)		if (items >= 2) x
#define GET(x)		if (GIMME_V == G_VOID) XSRETURN(0); RETVAL = x
#define MEMBER(c,m)	SET( mycop(c)->m = value ); \
			GET( mycop(c)->m );
#define MEMBER_PV(c,m)	SET( mycop(c)->m = savepv(value) ); \
			GET( mycop(c)->m ? mycop(c)->m : Nullch );
#define MEMBER_SV(c,m)	SET( mycop(c)->m = newSVsv(value)); \
			GET( mycop(c)->m ? SvREFCNT_inc(mycop(c)->m) : newSVpvn("", 0) );
#define ACCESSOR(c,s,g)	SET( s(mycop(c), value) ); \
			GET( g(mycop(c)) );

#ifndef CopFILEGV_set
#define CopFILEGV_set(c, gv) ;; /* noop */
#endif

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

MODULE = Devel::Hints	PACKAGE = Devel::Hints

char *
cop_label(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
#ifdef CopLABEL
	if (GIMME_V == G_VOID) XSRETURN(0); RETVAL = (char *) CopLABEL(mycop(code));
#else
	MEMBER_PV( code, cop_label );
#endif
    OUTPUT:
	RETVAL

char *
cop_stashpv(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
	ACCESSOR( code, CopSTASHPV_set, CopSTASHPV );
    OUTPUT:
	RETVAL

HV *
cop_stash(code=NULL, value=NULL)
	SV*		code
	HV*		value
    CODE:
	ACCESSOR( code, CopSTASH_set, CopSTASH );
    OUTPUT:
	RETVAL

char *
cop_file(code=NULL, value=NULL)
	SV*		code
	char*		value
    CODE:
	ACCESSOR( code, CopFILE_set, CopFILE );
    OUTPUT:
	RETVAL

GV *
cop_filegv(code=NULL, value=NULL)
	SV*		code
	GV*		value
    CODE:
	ACCESSOR( code, CopFILEGV_set, CopFILEGV );
    OUTPUT:
	RETVAL

UV
cop_seq(code=NULL, value=0)
	SV*		code
	UV		value
    CODE:
	MEMBER( code, cop_seq );
    OUTPUT:
	RETVAL

I32
cop_arybase(code=NULL, value=0)
	SV*		code
	I32		value
    CODE:
#ifdef CopARYBASE_get
	if (GIMME_V == G_VOID) XSRETURN(0); RETVAL = (I32) CopARYBASE_get(mycop(code));
#else
	MEMBER( code, cop_arybase );
#endif
    OUTPUT:
	RETVAL

U16
cop_line(code=NULL, value=0)
	SV*		code
	U16		value
    CODE:
	MEMBER( code, cop_line );
    OUTPUT:
	RETVAL

SV *
cop_warnings(code=NULL, value=NULL)
	SV*		code
	SV*		value
    CODE:
#if PERL_REVISION == 5 && (PERL_VERSION >= 10)
	RETVAL = &PL_sv_undef;
#else
	SET( mycop(c)->cop_warnings = newSVsv(value));
	if ( PTR2UV(mycop(c)->cop_warnings) > 255 ) {
	    /* pointer to the lexical SV */
	    RETVAL = SvREFCNT_inc(mycop(c)->cop_warnings);
	}
	else {
	    /* UV of global warnings flags */
	    RETVAL = newSVuv( PTR2UV(mycop(c)->cop_warnings) );
	}
#endif
    OUTPUT:
	RETVAL

SV *
cop_io(code=NULL, value=NULL)
	SV*		code
	SV*		value
    CODE:
#if PERL_REVISION == 5 && (PERL_VERSION >= 7 && PERL_VERSION < 10)
	MEMBER_SV( code, cop_io );
#else
	RETVAL = &PL_sv_undef;
#endif
    OUTPUT:
	RETVAL

