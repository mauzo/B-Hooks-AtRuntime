package Devel::AtRuntime;

use warnings;
use strict;

use XSLoader;
use Exporter        "import";
use Sub::Name       "subname";

our $VERSION = "1";
XSLoader::load __PACKAGE__, $VERSION;

our @EXPORT = "at_runtime";

my $Hooks;

sub clear {
    # By deleting the stash entry we ensure the only ref to the glob is
    # through the optree it was compiled into. This means that if that
    # optree is ever freed, the glob will disappear along with @hooks
    # and anything closed over by the user's callbacks.
    delete $Devel::AtRuntime::{run};
    $Hooks = undef;
}

sub at_runtime (&) {
    my ($cv) = @_;

    unless ($Hooks) {
        # Close over an array of callbacks so we don't need to keep
        # stuffing text into the buffer.
        $Hooks = \my @hooks;

        # This must be a symref, so we get a fresh glob each time.
        my $gv = do { no strict "refs"; \*{"run"} };
        *$gv = subname "run", sub { $_->() for @hooks };

        lex_stuff("Devel::AtRuntime::run();" .
            "BEGIN{Devel::AtRuntime::clear()}");
    }

    push @$Hooks, $cv;
}

1;
