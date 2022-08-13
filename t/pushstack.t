#!/usr/bin/perl

# Issue #2 on Github. This causes an assertion failure on DEBUGGING
# perls, and sometimes a segfault otherwise, but is difficult to test
# more directly than that.

use lib "tlib";

use Test::More;
use t::Util;

BEGIN {
    fakerequire "t/Bar.pm", q{
        package t::Bar;

        use B::Hooks::AtRuntime "after_runtime";

        sub recurse {
            my $depth = shift;
            return if $depth < 0;
            recurse($depth -1);
        }

        sub import {
            after_runtime {
                recurse(20);
            }
        }

        1;
    };

    fakerequire "t/Foo.pm", q{
        package t::Foo;
        use t::Bar;
        1;
    };
    t::Foo->import();

    pass("Recursion imported");
}

pass("Recursion done");
done_testing();


