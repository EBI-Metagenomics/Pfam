
# NCBISeq.pm
# jt6 20071010 WTSI
#
# $Id: NCBISeq.pm,v 1.4 2009-01-09 12:59:24 jt6 Exp $

=head1 NAME

PfamWeb::Controller::NCBISeq - controller to build pages for sequences with
NCBI identifiers

=cut

package PfamWeb::Controller::NCBISeq;

=head1 DESCRIPTION

Generates a B<tabbed page>.

$Id: NCBISeq.pm,v 1.4 2009-01-09 12:59:24 jt6 Exp $

=cut

use strict;
use warnings;

use Bio::Pfam::PfamRegion;
use Bio::Pfam::AnnSeqFactory;
use Bio::SeqFeature::Generic;
use Bio::Pfam::OtherRegion;
use Bio::Pfam::SeqPfam;
use Bio::Pfam::Drawing::Layout::PfamLayoutManager;
#use Bio::Pfam::Drawing::Image::ImageSet;
#use Bio::Pfam::Drawing::Image::Image;

use Data::Dump qw( dump );

use base 'PfamWeb::Controller::Section';

__PACKAGE__->config( SECTION => 'ncbiseq' );

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 begin : Private

Get the data from the database for the entry.

=cut

sub begin : Private {
  my ( $this, $c, $entry_arg ) = @_;

  # decide what format to emit. The default is HTML, in which case
  # we don't set a template here, but just let the "end" method on
  # the Section controller take care of us
  if ( defined $c->req->param('output') and
       $c->req->param('output') eq 'xml' ) {
    $c->stash->{output_xml} = 1;
    $c->res->content_type('text/xml');    
  }
  
  # get a handle on the entry and detaint it
  my $tainted_entry = $c->req->param('acc')   ||
                      $c->req->param('gi')    ||
                      $c->req->param('entry') ||
                      $entry_arg              ||
                      '';

  # although these next checks might fail and end up putting an error message
  # into the stash, we don't "return", because we might want to process the 
  # error message using a template that returns XML rather than simply HTML
  # (XML output not yet implemented for metaseq data
  # jt6 20080603 WTSI.)
  
  my $entry;
  if ( $tainted_entry ) {
    ( $entry ) = $tainted_entry =~ m/^([\w\.-]+)$/;
    $c->stash->{errorMsg} = 'Invalid ncbiseq accession or ID' 
      unless defined $entry;
  }
  else {
    $c->stash->{errorMsg} = 'No ncbiseq accession or ID specified';
  }

  # retrieve data for this entry
  $c->forward( 'get_data', [ $entry ] ) if defined $entry;
}

#-------------------------------------------------------------------------------
#- private actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 action : Attribute

Description...

=cut

sub get_data : Private {
  my ( $this, $c, $entry ) = @_;
  
  my $rs = $c->model('PfamDB::Ncbi_seq')
             ->search( [ { gi            => $entry }, 
                         { secondary_acc => $entry } ] );

  my $ncbiseq = $rs->first if defined $rs;
  
  unless ( defined $ncbiseq ) {
    $c->stash->{errorMsg} = 'No valid ncbiseq accession or ID';
    return;
  }
  
  $c->log->debug( 'Ncbiseq::get_data: got a ncbiseq entry' ) if $c->debug;
  $c->stash->{ncbiseq} = $ncbiseq;
  $c->stash->{acc}     = $ncbiseq->gi;
  
  # only add extra data to the stash if we're actually going to use it later
  if ( not $c->stash->{output_xml} and 
       ref $this eq 'PfamWeb::Controller::Ncbiseq' ) {
    
    $c->log->debug( 'Ncbiseq::get_data: adding extra ncbiseq info' )
      if $c->debug;
    
    $c->forward('generatePfamGraphic');
    $c->forward('getSummaryData');
  }
  
}

#-------------------------------------------------------------------------------

=head2 generatePfamGraphic : Private

Generates the Pfam graphic.

=cut

