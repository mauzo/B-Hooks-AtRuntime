#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

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

MODULE = B::Hooks::AtRuntime  PACKAGE = B::Hooks::AtRuntime

void
lex_stuff (s)
        SV *s
    CODE:
        lex_stuff_sv(s, 0);

UV
count_BEGINs ()
    PREINIT:
        I32 c = 0;
        const PERL_CONTEXT *cx;
        const CV *cxcv;
    CODE:
        RETVAL = 0;
        while (cx = caller_cx(c++, NULL)) {
            if (CxTYPE(cx) == CXt_SUB   &&
                (cxcv = cx->blk_sub.cv) &&
                CvSPECIAL(cxcv)         &&
                strEQ(GvNAME(CvGV(cxcv)), "BEGIN")
            )
                RETVAL++;
        }
    OUTPUT:
        RETVAL
