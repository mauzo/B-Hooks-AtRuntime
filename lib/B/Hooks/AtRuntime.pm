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

my @Hooks;

sub replace_run {
    my ($new) = @_;
    local $" = "][";
    warn "REPLACE [@{$new || []}]\n";

    # By deleting the stash entry we ensure the only ref to the glob is
    # through the optree it was compiled into. This means that if that
    # optree is ever freed, the glob will disappear along with @hooks
    # and anything closed over by the user's callbacks.
    delete $B::Hooks::AtRuntime::{run};

    no strict "refs";
    $new and *{"run"} = $new->[1];
}

sub clear {
    my ($depth) = @_;
    local $" = "][";
    no warnings "uninitialized";
    warn "CLEAR: [$depth] [@{$Hooks[$depth] || []}]\n";
    $Hooks[$depth] = undef;
    replace_run $Hooks[$depth - 1];
}

sub at_runtime (&) {
    my ($cv) = @_;

    local $" = "][";

    my $depth = count_BEGINs();
    warn "DEPTH: [$depth]\n";

    my $hk;
    unless ($hk = $Hooks[$depth]) {
        # Close over an array of callbacks so we don't need to keep
        # stuffing text into the buffer.
        my @hooks;
        $hk = $Hooks[$depth] = [ 
            \@hooks, 
            subname "run", sub { $_->() for @hooks } 
        ];
        warn "ALLOC: [@{$hk}]\n";
        replace_run $hk;

        # This must be all on one line, so we don't mess up perl's idea
        # of the current line number.
        lex_stuff("B::Hooks::AtRuntime::run();" .
            "BEGIN{B::Hooks::AtRuntime::clear($depth)}");
    }

    warn "PUSH: [@$hk]\n";
    push @{$$hk[0]}, $cv;
}

1;
