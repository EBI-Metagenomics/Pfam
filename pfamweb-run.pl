#!/use/bin/perl

use strict;
use warnings;
use Env qw(@PERL5LIB @PATH $PFAMWEB_CONFIG);
use Cwd;
use FindBin qw($Bin $Script $RealBin $RealScript);
use File::Spec;
use File::Basename;
use Config::General;
use Data::Printer;

our @PERL5LIB;
our @PATH;
my @LIBS = qw(PfamWeb Rfam Rfam/Schemata PfamSchemata PfamBackend PfamScripts Bio-Easel WikiApp PfamTests PfamConfig PfamLib PfamBase PfamBase/lib);

my ($pfamConfigFile, $port) = (@ARGV);
my $pfamExe = "PfamWeb/script/pfamweb_server.pl";

unless (defined $port) {
    $port = 8000;
}

foreach my $lib (@LIBS) {
    push(@PERL5LIB, $lib);
}

$pfamConfigFile = $PFAMWEB_CONFIG if (defined $PFAMWEB_CONFIG && !defined $pfamConfigFile);
if (defined $pfamConfigFile && -f $pfamConfigFile) {
    open(IN, "<$pfamConfigFile") or die ("Failed to open config file: $!");
    my ($name, $path, $suffix) = fileparse($pfamConfigFile, ".conf");
    my $newConfigFile = File::Spec->join($Bin, $path . "$name"."_autogen$suffix");
    if (! -e File::Spec->join($Bin, "$path$name.$suffix")) {
      $newConfigFile = File::Spec->join($path . "$name"."_autogen$suffix");
    }
    open(OUT, ">", "$newConfigFile") or die ("Failed to create new config file '$newConfigFile': $!");

    my $baseRootPath = File::Spec->join($Bin, "PfamBase", "root");
    die ("Failed to find $baseRootPath") unless (-e $baseRootPath);
    my $webRootPath = File::Spec->join($Bin, "PfamWeb", "root");
    die ("Failed to find $webRootPath") unless (-e $webRootPath);
    my $configRootPath = File::Spec->join($Bin, "PfamConfig", "PfamWeb");
    die ("Failed to find $configRootPath") unless (-e $configRootPath);

    while(<IN>) {
        my $line = $_;
        if ($line =~ /^l4p_config/i) {
          $line =~ s/.*?l4p\.conf/l4p_config $configRootPath\/l4p.conf/;
        } elsif ($line =~ /PfamBase/i) {
            $line =~ s/include_path.*?PfamBase.*?$/include_path $baseRootPath/;
            $line =~ s/INCLUDE_PATH.*?PfamBase.*?$/INCLUDE_PATH "$baseRootPath"/;
        } elsif ($line =~ /PfamWeb/i) {
            $line =~ s/include_path.*?PfamWeb.*?$/include_path $webRootPath/;
            $line =~ s/INCLUDE_PATH.*?PfamWeb.*?$/INCLUDE_PATH "$webRootPath"/;
        }
        print OUT $line;
    }
    close(IN);
    close(OUT);

    die("Failed to create new config file $newConfigFile") unless (-e $newConfigFile);
    #$PFAMWEB_CONFIG = $pfamConfigFile;
    $PFAMWEB_CONFIG = $newConfigFile;
    print "Running using $name$suffix in $path\n";
}
die ("Either set PFAMWEB_CONFIG environment variable or provide path to Pfam web config file") unless (defined $PFAMWEB_CONFIG);

my $targetDir = File::Spec->join($Bin, "PfamBase", "root", "static");
my $linkDir = File::Spec->join($Bin, "PfamWeb", "root", "shared");
unless (-e $linkDir && -l $linkDir) {
    my $linkCreated = eval {symlink($targetDir, $linkDir); 1};
    die ("Failed to create link $linkDir") unless ($linkCreated);
}

$ENV{CATALYST_DEBUG} = 1;
#$ENV{DBIC_TRACE} = 1;
system("perl $pfamExe -p $port --follow_symlink");
