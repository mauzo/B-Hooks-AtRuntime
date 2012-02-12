package B::Hooks::AtRuntime;

use warnings;
use strict;

use XSLoader;
use Exporter        "import";
use Sub::Name       "subname";
use Carp;

BEGIN {
    our $VERSION = "1";
    XSLoader::load __PACKAGE__, $VERSION;
}

our @EXPORT = "at_runtime";
our @EXPORT_OK = qw/at_runtime lex_stuff/;

use constant USE_FILTER =>
    defined $ENV{PERL_B_HOOKS_ATRUNTIME} 
        ? $ENV{PERL_B_HOOKS_ATRUNTIME} eq "filter"
        : not defined &lex_stuff;

if (USE_FILTER) {
    require Filter::Util::Call;

    # This isn't an exact replacement: it inserts the text at the start
    # of the next line, rather than immediately after the current BEGIN.
    #
    # In theory I could use B::Hooks::Parser, which aims to emulate
    # lex_stuff on older perls, but that uses a source filter to ensure
    # PL_linebuf has some extra space in it (since it can't be
    # reallocated without adjusting pointers we can't get to). This
    # means BHP::setup needs to be called at least one source line
    # before we want to insert any text (so the filter has a chance to
    # run), which makes it precisely useless for our purposes :(.

    no warnings "redefine";
    *lex_stuff = subname "lex_stuff", sub {
        my ($str) = @_;

        compiling_string_eval() and croak 
            "Can't stuff into a string eval";

        if (defined(my $extra = remaining_text())) {
            $extra =~ s/\n+\z//;
            carp "Extra text '$extra' after call to lex_stuff";
        }

        Filter::Util::Call::filter_add(sub {
            $_ = $str;
            Filter::Util::Call::filter_del();
            return 1;
        });
    };
}

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
    
    USE_FILTER and compiling_string_eval() and croak
        "Can't use at_runtime from a string eval";

    my $depth = count_BEGINs()
        or croak "You must call at_runtime at compile time";
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
