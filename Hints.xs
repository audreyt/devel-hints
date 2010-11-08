#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#define SET(x)		if (items >= 2) x
#define GET(x)		if (GIMME_V == G_VOID) XSRETURN(0); RETVAL = x
#define MEMBER(m)	SET( MYCOP->m = value ); \
			GET( MYCOP->m );
#define MEMBER_PV(m)	SET( MYCOP->m = savepv(value) ); \
			GET( MYCOP->m ? MYCOP->m : Nullch );
#define MEMBER_SV(m)	SET( MYCOP->m = newSVsv(value)); \
			GET( MYCOP->m ? SvREFCNT_inc(MYCOP->m) : newSVpvn("", 0) );
#define ACCESSOR(s,g)	SET( s(MYCOP, value) ); \
			GET( g(MYCOP) );
#define MYCOP		((count <= 0) ? PL_curcop \
			    : cxstack[cxstack_ix - count + 1 ].blk_oldcop)

#ifndef CopFILEGV_set
#define CopFILEGV_set(c, gv) ;; /* noop */
#endif

MODULE = Devel::Hints	PACKAGE = Devel::Hints

char *
cop_label(count=0, value=NULL)
	I32		count
	char*		value
    CODE:
#ifdef CopLABEL
	if (GIMME_V == G_VOID) XSRETURN(0); RETVAL = (char *) CopLABEL(MYCOP);
#else
	MEMBER_PV( cop_label );
#endif
    OUTPUT:
	RETVAL

char *
cop_stashpv(count=0, value=NULL)
	I32		count
	char*		value
    CODE:
	ACCESSOR( CopSTASHPV_set, CopSTASHPV );
    OUTPUT:
	RETVAL

HV *
cop_stash(count=0, value=NULL)
	I32		count
	HV*		value
    CODE:
	ACCESSOR( CopSTASH_set, CopSTASH );
    OUTPUT:
	RETVAL

char *
cop_file(count=0, value=NULL)
	I32		count
	char*		value
    CODE:
	ACCESSOR( CopFILE_set, CopFILE );
    OUTPUT:
	RETVAL

GV *
cop_filegv(count=0, value=NULL)
	I32		count
	GV*		value
    CODE:
	ACCESSOR( CopFILEGV_set, CopFILEGV );
    OUTPUT:
	RETVAL

UV
cop_seq(count=0, value=0)
	I32		count
	UV		value
    CODE:
	MEMBER( cop_seq );
    OUTPUT:
	RETVAL

I32
cop_arybase(count=0, value=0)
	I32		count
	I32		value
    CODE:
#ifdef CopARYBASE_get
	if (GIMME_V == G_VOID) XSRETURN(0); RETVAL = (I32) CopARYBASE_get(MYCOP);
#else
	MEMBER( cop_arybase );
#endif
    OUTPUT:
	RETVAL

U16
cop_line(count=0, value=0)
	I32		count
	U16		value
    CODE:
	MEMBER( cop_line );
    OUTPUT:
	RETVAL

SV *
cop_warnings(count=0, value=NULL)
	I32		count
	SV*		value
    CODE:
#if PERL_REVISION == 5 && (PERL_VERSION >= 10)
	RETVAL = &PL_sv_undef;
#else
	SET( MYCOP->cop_warnings = newSVsv(value));
	if ( PTR2UV(MYCOP->cop_warnings) > 255 ) {
	    /* pointer to the lexical SV */
	    RETVAL = SvREFCNT_inc(MYCOP->cop_warnings);
	}
	else {
	    /* UV of global warnings flags */
	    RETVAL = newSVuv( PTR2UV(MYCOP->cop_warnings) );
	}
#endif
    OUTPUT:
	RETVAL

SV *
cop_io(count=0, value=NULL)
	I32		count
	SV*		value
    CODE:
#if PERL_REVISION == 5 && (PERL_VERSION >= 7 && PERL_VERSION < 10)
	MEMBER_SV( cop_io );
#else
	RETVAL = &PL_sv_undef;
#endif
    OUTPUT:
	RETVAL

