
# SpeciesTree.pm
# jt6 20060410 WTSI
#
# $Id: SpeciesTree.pm,v 1.2 2006-10-31 15:15:09 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Family::SpeciesTree - controller to build the
species tree

=cut

package PfamWeb::Controller::Clan::SpeciesTree;

=head1 DESCRIPTION

Builds a species tree as a series of nested hashes, which is handed
off to a template to be rendered as a clickable HTML tree.

Generates a B<page fragment>.

$Id: SpeciesTree.pm,v 1.2 2006-10-31 15:15:09 jt6 Exp $

=cut

use strict;
use warnings;

use URI::Escape;
use Data::Dump qw( dump );

use base "PfamWeb::Controller::Clan";

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 auto : Private

Generates the tree and adds it to the stash.

=cut

sub auto : Private {
  my( $this, $c ) = @_;

  # retrieve the tree and stash it
  $c->forward( "getTree" );

}

#-------------------------------------------------------------------------------

=head2 renderTree : Path

Captures URLs like C<http://localhost:3000/clan/speciestree?acc=CL0067>

=cut

sub renderTree : Path {
  my( $this, $c ) = @_;

  # point to the template that will generate the javascript that
  # builds the tree in the client
  $c->stash->{template} = "components/blocks/family/renderTree.tt";
}

#-------------------------------------------------------------------------------

=head2 renderSubTree : Path

Renders a tree from the supplied sequence accessions.

=cut

sub renderSubTree : Path( "/clan/speciessubtree" ) {
  my( $this, $c ) = @_;

  $c->log->debug( "acc:  |" . $c->req->param( "acc" ) . "|" );
  $c->log->debug( "seqs: |" . $c->req->param( "seqs" ) . "|" );

  foreach ( split / /, uri_unescape( $c->req->param("seqs") ) ) {
	$c->log->debug( "  id: |$_|" );
  }

}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# retrieve the tree data from the database and recurse over it to
# build a set of nested hashes that represent it

sub getTree : Private {
  my( $this, $c ) = @_;

  #Get the species information for the full alignment for each clan member.  This probably could be done in one query,
  #but this is going to be quicker (I think....)
  my @auto_pfamAs = $c->model("PfamDB::Clan_membership")->search( { "auto_clan" => $c->stash->{clan}->auto_clan});
  my @all_regions;
  foreach my $auto_pfamA (@auto_pfamAs){
    my @regions = $c->model("PfamDB::PfamA_reg_full")->search(
							      { "auto_pfamA" => $auto_pfamA->auto_pfamA,
								"in_full"         => 1 },
							      { join              => [ qw/pfamseq/],
								prefetch          => [ qw/pfamseq/ ],}
							     );
    push(@all_regions, @regions);
  }
  my %tree;
  my $maxDepth = 0;
  foreach my $region ( @all_regions ) {
    my $speciesData = {}; #This probably could be moved out
    #For some reason in the database Taxonomoy is stored up to genus!
    my $tax = $region->taxonomy;
    my $species = $region->species;
    $tax =~ s/\s+//g;
    #Remove ful stop from the end of the species line. Dodgy......I know
    chop($species);
    #As the species has a leading white space.....
    $species =~ s/^(\s+)//g;
    my @tax = split(/\;/, $tax);

	$maxDepth = scalar @tax	if scalar @tax > $maxDepth;

    $tax[$#tax] = $species;
    $$speciesData{'acc'} = $region->pfamseq_acc;
    $$speciesData{'species'} = $species;
    $$speciesData{'tax'} = \@tax;
    &addBranch(\%tree, $speciesData);
  }
  $tree{maxTreeDepth} = $maxDepth;

  $c->stash->{rawTree} = \%tree;
}

#-------------------------------------------------------------------------------
# recursive subroutine to construct a node in the tree

sub addBranch {
  my ($treeRef, $branchRef) = @_;
  my $node = shift @{$$branchRef{'tax'}};
  if($node){
    $treeRef->{branches}->{$node}->{frequency}++; # count the number of regions
    $treeRef->{branches}->{$node}->{sequences}->{$$branchRef{'acc'}}++; #count the number of unique sequences
    $treeRef->{branches}->{$node}->{species}->{$$branchRef{'species'}}++; #count the number of unique species
    if($node eq $$branchRef{'species'}){
      $treeRef->{branches}->{$node}->{inSeed}++ if($$branchRef{'inSeed'});
    }
    addBranch($treeRef->{branches}->{$node}, $branchRef);
  }
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