sub generatePfamGraphic : Private {
  my( $this, $c ) = @_;
  
  my $factory = new Bio::Pfam::AnnSeqFactory;
  my $annseq  = $factory->createAnnotatedSequence();
  
  my %args = (
    '-seq'   => $c->stash->{ncbiseq}->sequence,
    '-start' => 1,
    '-end'   => $c->stash->{ncbiseq}->length,
    '-id'    => $c->stash->{ncbiseq}->gi,
    '-acc'   => $c->stash->{ncbiseq}->secondary_acc,
    '-desc'  => $c->stash->{ncbiseq}->description
  );
  $c->log->debug( 'NCBISeq::generatePfamGraphic: annseq args: ', dump \%args )
    if $c->debug;

  $annseq->sequence( Bio::Pfam::SeqPfam->new( %args ) );
  
  my @rs = $c->model('PfamDB::Ncbi_pfama_reg')
             ->search( { gi      => $c->stash->{ncbiseq}->gi,
                         in_full => 1 },
                       { join     => [ 'pfamA' ],
                         prefetch => [ 'pfamA' ] } );

  foreach my $row ( @rs ) {
    %args = (
      '-PFAM_ACCESSION' => $row->pfamA_acc,
      '-PFAM_ID'        => $row->pfamA_id,
      '-SEQ_ID'         => $annseq->id,
      '-FROM'           => $row->seq_start,
      '-TO'             => $row->seq_end,
      '-MODEL_FROM'     => $row->model_start,
      '-MODEL_TO'       => $row->model_end,
      '-MODEL_LENGTH'   => $row->model_length,
      '-BITS'           => $row->domain_bits_score,
      '-EVALUE'         => $row->domain_evalue_score,
      '-TYPE'           => 'PfamA',
      '-REGION'         => $row->type
    );
    $annseq->addAnnotatedRegion( Bio::Pfam::PfamRegion->new( %args ) );
  }
  
  # build a layout manager
  my $layout = Bio::Pfam::Drawing::Layout::PfamLayoutManager->new;
  $layout->layout_sequences( $annseq );
  
   # if we've arrived here from the top-level controller, rather than from one 
  # of the sub-classes, we will be displaying a key for the domain graphic.
  # For now at least, the sub-classes, such as the interactive feature viewer,
  # don't bother with the key, so they don't need this extra blob of data in 
  # the stash. 
  $c->forward( 'generateKey', [ $layout ] )
    if ref $this eq 'PfamWeb::Controller::NCBISeq';
  
  # and use it to create an ImageSet

  # should we use a document store rather than temp space for the images ?
  my $imageset;  
  if ( $c->config->{use_image_store} ) {
    $c->log->debug( 'NCBISeq::generatePfamGraphic: using document store for image' )
      if $c->debug;
    require PfamWeb::ImageSet;
    $imageset = PfamWeb::ImageSet->new;
  }
  else {
    $c->log->debug( 'NCBISeq::generatePfamGraphic: using temporary directory for store image' )
      if $c->debug;
    require Bio::Pfam::Drawing::Image::ImageSet;
    $imageset = Bio::Pfam::Drawing::Image::ImageSet->new;
  }

  $imageset->create_images( $layout->layout_to_XMLDOM );
 
  $c->stash->{imageset} = $imageset;
}

#-------------------------------------------------------------------------------

=head2 generateKey : Private

Generates a data structure representing the key to the domain image, which 
can be formatted sensibly by the view.

=cut

sub generateKey : Private {
  my( $this, $c, $lm ) = @_;
  
  # retrieve a hash of BioPerl objects indexed on sequence ID
  my %hash = $lm->seqHash;

  # pull out the sequence object for just the sequence that we're dealing with
  # (there should be only that one anyway) 
  my $seq = $hash{ $c->stash->{ncbiseq}->gi };

  # and get the raw key data from that
  my %key = $seq->getKey;

  # from this point on we're mimicking old, crufty code...
  
  # sort the rows according to the start position of the domain
  my @rows;
  foreach my $row ( sort{$key{$a}{start} <=> $key{$b}{start} } keys %key ) {

    # shouldn't they always be a number ?
    next unless $key{$row}{start} =~ /^\d+$/;
   
    # just store the hash for this row and we're done here; let the view
    # figure out what to render 
    push @rows, $key{$row};
  }
  
  $c->stash->{imageKey} = \@rows;
}

#-------------------------------------------------------------------------------

=head2 getSummaryData : Private

Gets the data items for the overview bar

=cut

sub getSummaryData : Private {
  my ( $this, $c ) = @_;

  my %summaryData;

  # first, the number of sequences... pretty easy...
  $summaryData{numSequences} = 1;

  # also, the number of architectures
  $summaryData{numArchitectures} = 1;

  # number of species
  $summaryData{numSpecies} = 0;

  # number of structures
  $summaryData{numStructures} = 0;

  # number of interactions
  $summaryData{numInt} = 0;

  $c->stash->{summaryData} = \%summaryData;

  $c->log->debug('NCBISeq::getSummaryData: added the summary data to the stash')
    if $c->debug;
}

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

Rob Finn, C<rdf@sanger.ac.uk>

Andy Jenkinson, C<aj5@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2007: Genome Research Ltd.

Authors: Rob Finn (rdf@sanger.ac.uk), John Tate (jt6@sanger.ac.uk)

This is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.

=cut

1;
