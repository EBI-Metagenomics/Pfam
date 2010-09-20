
# Tree.pm
# jt6 20060511 WTSI
#
# $Id: Tree.pm,v 1.18 2009-06-09 15:20:00 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Family::Tree;

Controller to build the tree view of the family.

=cut

package PfamWeb::Controller::Family::Tree;

=head1 DESCRIPTION

Uses treefam drawing code to generate images of the tree for
a given family.

$Id: Tree.pm,v 1.18 2009-06-09 15:20:00 jt6 Exp $

=cut

use strict;
use warnings;

use Compress::Zlib;

use treefam::nhx_plot;

use base 'PfamWeb::Controller::Family';

#-------------------------------------------------------------------------------
#- exposed actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 showTree : Path

Plots the tree that we loaded in "auto" and hands off to a template that
builds HTML for the image and associated image map.

=cut

sub showTree : Path {
  my( $this, $c ) = @_;

  # stash the tree object
  $c->forward( 'getTree' );
  
  # bail unless we actually got a tree
  unless ( defined $c->stash->{tree} ) {
    $c->res->status( 204 );
    return;
  }

  # populate the tree nodes with the areas for the image map
  $c->stash->{tree}->plot_core;

  # set up the TT view
  $c->stash->{template} = 'components/blocks/family/treeMap.tt';

  # cache the page (fragment) for one week
  #$c->cache_page( 604800 );
}

#-------------------------------------------------------------------------------

=head2 image : Local

If we successfully generated a tree image, returns it directly as
an "image/gif". Otherwise returns a blank image.

=cut

sub image : Local {
  my( $this, $c ) = @_;

  # stash the tree object
  $c->forward( 'getTree' );

  if ( defined $c->stash->{tree} ) {
    $c->res->content_type( 'image/gif' );
    $c->res->body( $c->stash->{tree}->plot_core( 1 )->gif );
  }
    else {
    # TODO this is bad. We should avoid hard-coding a path to an image here
    $c->res->redirect( $c->uri_for( '/shared/images/blank.gif' ) ) if $c->debug;
  }

}

#-------------------------------------------------------------------------------

=head2 download : Local

Serves the raw tree data as a downloadable file.

=cut

sub download : Local {
  my( $this, $c ) = @_;

  $c->log->debug( 'Family::Tree::download: dumping tree data to the response' )
    if $c->debug;

  # stash the raw tree data
  $c->forward( 'getTreeData' );

  return unless defined $c->stash->{treeData};

  my $filename = $c->stash->{acc} . '_' . $c->stash->{alnType} . '.nhx';

  $c->log->debug( "Family::Tree::download: tree filename: |$filename|" )
    if $c->debug;

  $c->res->content_type( 'text/plain' );
  $c->res->header( 'Content-disposition' => "attachment; filename=$filename" );
  $c->res->body( $c->stash->{treeData} );
}

#-------------------------------------------------------------------------------
#- private actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 getTree : Private

Builds the TreeFam tree object for the specified family and alignment type 
(seed or full). We first check the cache for the pre-built tree object and 
then fall back to the database if it's not already available in the cache.

=cut

sub getTree : Private {
  my( $this, $c) = @_;

  # see if we can extract the pre-built tree object from cache
  my $cacheKey = 'tree' . $c->stash->{acc} . $c->stash->{alnType};
  my $tree     = $c->cache->get( $cacheKey );
  
  if ( defined $tree ) {
    $c->log->debug( 'Family::Tree::getTree: extracted tree from cache' )
      if $c->debug;  
  }
  else {
    $c->log->debug( 'Family::Tree::getTree: failed to extract tree from cache; going to DB' )
      if $c->debug;  

    # get a new tree object...
    $tree = treefam::nhx_plot->new( -width => 600,
                                    -skip  => 14 );

    # retrieve the tree from the DB
    $c->forward( 'getTreeData' );
    return unless defined $c->stash->{treeData};
  
    # parse the data
    eval {
      $tree->parse( $c->stash->{treeData} );
    };
    if( $@ ) {
      $c->log->error( 'Family::Tree::getTree: ERROR: failed to parse ' 
                      . $c->stash->{alnType} . ' tree for ' 
                      . $c->stash->{acc} . ": $@" );
      return;
    }

    # and now cache the populated tree object
    $c->cache->set( $cacheKey, $tree ) unless $ENV{NO_CACHE};
  }
  
  $c->stash->{tree} = $tree;
}

#-------------------------------------------------------------------------------

=head2 getTreeData : Private

Retrieves the raw tree data. We first check the cache and then fall back to the 
database.

=cut

sub getTreeData : Private {
  my( $this, $c) = @_;

  # see if we can extract the pre-built tree object from cache
  my $cacheKey = 'treeData' . $c->stash->{acc} . $c->stash->{alnType};
  my $treeData = $c->cache->get( $cacheKey );
  
  if( defined $treeData ) {
    $c->log->debug( 'Family::Tree::getTreeData: extracted tree data from cache' )
      if $c->debug;  
  } else {
    $c->log->debug( 'Family::Tree::getTreeData: failed to extract tree data from cache; going to DB' )
      if $c->debug;  

    # retrieve the tree from the DB
    my $rs = $c->model('PfamDB::AlignmentsAndTrees')
               ->search( { auto_pfama => $c->stash->{pfam}->auto_pfama,
                           type       => $c->stash->{alnType} } );

    return unless defined $rs;
    
    my $row = $rs->first;
    return unless defined $row;
    
    my $tree = $row->tree;
    return unless defined $tree;

    # make sure we can uncompress it
    $treeData = Compress::Zlib::memGunzip( $tree );
    unless ( defined $treeData ) {
      $c->log->error( 'Family::Tree::getTree: ERROR: failed to uncompress ' 
                      . $c->stash->{alnType} . ' tree data for ' 
                      . $c->stash->{acc} );
      return;
    }

    # and now cache the populated tree data
    $c->cache->set( $cacheKey, $treeData ) unless $ENV{NO_CACHE};
  }
  
  # stash the uncompressed tree
  $c->stash->{treeData} = $treeData;
}

#-------------------------------------------------------------------------------

=head1 AUTHOR

John Tate, C<jt6@sanger.ac.uk>

Rob Finn, C<rdf@sanger.ac.uk>

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
