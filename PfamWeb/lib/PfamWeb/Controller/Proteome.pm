
# Proteome.pm
# rdf 20060821 WTSI
#
# Controller to build the main Pfam Proteome page.
#
# $Id: Proteome.pm,v 1.4 2007-03-05 13:23:34 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Proteome- controller for the proteome section

=cut

package PfamWeb::Controller::Proteome;

=head1 DESCRIPTION

This is intended to be the base class for everything related to clans
across the site. The L<begin|/"begin : Private"> method will try to
extract a clan ID or accession from the captured URL and then try to
load a Clan object from the model into the stash.

Generates a B<tabbed page>.

$Id: Proteome.pm,v 1.4 2007-03-05 13:23:34 jt6 Exp $

=cut

use strict;
use warnings;

use base "PfamWeb::Controller::Section";

# set the name of the section
__PACKAGE__->config( SECTION => "proteome" );

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 begin : Private

Tries to extract an NCBI code from the parameters and retrieves the appropriate
row for it.

=cut

sub begin : Private {
  my( $this, $c ) = @_;

  if( defined $c->req->param( "ncbiCode" ) ) {

    my ($ncbiCode) = $c->req->param( "ncbiCode" ) =~ m/^(\d+)$/i;
    $c->log->info( "Proteome::begin: found ncbiCode |$ncbiCode|" );

    $c->stash->{proteomeSpecies} = $c->model("PfamDB::Genome_species")->find( { ncbi_code => $ncbiCode});

    $c->forward( "_getSummaryData" );
  }
}


#-------------------------------------------------------------------------------

=head2 begin : Private

Just gets the data items for the overview bar.

=cut

sub _getSummaryData : Private {
  my( $this, $c ) = @_;

  my %summaryData;
  #select distinct auto_architecture from pfamseq where ncbi_code=62977 and genome_seq=1;
  my $rs = $c->model("PfamDB::Pfamseq")->find({ ncbi_code  => $c->stash->{proteomeSpecies}->ncbi_code,
						genome_seq => 1},
					      { select => [
							   { count => [
								       { distinct => [ "auto_architecture" ] }
								      ]
							   }
							  ],
						as => [ qw/numArch/ ]
					      });
  $summaryData{numArchitectures} = $rs->get_column( "numArch" );;

  # number of sequences in proteome.
  $summaryData{numSequences} = $c->stash->{proteomeSpecies}->total_genome_proteins;


  # number of structures known for the domain
  #Release 21.0 need something like this
  
  #select distinct auto_pdb from pdb_pfamA_reg a, pfamseq s where s.auto_pfamseq=a.auto_pfamseq and ncbi_code=62977 and genome_seq=1;
  $rs = $c->model("PfamDB::Pdb_pfamA_reg")->find({ "pfamseq.ncbi_code"  => $c->stash->{proteomeSpecies}->ncbi_code,
						   "pfamseq.genome_seq" => 1},
						 { select => [
							      { count => [
									  { distinct => [ "auto_pdb" ] }
									 ]
							      }
							     ],
						   as => [ qw/numPdb/ ],
						   join => [qw/pfamseq/],
						 });
   $summaryData{numStructures}  = $rs->get_column( "numPdb" );

  # number of species
  #AS we are dealing with a proteome, this is 1
  $summaryData{numSpecies} = 1;
  # number of interactions - For now set to zero
  $summaryData{numInt} = 0;
  $c->stash->{summaryData} = \%summaryData;

}

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

Rob Finn, C<rdf@sanger.ac.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

