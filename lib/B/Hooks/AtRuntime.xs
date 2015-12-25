#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define NEED_PL_parser
#define DPPP_PL_parser_NO_DUMMY
#include "ppport.h"

#ifndef caller_cx
#define caller_cx(c, p)         MY_caller_cx(aTHX_ c, p)

/* Since we're only looking for BEGINs, we can skip most of the
 * subtleties of the real caller_cx and not worry about returning a
 * whole lot of extra frames that aren't subs.
 */
static const PERL_CONTEXT *
MY_caller_cx(pTHX_ I32 count, const PERL_CONTEXT **dbcxp)
{
    register I32 cxix = cxstack_ix;
    register const PERL_CONTEXT *ccstack = cxstack;
    const PERL_SI *top_si = PL_curstackinfo;

    for (;;) {
	/* we may be in a higher stacklevel, so dig down deeper */
	while (cxix < 0 && top_si->si_type != PERLSI_MAIN) {
	    top_si = top_si->si_prev;
	    ccstack = top_si->si_cxstack;
	    cxix = top_si->si_cxix;
	}
	if (cxix < 0)
	    return NULL;
	if (!count--)
	    break;
	cxix = cxix - 1;
    }

    return &ccstack[cxix];
}

#endif

void
call_after (pTHX_ void *p)
{
    dSP;
    SV  *cv = (SV*)p;

    PUSHMARK(SP);
    call_sv(cv, G_VOID|G_DISCARD);
    SvREFCNT_dec(cv);
}

MODULE = B::Hooks::AtRuntime  PACKAGE = B::Hooks::AtRuntime

#ifdef lex_stuff_sv

void
lex_stuff (s)
        SV *s
    CODE:
        if (!PL_parser)
            Perl_croak(aTHX_ "Not currently compiling anything");
        lex_stuff_sv(s, 0);

#endif

UV
count_BEGINs ()
    PREINIT:
        I32 c = 0;
        const PERL_CONTEXT *cx;
        const CV *cxcv;
    CODE:
        RETVAL = 0;
        while ((cx = caller_cx(c++, NULL))) {
            if (CxTYPE(cx) == CXt_SUB   &&
                (cxcv = cx->blk_sub.cv) &&
                CvSPECIAL(cxcv)         &&
                strEQ(GvNAME(CvGV(cxcv)), "BEGIN")
            )
                RETVAL++;
        }
    OUTPUT:
        RETVAL

bool
compiling_string_eval ()
    PREINIT:
        I32 c = 0;
        const PERL_CONTEXT *cx;
        const CV *cxcv;
    CODE:
        RETVAL = 0;
        while ((cx = caller_cx(c++, NULL))) {
            if (CxTYPE(cx) == CXt_SUB   &&
                (cxcv = cx->blk_sub.cv) &&
                CvSPECIAL(cxcv)         &&
                strEQ(GvNAME(CvGV(cxcv)), "BEGIN")
            ) {
                cx = caller_cx(c + 1, NULL);
                if (cx && CxREALEVAL(cx))
                    RETVAL = 1;
                break;
            }
        }
    OUTPUT:
        RETVAL

SV *
remaining_text ()
    PREINIT:
        char *c;
    CODE:
        RETVAL = &PL_sv_undef;
        if (PL_parser) {
            for (c = PL_bufptr; c < PL_bufend; c++) {
                if (isSPACE(*c))    continue;
                if (*c == '#')      break;
                /* strictly it might be UTF8, but this is just an error so I
                 * don't care. */
                RETVAL = newSVpvn(c, PL_bufend - c);
                break;
            }
        }
    OUTPUT:
        RETVAL

void
run (...)
    PREINIT:
        dORIGMARK;
        SV      *sv;
        I32     i = 0;
    CODE:
        LEAVE; /* hmm hmm hmm */

        while (i++ < items) {
            sv = *(MARK + i);

            if (!SvROK(sv))
                Perl_croak(aTHX_ "Not a reference");
            sv = SvRV(sv);

            if (SvROK(sv)) {
                sv = SvRV(sv);
                SvREFCNT_inc(sv);
                SAVEDESTRUCTOR_X(call_after, sv);
            }
            else {
                PUSHMARK(SP); PUTBACK;
                call_sv(sv, G_VOID|G_DISCARD);
                MSPAGAIN;

            }
        }

        ENTER;
