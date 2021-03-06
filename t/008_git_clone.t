use Test::More tests => 4;
use Test::Exception;
use strict;
use warnings;
use autodie qw/:all/;
use IPC::Cmd qw/can_run/;

use jitterbug;
use jitterbug::Schema;
use lib 't/lib';
use jitterbug::Test;

use JSON;
use YAML qw/LoadFile Dump/;

use File::Spec;
use File::Temp qw/tempdir/;

use Dancer::Test;
use Dancer::Config qw/setting/;
use File::Spec::Functions;
use File::Copy::Recursive qw/dircopy/;
use File::Path qw/rmtree/;

my $hook_data = catfile(qw/t data hook_data.yml/);

my $content = LoadFile($hook_data);

my $db_dir = tempdir( CLEANUP => 1 );
my $db_file = File::Spec->catfile( $db_dir, 'jitterbug.db' );
my $dsn     = 'dbi:SQLite:dbname=' . $db_file;
my $schema  = jitterbug::Schema->connect($dsn);
$schema->deploy;

setting plugins => {
    DBIC => {
        schema => {
            skip_automake => 1,
            pckg          => "jitterbug::Schema",
            connect_info  => [$dsn]
        }
    }
};

rmtree(catfile(qw/t tmp build testing/));

if (can_run('git')){

    my $gitrepo = "t/data/testing";
    dircopy "$gitrepo/._git_", "$gitrepo/.git" unless -e "$gitrepo/.git";

    lives_ok sub { system("$^X -Ilib scripts/post_to_hook.pl") }, 'post_to_hook.pl lives';


    lives_ok sub { $ENV{DEBUG} = 1;
        system("$^X -Ilib scripts/builder.pl -c t/data/test.yml -C")
    }, 'builder.pl lives';

    ok(-e "t/tmp/build/testing/.git", 'found a testing git repo');
    chdir "t/tmp/build/testing";
    chomp( my $sha1 = qx{git rev-parse HEAD} );
    is($sha1,"3ab75b9a29e09bf027f64250b44cab19b316c128", "got expected sha1 in repo");
} else {
    skip "Git not available, skipping tests", 3;
}
