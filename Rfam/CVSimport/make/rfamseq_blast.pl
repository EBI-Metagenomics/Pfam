#!/usr/local/bin/perl -w

BEGIN {
    $rfam_mod_dir = 
        (defined $ENV{'RFAM_MODULES_DIR'})
            ?$ENV{'RFAM_MODULES_DIR'}:"/pfam/db/Rfam/scripts/Modules";
    $bioperl_dir =
        (defined $ENV{'BIOPERL_DIR'})
            ?$ENV{'BIOPERL_DIR'}:"/pfam/db/bioperl";
}

use lib $rfam_mod_dir;
use lib $bioperl_dir;

use strict;
use Getopt::Long;
use Rfam;
use Bio::Tools::BPlite;
use Bio::Index::Fasta;
use Bio::SeqIO;
use Bio::Tools::Run::StandAloneBlast;
use Bio::SearchIO;
use Bio::SearchIO::Writer::TextResultWriter;

my( $evalue, $division, $minidb, $help, $length, $listhits );
&GetOptions( "e=s"    => \$evalue,
	     "d=s"    => \$division,
	     "h"      => \$help,
	     "w=s"    => \$length,
	     "minidb" => \$minidb,
	     "l"      => \$listhits );

$evalue = 10 if( not $evalue );

my $fafile = shift;

if( $help or not $fafile ) {
    print STDERR <<EOF;

rfamseq_blast.pl: blast a sequence against rfamseq

Usage:   rfamseq_blast.pl <options> <fastafile>
Options:       -h          show this help
               -d <div>    restrict search to EMBL division
               -e <n>      blast evalue threshold
               --minidb    build minidb of all blast hits
	       -w <n>      override sequence length window 

EOF
exit(1);
}

my $blastdbdir = $Rfam::rfamseq_current_dir;
my $inxfile    = $Rfam::rfamseq_current_inx;

my $in = Bio::SeqIO -> new( '-file' => $fafile, '-format' => 'Fasta' );
unless( $length ) {
    $length = $in -> next_seq() -> length();
}

my $seqinx  = Bio::Index::Fasta->new( '-filename'    => $inxfile,
				      '-dbm_package' => 'DB_File' ); 
END { undef $seqinx; }   # stop bizarre seg faults

my $glob;

if( $division ) {
    $glob = "$division*.fa";
}
else {
    $glob = "*.fa";
}


my %hitlist;
foreach my $db ( glob( "$Rfam::rfamseq_current_dir/$glob" ) ) {
    my $factory = Bio::Tools::Run::StandAloneBlast->new( 'program'  => 'blastn',
							 'database' => $db,
							 'F'        => 'F',
							 'W'        => 7,
							 'b'        => 100000,
							 'v'        => 100000,
							 'e'        => $evalue );

    print STDERR "searching $db\n";

    my $seqio = Bio::SeqIO -> new( '-file' => $fafile, '-format' => 'Fasta' );
    while( my $seq = $seqio -> next_seq() ) {
	my $report = $factory->blastall( $seq );
	while( my $result = $report->next_result ) {
	    unless( $listhits or $minidb ) {
		my $writer = new Bio::SearchIO::Writer::TextResultWriter();
		my $out = new Bio::SearchIO( -writer => $writer );
		$out->write_result( $result );
	    }
	    while( my $hit = $result->next_hit() ) {
		while( my $hsp = $hit->next_hsp() ) {
		    push( @{ $hitlist{$hit->name} }, $hsp );
		}
	    }
	}
    }

    foreach my $id ( keys %hitlist ) {
	my @se;
	my @hsplist = sort { $a->start('hit') <=> $b->start('hit') } @{ $hitlist{$id} };
	while( my $hsp = shift @hsplist ) {
	    my( $start, $end ) = ( $hsp->start('hit'), $hsp->end('hit') );
	    $start = $start - $length;
	    $end   = $end   + $length;
	    $start = 1 if( $start < 1 );

	    # Merge overlapping regions - because hsps are sorted by start 
	    # we only need to check if it overlaps with the last one
	    if( scalar(@se) and 
		$start <= $se[ scalar(@se)-1 ]->{'end'} and 
		$end >= $se[ scalar(@se)-1 ]->{'end'} ) {
		
		$se[ scalar(@se)-1 ]->{'end'} = $end;
	    }
	    else {
		push( @se, { 'start' => $start, 'end' => $end } );
	    }
	}

	foreach my $se ( @se ) {
	    if( $listhits ) {
		print "$id ", $se->{'start'}, " ", $se->{'end'}, "\n";
	    }
	    elsif( $minidb ) {
		my $faout = Bio::SeqIO -> new( '-format' => 'Fasta' );
		foreach my $se ( @se ) {
		    my $seq = &get_seq( $id, $se->{'start'}, $se->{'end'} );
		    $faout -> write_seq( $seq );
		}
	    }
	}
    }
}

#########

sub get_seq {
    # fixes start < 1 and end > length
    my $id    = shift;
    my $start = shift;
    my $end   = shift;

    my $seq = new Bio::Seq;
    eval {
        $seq = $seqinx -> fetch( $id );
    };
    if( not $seq or $@ ) {
        warn "$id not found in your seq db\n";
        return 0;       # failure
    }
    my $length = $seq -> length();
    if( $start < 1 ) {
        $start = 1;
    }
    if( $end > $length ) {
        $end = $length;
    }
    my $truncseq = $seq -> trunc( $start, $end );
    $truncseq -> desc( "" );
    $truncseq -> id( "$id/$start-$end" );
    return $truncseq;
}
