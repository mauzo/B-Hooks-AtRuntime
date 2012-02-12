use Module::Build;

Module::Build->new(
    module_name         => "B::Hooks::AtRuntime",
    license             => "bsd",

    include_dirs        => ".",

    configure_requires  => {
        "Module::Build"     => "0.38",
    },
    build_requires      => {
        "Test::More"        => "0.65",
    },
    requires            => {
        perl                => "5.012",
        "Sub::Name"         => "0.05",
    },

    meta_merge          => {
        resources => {
            repository => "http://github.com/mauzo/B-Hooks-AtRuntime",
            bugtracker => "https://rt.cpan.org/Public/Dist/" .
                "Display.html?Name=B-Hooks-AtRuntime",
        },
    },
)->create_build_script;
