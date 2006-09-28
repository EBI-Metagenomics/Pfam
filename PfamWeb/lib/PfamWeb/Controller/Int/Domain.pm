# Domain.pm
# rdf 20060818 WTSI
#
# Controller to build the main Domain page.
#
# $Id: Domain.pm,v 1.2 2006-09-28 09:40:09 rdf Exp $

package PfamWeb::Controller::Int::Domain;

use strict;
use warnings;
use Data::Dumper;

use base "Catalyst::Controller";

#-------------------------------------------------------------------------------
# pick up http://localhost:3000/int

sub generateDomainIntSum : Path {
  my( $this, $c ) = @_;

  $c->log->debug("Int::Domain::generateDomainIntSum: Hello");


  if( defined $c->req->param("acc") ) {
    $c->req->param("acc") =~ m/^(PF\d{5})$/i;
    $c->stash->{pfam} = $c->model("PfamDB::Pfam")->find( { pfamA_acc => $1 } );
  }elsif(defined $c->req->param("id") ) {

  }elsif(defined $c->req->param("entry") ) {

  }
  if($c->stash->{pfam}->pfamA_id){
    # Now that we have a pfam domain
    my @rs = $c->model("PfamDB::Int_pfamAs")->search({ auto_pfamA_A => $c->stash->{pfam}->auto_pfamA },
						     { join     => [qw/pfamA_B/],
						       prefetch => [qw/pfamA_B/]});
    if(scalar(@rs)){
      $c->stash->{domainInts} = \@rs;
      my $noSeqs = $c->model("PfamDB::Interactions")->find({ auto_pfamA_A => $c->stash->{pfam}->auto_pfamA },
							   { select => { count => {distinct => "auto_pfamseq_A" }},
							     as     => [qw/noSeqs/] });
      $c->stash->{noSeqs} = $noSeqs->get_column("noSeqs");
      my $noStruc = $c->model("PfamDB::Interactions")->find({ auto_pfamA_A => $c->stash->{pfam}->auto_pfamA },
								{ select => { count => {distinct => "auto_pdb" }},
								  as     => [qw/noStrucs/] });
      
      my %summaryData;
      $summaryData{numSpecies} = 0;
      $summaryData{numArchitectures} = 0;
      $summaryData{numStructures}  = $noSeqs->get_column("noSeqs");
      $summaryData{numSequences}   = $noStruc->get_column("noStrucs");
      $summaryData{numInt}         = scalar(@rs);
      $c->stash->{summaryData} = \%summaryData;
      
      $c->log->debug("Get ".$noSeqs->get_column("noSeqs")." sequences");
      $c->log->debug("Found ".scalar(@{$c->stash->{domainInts}})." domain interactions");
      $c->log->debug("Int::Domain::generateDomainIntSum: Got domain data for:");
    }else{
      $c->stash->{noiPfam} = 1;
    }
  }else{
    $c->stash->{noPfam} = 1;
  }

}

#-------------------------------------------------------------------------------
sub end : Private {
  my( $this, $c ) = @_;

  # don't try to render a page unless there's a Pfam object in the stash
  #return 0 unless defined $c->stash->{ligand};

  # check for errors
  if ( scalar @{ $c->error } ) {
        $c->stash->{errors}   = $c->error;
        $c->stash->{template} = "components/blocks/ipfam/errors.tt";
  } else {
        $c->log->debug("PfamWeb::Controller::Int::Domain - Handing off to layout");
        $c->stash->{pageType} = "iDomain";
        $c->stash->{template} ||= "pages/layout.tt";
  }

  # and render the page
  $c->forward( "PfamWeb::View::TT" );

  # clear any errors
  $c->error(0);

}
1;

