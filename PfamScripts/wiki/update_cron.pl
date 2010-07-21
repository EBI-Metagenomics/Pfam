#!/usr/bin/perl

# this script updates the "wikipedia_revision" column in the wiki_approve database.
# It checks wikipedia to get the latest revision number for all of the articles 
# in the table. If the retrieved version number is different from the one in the
# table, the row is updated.
#
# jt6 20100420 WTSI
#
# $Id$

use strict;
use warnings;

use Getopt::Long;
use Config::General;
use WikiApprove;
use Bio::Pfam::Wiki::Updater;
use DateTime;

# find the config file
my $config = 'conf/wiki.conf';
GetOptions ( 'config=s' => \$config );
die "ERROR: couldn't read config from '$config': $!" unless -e $config;

# get the DB connection parameters
my $cg = Config::General->new($config);
my %config = $cg->getall;
die "ERROR: failed to extract and configuration from '$config'"
  unless keys %$cg;
my $conf = $config{wiki_approve}{WikiApprove};

# connect to the wiki_approve database
my $dsn = "dbi:mysql:$conf->{db_name}:$conf->{db_host}:$conf->{db_port}";
my $wa = WikiApprove->connect( $dsn, $conf->{username}, $conf->{password} );

# get an Updater and update all entries
my $u = Bio::Pfam::Wiki::Updater->new( schema => $wa );
$u->update_all;

my $checked = $u->num_checked;
my $updated = $u->num_updated;

my $now = DateTime->now;
print STDERR "$now: updated last revision IDs for $updated out of $checked checked articles\n";

