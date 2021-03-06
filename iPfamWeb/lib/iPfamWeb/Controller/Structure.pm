
# Structure.pm
# jt6 20060706 WTSI
#
# $Id: Structure.pm,v 1.4 2009-12-01 10:49:46 pg6 Exp $

=head1 NAME

PfamWeb::Controller::Structure - controller for structure-related
sections of the site

=cut

package iPfamWeb::Controller::Structure;

=head1 DESCRIPTION

This is intended to be the base class for everything related to 3-D
structure across the site. The L<begin|/"begin : Private"> method will
try to extract a PDB ID from the captured URL and then try to load a
Pdb object from the model into the stash.

This is also the controller that handles the structure section of the
site, so it includes an action to capture a URL like

=over

=item http://localhost:3000/structure?id=1abc

=back

Generates a B<tabbed page>.

$Id: Structure.pm,v 1.4 2009-12-01 10:49:46 pg6 Exp $

=cut

use strict;
use warnings;

use Data::Dumper;
use GraphViz;

use base 'iPfamWeb::Controller::Section';

__PACKAGE__->config( SECTION => 'structure' );

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 begin : Private

Tries to extract a PDB ID from the URL and gets the row in the Pdb table
for that entry. Accepts various formats of URL:

=over

=item * http://localhost:3000/structure/I<..>?id=1abc

=item * http://localhost:3000/structure/I<..>?entry=1abc

=item * http://localhost:3000/structure/I<..>/1abc

=item * http://localhost:3000/structure/I<..>/1abc.pdb

=back

=cut

sub begin : Private {
  my( $this, $c, @pdbIdArgs ) = @_;

  # get the accession or ID code
  my $pdbId;
  if( defined $c->req->param('id') ) {
    $c->log->debug( 'Structure::begin: found param "id"; checking...' );

    $c->req->param('id') =~ m/^([0-9][A-Z0-9]{3})$/i;
    $pdbId = $1 if defined $1;
  
  } elsif( defined $c->req->param('entry') ) {
    $c->log->debug( 'Structure::begin: found param "entry"; checking...' );

    $c->req->param('entry') =~ m/^([0-9][A-Z0-9]{3})$/i;
    $pdbId = $1 if defined $1;

  } elsif( scalar @pdbIdArgs ) {

    # this is a real hack... need to figure out how to get hold of the last
    # argument to the URL without this...
    my $pdbIdArg = $pdbIdArgs[-1];

    $c->log->debug( "Structure::begin: found an argument ($pdbIdArg); checking..." );
    $pdbIdArg =~ /(\d\w{3})/;
    $pdbId = $1 if defined $1;

  }

   my $pdb = $c->model('iPfamDB::Pdb')
              ->search( { pdb_id => $pdbId } )
              ->single;
#   my $pdb = $c->model('iPfamDB::Pdb')
#              ->find( { pdb_id => $pdbId } );

  # we're done here unless there's an entry specified
  unless( defined $pdb ) {

    # see if this was an internal link and, if so, report it
    my $b = $c->req->base;
    if( defined $c->req->referer and $c->req->referer =~ /^$b/ ) {
  
      # report the error as a broken internal link
      $c->error( q|Found a broken internal link; no valid PDB ID |
                 . qq|("$pdbId") in "| . $c->req->referer . q|"| );
      $c->forward( '/reportError' );
  
      $c->clear_errors;
    }
  
    $c->stash->{errorMsg} = 'No valid PDB ID';
  
    # log a warning and we're done; drop out to the end method which
    # will put up the standard error page
    $c->log->warn( "Structure::begin: couldn't retrieve data for PDB ID |$pdbId|" );
  
    return;
  }

  $c->log->debug( "Structure::begin: successfully retrieved pdb object for |$pdbId|" );

  # stash the PDB object and ID
  $c->stash->{pdb}   = $pdb;
  $c->stash->{pdbId} = $pdbId;

  # get the icon summary data, but only if we're in this top-level class, 
  # i.e. the one that generates the structure page rather than the sub-classes
  # that build page components
  if( ref $this eq 'iPfamWeb::Controller::Structure' ) {
    #$c->forward( 'getSummaryData' );
    $c->forward( 'getAuthors' );
    $c->forward( 'getSummaryImage' );
  }
  
  # add the mapping between structure, sequence and family. We need this for 
  # more or less all of the sub-classes, so always do this
  $c->forward( 'addMapping' );

}

#-------------------------------------------------------------------------------
#- private actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 getSummaryData : Private

Gets the data items for the overview bar

=cut

