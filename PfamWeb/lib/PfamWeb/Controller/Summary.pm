
# Summary.pm
# jt6 20060316 WTSI
#
# Controller to build the main Pfam family page. Still a test-bed of
# sorts.
#
# $Id: Summary.pm,v 1.4 2006-03-24 11:37:06 jt6 Exp $

package PfamWeb::Controller::Summary;

use strict;
use warnings;
use base "Catalyst::Controller";


# pick up a URL like http://localhost:3000/summary/PF00067

sub getacc : LocalRegex( '^(PF\d{5})' ) {
  my( $this, $c ) = @_;

  my $acc = $c->req->snippets->[0];
  $c->stash->{pfam} = PfamWeb::Model::Pfam->find( { pfamA_acc => $acc } );

  $c->stash->{template} = "pages/error.tt"
	unless defined $c->stash->{pfam};

  #$c->log->info( "getacc: Pfam object: |", $c->stash->{pfam}, "|" );
}


# pick up URLs like
#   http://localhost:3000/summary?acc=PF00067
# or
#   http://localhost:3000/summary?id=p450

sub default : Private {
  my( $this, $c ) = @_;

#   if( defined $c->session->{layout} ) {
# 	$c->stash->{layout} = $c->session->{layout};
# 	$c->log->debug( "added layout object to stash" );
#   }

  if( defined $c->req->param("acc") ) {

	$c->req->param("acc") =~ m/^(PF\d{5})$/;
	$c->log->info( "found accession |$1|" );

	$c->stash->{pfam} = PfamWeb::Model::Pfam->find( { pfamA_acc => $1 } )
	  if defined $1;

  } elsif( defined $c->req->param("id") ) {

	$c->req->param("id") =~ m/(^\w+$)/;
	$c->log->info( "found ID |$1|" );

	$c->stash->{pfam} = PfamWeb::Model::Pfam->find( { pfamA_id => $1 } )
	  if defined $1;

  }

  $c->stash->{template} = "pages/error.tt"
	unless defined $c->stash->{pfam};

  $c->log->info( "default: Pfam object: |", $c->stash->{pfam}, "|" );

}


# hand off to TT to render the page. Default to "view.tt", which is
# the standard summary page right now. If actions have had problems,
# they'll have switched to point to "error.tt"

sub end : Private {
  my( $this, $c ) = @_;

  # see if a view was specified
  my $view;
  if( $c->req->param( "view" ) ) {
	( $view = $c->req->param( "view" ) ) =~ s/^([A-Za-z_]+).*$/$1/;

	# set the view
	$c->stash->{template} ||= "pages/" . $this->{views}->{$view}
  }

  # pick a tab
  if( $c->req->param( "tab" ) ) {
	$c->req->param( "tab" ) =~ /^([A-Za-z]+).*$/;
	$c->stash->{selectedTab} = $1;
  }

  # add domain architectures to the stash
  my @seqs_acc;
  my $acc = $c->stash->{pfam}->pfamA_acc;
  foreach my $arch ( PfamWeb::Model::PfamA_architecture->search( {'pfamA_acc' => $acc },
																 { join       => [qw/ arch pfam/],
																   order_by   =>"arch.no_seqs DESC" }
															   )
				   ) {
	push @seqs_acc, $arch->pfamseq_acc;
  }

  my $layout = Bio::Pfam::Drawing::Layout::PfamLayoutManager->new;
  $layout->scale_x("0.2"); #0.33
  $layout->scale_y("0.5"); #0.45

  #my %order = map{$_ => 1 }$layout->region_order;
  my %order = ( "pfama" => 1);

  my $seqs = PfamWeb::Model::GetBioObjects::getAnnseq( \@seqs_acc, \%order );

  $layout->layout_sequences( @$seqs );

  my $imageset = Bio::Pfam::Drawing::Image::ImageSet->new;
  $imageset->create_images($layout->layout_to_XMLDOM);

  $c->stash->{images} = $imageset;

  # make sure there's a template defined ultimately
  $c->stash->{template} ||= "pages/" . $this->{views}->{default};

  # and use it
  $c->forward( "PfamWeb::View::TT" );
}

1;
