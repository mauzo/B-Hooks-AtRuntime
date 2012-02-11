package B::Hooks::AtRuntime;

use warnings;
use strict;

use XSLoader;
use Exporter        "import";
use Sub::Name       "subname";

our $VERSION = "1";
XSLoader::load __PACKAGE__, $VERSION;

our @EXPORT = "at_runtime";
our @EXPORT_OK = qw/at_runtime lex_stuff/;

my $Hooks;

sub clear {
    # By deleting the stash entry we ensure the only ref to the glob is
    # through the optree it was compiled into. This means that if that
    # optree is ever freed, the glob will disappear along with @hooks
    # and anything closed over by the user's callbacks.
    delete $B::Hooks::AtRuntime::{run};
    $Hooks = undef;
}

sub at_runtime (&) {
    my ($cv) = @_;

    unless ($Hooks) {
        # This must be a symref, so we get a fresh glob each time.
        my $gv = do { no strict "refs"; \*{"run"} };

        # Close over an array of callbacks so we don't need to keep
        # stuffing text into the buffer.
        $Hooks = \my @hooks;
        *$gv = subname "run", sub { $_->() for @hooks };

        # This must be all on one line, so we don't mess up perl's idea
        # of the current line number.
        lex_stuff("B::Hooks::AtRuntime::run();" .
            "BEGIN{B::Hooks::AtRuntime::clear()}");
    }

    push @$Hooks, $cv;
}

1;