sub getSummaryData : Private {
  my( $this, $c ) = @_;
 
  $c->log->debug( "Structure::getSummaryData: Getting summary data for pdb" );
  my $summaryData;

  my $acc = $c->stash->{pdb}->accession;

  # number of sequences in the structure - count the number of chains.
  my $rs = $c->model('iPfamDB::PdbResidueData')
             ->find( { accession => $acc },
                     { select   => [
                                     {
                                       count => [ { distinct => [ 'chain' ] } ]
                                     }
                                   ],
                       as       => [ qw( numChains ) ] } );
  $summaryData->{numSequences} = $rs->get_column( 'numChains' );

#  # number of species should be one, but get the species for the sequences
#  $rs = $c->model('PfamDB::Pdb_residue')
#          ->find( { auto_pdb => $autoPdb },
#                  { join     => [ qw( pfamseq )],
#                    select   => [
#                                  {
#                                    count => [ { distinct => [ 'pfamseq.species' ] } ]
#                                  }
#                                ],
#                    as       => [ qw( numSpecies ) ] } );
#  $summaryData{numSpecies} = $rs->get_column( 'numSpecies' );
#
#  # number architectures
#  $rs = $c->model('PfamDB::Pdb_residue')
#          ->find( { auto_pdb => $autoPdb },
#                  { join     => [ qw( pfamseq )],
#                    select   => [
#                                  {
#                                   count => [ { distinct => [ 'pfamseq.auto_architecture' ] } ]
#                                  }
#                                ],
#                    as       => [ qw( numArch ) ] } );
#  $summaryData{numArchitectures} = $rs->get_column( 'numArch' );

  # number of interactions.
  #$rs = $c->model('PfamDB::Interactions')
  #        ->find( { auto_pdb => $autoPdb },
  #                { select   => [
  #                                {
  #                                  count => [ { distinct => [ 'auto_int_pfamAs' ] } ]
  #                                }
  #                              ],
  #                  as       => [ qw( numInts ) ] } );
  #$summaryData{numInt} = $rs->get_column( 'numInts' );
  #$summaryData{numInt} = 0;
  # number of structures is one
  
 
  $summaryData->{domInt} = 4;
  $summaryData->{ligInt} = 1;
  $summaryData->{naInt}  = 0;
  $summaryData->{numStructures} = 1;
  $c->stash->{summaryData} = $summaryData;
  
}
#-------------------------------------------------------------------------------
=head2 getAuthors : Private

Add the list of authors to the stash.

=cut

sub getSummaryImage : Private {
  my($this, $c) = @_;
  
  #Make a new image object
  my $g = GraphViz->new(	no_overlap => 1,
					  		rankdir => 1,
					  		bgcolor => 'white'
					  		);
  $g->add_node( "Domain A",
                cluster => "ChainA",
                style => "filled",
                color => "red",
                URL   => "http://pfam.sanger.ac.uk");
  $g->add_node( "Domain B",
                cluster => "ChainA",
                style => "filled",
                color => "green");
  $g->add_node( "Domain C",
                cluster => "ChainB",
                style => "filled",
                color => "blue");
                
  $g->add_edge("Domain A" => "Domain B",
				 			  style => 'bold',
			 			    color => 'grey',
			 			    dir => 'none');
	
	$g->add_node("DNA",
				 			  style => 'filled',
				 			  shape => 'diamond',
			 			    color => 'black',
			 			    URL => '\N');
  $g->add_node("RNA",
				 			  style => 'filled',
				 			  shape => 'diamond',
			 			    color => 'grey',
			 			    URL => '\N'); 
			 			     
	$g->add_node("Small ligand",
				 			  style => 'filled',
				 			  shape => 'box',
			 			    color => 'yellow',
			 			    URL => '\N');

  $g->add_edge("Domain A" => "Domain C", style => "dashed", dir => 'both', URL => "http://localhost:8001/catalyst/ipfam");
  $g->add_edge("Domain B" => "Domain C", style => "filled", dir => 'both');
  $c->stash->{summaryImage} = "domainInt.png"; 
  
  $g->as_png($ENV{IPFAM_DOMAIN_IMAGES}."/domainInt.png");
  $c->stash->{summaryImageMap} = $g->as_cmapx();
}



#-------------------------------------------------------------------------------

=head2 getAuthors : Private

Add the list of authors to the stash.

=cut

sub getAuthors : Private {
  my( $this, $c ) = @_;

  # get the authors list
  my @authors = $c->model('iPfamDB::PdbAuthor')
                  ->search( { accession => $c->stash->{pdb}->accession },
                            { order_by => 'author_order ASC' } );

  $c->stash->{authors} = \@authors;
}

#-------------------------------------------------------------------------------

=head2 addMapping : Private

Adds the structure-to-UniProt mapping to the stash.

=cut

sub addMapping : Private {
  my( $this, $c ) = @_;

  $c->log->debug( 'Structure::addMapping: adding mappings for PDB entry '
          . $c->stash->{pdb}->pdb_id );

  # add the structure-to-UniProt mapping to the stash
  my @unpMap = $c->model('iPfamDB::PdbChainData')
                 ->search( { pdb_id  => $c->stash->{ pdbId } },
                           { order_by    => 'original_chain ASC' } );

  $c->log->debug( 'Structure::addMapping: found ' . scalar @unpMap . ' mappings' );
  
  $c->stash->{mapping} = \@unpMap;

  # build a little data structure to map PDB chains to uniprot IDs and
  # then cache that for the post-loaded graphics component
  my( %chains, $chain );
  foreach my $row ( @unpMap ) {
    $chain = ( defined $row->original_chain ) ? $row->original_chain : ' ';
    # N.B. Need to think more about the consequences of setting null
    # chain ID to " "...
  
    $chains{internal_chain_id}->{$chain} = '';
  }
  $c->stash->{chainsMapping} = \%chains;

} 

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

Rob Finn, C<rdf@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2007: Genome Research Ltd.

Authors: Rob Finn (rdf@sanger.ac.uk), John Tate (jt6@sanger.ac.uk)

This is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
or see the on-line version at http://www.gnu.org/copyleft/gpl.txt

=cut

1;
