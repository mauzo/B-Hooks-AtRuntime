#!/usr/bin/perl

use warnings;
use strict;
use lib "tlib";

use Test::More;
use Test::Exception;
use Test::Warn;

use B::Hooks::AtRuntime;

BEGIN {
    package DB;
    no strict;

    sub sub { &$sub; }
}
BEGIN { $^P |= 0x1 }

# Use a fresh lexical each time, just to make sure tests don't interfere
# with each other.

{
    my @record;
    push @record, 1;
    BEGIN { at_runtime { push @record, 2 } }
    push @record, 3;

    is_deeply \@record, [1..3], "at_runtime works with DB::sub";
}

done_testing;
