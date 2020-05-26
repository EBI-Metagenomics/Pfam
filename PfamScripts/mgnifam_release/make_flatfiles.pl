#!/usr/bin/env perl

use strict;
use warnings;
use Text::Wrap;
use Bio::Pfam::Config;
use Bio::Pfam::PfamLiveDBManager;

#Get database connection
my $config = Bio::Pfam::Config->new;
my $pfamDB = Bio::Pfam::PfamLiveDBManager->new( %{ $config->pfamliveAdmin } );
my $dbh = $pfamDB->getSchema->storage->dbh;

unless($pfamDB->{database} eq "mgnifam") {
  die "Need to use the config for mgnifam\n";
}


#Get all the mgnifams, order by id
my @mgnifams = $pfamDB->getSchema->resultset('Mgnifam')->search( {}, { order_by => 'mgnifam_id' });


#Make the HMM flatfile
my $hmm_file = "MGnifam.hmm";
print STDERR "Making $hmm_file\n";
open(HMM, ">$hmm_file") or die "Couldn't open fh tp $hmm_file, $!";
foreach my $mgnifam (@mgnifams) {
  my $hmm = $pfamDB->getSchema->resultset('MgnifamHmm')->find({ mgnifam_acc => $mgnifam->mgnifam_acc });
  print HMM $hmm->hmm;
}
close HMM;


#Make hmm.dat file
my $hmm_dat_file="MGnifam.hmm.dat";
print STDERR "Making $hmm_dat_file file\n";
open(HMMDAT, ">$hmm_dat_file") or die "Couldn't open fh to $hmm_dat_file file, $!";
foreach my $mgnifam (@mgnifams) {
  print HMMDAT "# STOCKHOLM 1.0\n";
  print HMMDAT "#=GF ID   " . $mgnifam->mgnifam_id . "\n";
  print HMMDAT "#=GF AC   " . $mgnifam->mgnifam_acc . "\n";
  print HMMDAT "#=GF DE   " . $mgnifam->description . "\n";
  print HMMDAT "#=GF GA   " . $mgnifam->sequence_ga . "; " . $mgnifam->domain_ga . ";\n";
  print HMMDAT "#=GF TP   " . $mgnifam->type . "\n";
  print HMMDAT "#=GF ML   " . $mgnifam->model_length . "\n";
  print HMMDAT "//\n";
}
close(HMMDAT);


#Make the SEED flatfile
print STDERR "Making seed flatfile\n";
my $seed_file = "MGnifam.seed";
open(SEED, ">$seed_file") or die "Couldn't open fh tp $seed_file, $!";
foreach my $mgnifam (@mgnifams) {
  print SEED "# STOCKHOLM 1.0\n";
  print SEED "ID   ".$mgnifam->mgnifam_id."\n";
  print SEED "AC   ".$mgnifam->mgnifam_acc."\n";
  print SEED "DE   ".$mgnifam->description."\n";
  my @authors = split(/, /, $mgnifam->author);
  foreach my $author (@authors) { 
    print SEED "AU   $author".";\n";
  }    
  print SEED "SE   ".$mgnifam->seed_source."\n";
  print SEED "GA   ".$mgnifam->sequence_ga." ".$mgnifam->domain_ga.";\n";
  print SEED "TC   ".$mgnifam->sequence_tc." ".$mgnifam->domain_tc.";\n";
  print SEED "NC   ".$mgnifam->sequence_nc." ".$mgnifam->domain_nc.";\n";
  print SEED "BM   ".$mgnifam->buildmethod."\n";
  print SEED "SM   ".$mgnifam->searchmethod."\n";
  print SEED "TP   ".$mgnifam->type."\n";
  if($mgnifam->comment) {
    $Text::Wrap::columns = 75;
    print SEED wrap('CC   ', 'CC   ', $mgnifam->comment);
  }
  print SEED "SQ   ".$mgnifam->num_seed."\n";

  my $seed = $pfamDB->getSchema->resultset('MgnifamSeed')->find({ mgnifam_acc => $mgnifam->mgnifam_acc });
  print SEED $seed->seed;
  print SEED "//\n";
}
close SEED;