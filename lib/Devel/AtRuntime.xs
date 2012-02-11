#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

MODULE = Devel::AtRuntime  PACKAGE = Devel::AtRuntime

void
lex_stuff (s)
        SV *s
    CODE:
        lex_stuff_sv(s, 0);
