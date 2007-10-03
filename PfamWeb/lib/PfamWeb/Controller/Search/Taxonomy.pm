
# Taxonomy.pm
# jt6 20070918 WTSI
#
# $Id: Taxonomy.pm,v 1.5 2007-10-03 16:00:05 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Search::Taxonomy - controller for taxonomy searches

=cut

package PfamWeb::Controller::Search::Taxonomy;

=head1 DESCRIPTION

A search controller for performing taxonomy searches

$Id: Taxonomy.pm,v 1.5 2007-10-03 16:00:05 jt6 Exp $

=cut

use strict;
use warnings;

use Search::QueryParser;
use Data::Dump qw( dump );

use base 'PfamWeb::Controller::Search';

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 taxonomy : Path

Perform a taxonomy search and retrieves Pfam-A families selected by the
user-supplied boolean query strings, such as

  "Caenorhabditis elegans AND NOT Homo sapiens"

=cut

sub taxonomy : Path {
  my( $this, $c ) = @_;
  
  $c->log->debug( 'Search::Taxonomy::taxonomy: starting a taxonomy search' )
    if $c->debug;

  # make sure we got *something*
  unless( defined $c->req->param('q') ) {
    $c->stash->{taxSearchError} = 'There was a problem with your query. '
      . 'You did not supply a query string.';
    return;
  }

  # make sure it was plain text
  # But how do we deal with a case like "Escherichia coli O157:H7"? 
  unless( $c->req->param('q') =~ m/^([\S().\s]+)$/ ) {
    $c->stash->{taxSearchError} = 'There was a problem with your query. '
      . 'Please check that there are no illegal characters in your query string and try again.';
    return;
  }
  my $query = $1;
  $c->log->debug( "Search::Taxonomy::taxonomy: found query string: |$query|" )
    if $c->debug;
  
  #----------------------------------------
  
  # call parseTerms, to parse the query string and return it with the species 
  # names quoted. That method also puts two arrays into the stash: @terms 
  # stores the raw terms, @sentence stores the terms plus the boolean operators 
  # and braces
  
  my $quotedQuery = $c->forward('parseTerms', [ $query ] );

  #----------------------------------------
  
  # we got a valid string, but does it parse ?
  $c->log->debug( "Search::Taxonomy::taxonomy: got quoted query string: |$quotedQuery|" )
    if $c->debug;

  # see if we can retrieve this result from cache. Need to get rid of the 
  # stranger characters in the quoted string, like quotes, for a start...
  my $cacheKey = 'taxonomySearch' . $quotedQuery;
  $cacheKey =~ s/[\W\s]/_/g;
  my $families = $c->cache->get( $cacheKey );
  
  if( defined $families ) {
    $c->log->debug( 'Search::Taxonomy::taxonomy: retrieved families from cache' )
      if $c->debug;
  } else {
    $c->log->debug( 'Search::Taxonomy::taxonomy: failed to retrieve families from cache; going to DB' )
      if $c->debug;
   
    my $qp = new Search::QueryParser;
    my $pq = $qp->parse( $quotedQuery );
    unless( $pq ) {
      $c->stash->{taxSearchError} = 'There was a problem with your query. '
        . 'Please check that you entered a valid boolean query and try again.';
      return;
    }
      
    $c->log->debug( 'Search::Taxonomy::taxonomy: parsed query: ', dump $pq )
      if $c->debug;
  
    # walk down the tree and accumulate the list of Pfam-As for the specified
    # species
    $families = $c->forward('descend', [ $pq, '' ] );
  
    # cache the result
    $c->cache->set( $cacheKey, $families );
  }
  
  $c->log->debug( 'Search::Taxonomy::taxonomy: got the following families ',
                  dump $families )
    if $c->debug;
  
  $c->stash->{families} = $families;
  $c->stash->{template} = 'pages/search/taxonomy/results.tt';
}

#-------------------------------------------------------------------------------

=head2 unique : Local

Retrieves the list of Pfam-A accessions for families that are unique to the
specified taxonomic level (species, e.g. "C. elegans", or level, 
e.g. "Metazoa").

=cut

sub unique : Local {
  my( $this, $c ) = @_;

  # make sure we got *something*
  unless( defined $c->req->param('q') ) {
    $c->stash->{taxSearchError} = 'There was a problem with your query. '
      . 'You did not supply a query string.';
    return;
  }

  # make sure it was plain text
  # But how do we deal with a case like "Escherichia coli O157:H7"? 
  unless( $c->req->param('q') =~ m/^([\S().\s]+)$/ ) {
    $c->stash->{taxSearchError} = 'There was a problem with your query. '
      . 'Please check that you have not included any illegal characters and try again.';
    return;
  }
  my $query = $1;
  
  #----------------------------------------

  # call parseTerms, to parse the query string and return it with the species 
  # names quoted. That method also puts two arrays into the stash: @terms 
  # stores the raw terms, @sentence stores the terms plus the boolean operators 
  # and braces
  
  my $quotedQuery = $c->forward('parseTerms', [ $query ] );

  # we should have only one species name in the query
  if( scalar @{ $c->stash->{terms} } > 1 ) {
    $c->stash->{taxSearchError} = 'You can only find unique families for a single species.'
      . ' Please enter only one species name and try again.';
    return;
  }
  
  $c->log->debug( "Search::Taxonomy::unique: finding unique matches for |$quotedQuery|" )
    if $c->debug;

  #----------------------------------------

  # see if we can retrieve this result from cache. Need to get rid of the 
  # stranger characters in the quoted string, like quotes, for a start...
  my $cacheKey = 'uniqueFamilies' . $quotedQuery;
  $cacheKey =~ s/[\W\s]/_/g;
  my $unique = $c->cache->get( $cacheKey );
  
  if( defined $unique ) {
    $c->log->debug( 'Search::Taxonomy::unique: retrieved unique families from cache' )
      if $c->debug;
  } else { 
    $c->log->debug( 'Search::Taxonomy::unique: failed to retrieve unique families from cache; going to DB' )
      if $c->debug;
    
    my $allCount  = $c->forward('getAllFamilyCount');
    my $termCount = $c->forward('getFamilyCount', [ $quotedQuery ] );

    $unique = {};
    while( my( $k, $v ) = each %$termCount ) {
      # now see if the count is the same; if it is then it must be unique to 
      # the term
      $unique->{$k}++ if $allCount->{$k} == $v;
    }

    # cache the result
    $c->cache->set( $cacheKey, $unique );
  }
  
  $c->log->debug( 'Search::Taxonomy::unique: got the following families ',
                  dump $unique )
    if $c->debug;

  $c->stash->{uniqueFamilies} = $unique;
  $c->stash->{template}       = 'pages/search/taxonomy/results.tt';
}

#-------------------------------------------------------------------------------

=head2 suggest : Local

Returns a list of possible completions for species names as an HTML list (ul).

This action is intended to be called only by an AJAX call from the taxonomy 
search form. The resulting list is presented as auto-completion lines under the 
form field, letting the user know immediately that they can't spell 
Caenorhabditis elegans after all...

=cut

sub suggest : Local {
  my( $this, $c ) = @_;

  # make sure we got *something*
  return unless( defined $c->req->param('q') and 
                 $c->req->param('q') =~ m/^([\w\s\(\)\.]+)$/ );

  # split up the search string into individual 'words'. We don't care about
  # the return value, which gives the search string with the species names
  # quoted
  $c->forward( 'parseTerms', [ $1 ] );

  #----------------------------------------

  # perform a database look-up for the LAST species name in the search string, 
  # if there is one at this point

  my( $rawSpecies, @speciesSuggestions );
  
  if( defined $c->stash->{terms}->[-1] ) {
    
    $rawSpecies = $c->stash->{terms}->[-1];
  
    $c->log->debug( "Search::Taxonomy::suggest: raw species name: |$rawSpecies|" )
      if $c->debug;

    # collect the list of matching species names    
    my @species = $c->model('PfamDB::Taxonomy')
                    ->search_like( { species => "$rawSpecies%" } );
    foreach ( @species ) {
      push @speciesSuggestions, $_->species;
    }
                 
    # collect the list of matching levels, which are distinct from the actual
    # species name    
    my @levels  = $c->model('PfamDB::Taxonomy')
                    ->search_like( { level => "$rawSpecies%" } );
    foreach ( @levels ) {
      push @speciesSuggestions, $_->level;
    }
  
    $c->log->debug( 'Search::Taxonomy::suggest: found a total of |'
                    . scalar @speciesSuggestions . "| suggestions for |$rawSpecies|" )
      if $c->debug;
  }
  
  #----------------------------------------

  # rebuild the search string using the suggestions

  # limit the number of suggestions that we return; set in the config
  my $limit = $this->{numSuggestions} || 10;
  my $i = 0;

  my @searchSuggestions;
  my $suggestionLine = '';
  my $limited = 0;

  WORD:
  foreach my $word ( @{ $c->stash->{sentence} } ) {
    $c->log->debug( "Search::Taxonomy::suggest: suggesting for word |$word|" );

    # if this word is not the same as the last search term (which will be the
    # case if it's AND, OR, NOT or a brace), include it as is
    unless( $word eq $rawSpecies ) {
      $suggestionLine .= $word . ' ';
      next WORD;
    }

    # only add suggestions for the last search term
    unless( $word eq $c->stash->{sentence}->[-1] ) { 
      $suggestionLine .= $word . ' ';
      next WORD;
    }
    
    # build the list of suggestions based on the suggestions for the current
    # word
    SUGGESTION: 
    foreach my $suggestion ( sort @speciesSuggestions ) {
      push @searchSuggestions, $suggestionLine . $suggestion;
      if( $i >= $limit - 1 ) {
        $limited = 1;
        last WORD;
      }
      $i++;
    }

    $c->log->debug( "Search::Taxonomy::suggest: we now have |$i| suggestion lines ("
                    . scalar @searchSuggestions . ' according to array)' )
      if $c->debug;
  }

  my $responseString = '<ul>';
  foreach my $i ( 0 .. $#searchSuggestions ) {
    my $suggestion = $searchSuggestions[$i];

    $c->log->debug( "Search::Taxonomy::suggest: search suggestion: |$suggestion|" )
      if $c->debug;

    if( $limited and $i == $#searchSuggestions ) {
      $c->log->debug( 'Search::Taxonomy::suggest: suggestion list limited' )
        if $c->debug;
      $responseString .= qq(<li>$suggestion<span class="informal"><br />(Showing only first $limit suggestions)</span></li>); 
    } else {
      $responseString .= "<li>$suggestion</li>";
    }
  }
  
  $responseString .= '</ul>';
  
  #----------------------------------------

  $c->res->body( $responseString );
}

#-------------------------------------------------------------------------------
#- private actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 parseTerms : Private

Parses the query string into two arrays, @terms and @sentence, containing the 
species names and all of the tokens within the query respectively. The two 
arrays are dropped into the stash. Returns the query string with the species 
names quoted.

=cut

sub parseTerms : Private {
  my( $this, $c, $query ) = @_;

  # later we'll want to chomp to remove trailing spaces... 
  local $/ = ' ';
  
  # put spaces around braces to make sure we see them in the list of words when 
  # we split on spaces
  $query =~ s|([\(\)])| $1 |g;

  # strip leading and trailing spaces 
  $query =~ s/^\s*(.*?)\s*$/$1/;
  $c->log->debug( "Search::Taxonomy::parseTerms: starting with search term: |$query|" )
    if $c->debug;
  
  # break up the search term into "words"
  my @words = split /\s+/, $query;
  
  #----------------------------------------
  
  # next, filter the terms to collect the actual species names separately from
  # the boolean terms and braces. We'll also need to keep track of the order
  # of everything though, so that we can reconstruct the whole string, corrected
  # by the searches

  my( @terms, @sentence );
  my $term = '';
  foreach my $index ( 0 .. $#words ) {
    my $word = $words[$index];

    # filter out the debris of merging AND and NOT
    next if not defined $word;

    # and actually merge AND and NOT...
    if( $word =~ /^AND$/i ) {
      
      # check if the next word in the sentence is NOT and, if it is, merge
      # it with the current AND before deleting the NOT from the sentence
      # altogether
      if( $words[$index + 1] and 
          $words[$index + 1] eq 'NOT' ) {
        delete $words[$index + 1];
        chomp $term;
        push @sentence, $term, 'AND NOT';
        push @terms, $term;
        $term = '';

      } else {
        chomp $term;
        push @sentence, $term, 'AND';
        push @terms, $term;
        $term = '';
      }

    } elsif( $word =~ m/^(OR|NOT|\(|\))$/i ) {

      # just stuff this term (OR, NOT or braces) into the sentence, but ignore
      # terms that are just composed of spaces
      unless( $term =~ /^\s*$/ ) {
        chomp $term;
        push @sentence, $term;
        push @terms, $term;
      }
      push @sentence, uc $word;
      $term = '';

    } else {
      # the word that we have is a search term; add it to the growing search 
      # term string
      $term .= $word . ' ';
    }

  }

  # finally, if we had a non-whitespace term at the end of the search string, 
  # push in it into the list
  unless( $term =~ /^\s*$/ ) {
    chomp $term;
    push @sentence, $term;
    push @terms, $term;
  }

  #----------------------------------------

  # now we should have two arrays, one with the species names that we'll need
  # to search (@term), one with the whole search term broken up into 'words'
  # (@sentence)
  $c->stash->{terms}    = \@terms;
  $c->stash->{sentence} = \@sentence;
  
  # finally, put double-quotes around each of the search terms in the input
  # string and return that
  foreach my $term ( @{ $c->stash->{terms} } ) {
    $query =~ s/($term)/"$1"/ig;
  }

  return $query;
}

#-------------------------------------------------------------------------------

=head2 getFamilyCount : Private

Retrieves the list of families in a given species. Returns a reference to a 
hash containing the Pfam-A accession and the count of the number of families.

=cut

sub getFamilyCount : Private {
  my( $this, $c, $term ) = @_;  

  # see if we can retrieve the families from cache
  my $cacheKey = 'familyCount' . $term;
  $cacheKey =~ s/[\W\s]/_/g;
  $c->log->debug( "Search::Taxonomy::getFamilyCount: cacheKey: |$cacheKey|" )
    if $c->debug;
  my $res      = $c->cache->get( $cacheKey );

  if( defined $res ) {
    $c->log->debug( 'Search::Taxonomy::getFamilyCount: retrieved family counts from cache' )
      if $c->debug;
  } else {
    $c->log->debug( 'Search::Taxonomy::getFamilyCount: failed to retrieve family counts from cache; going to DB' )
      if $c->debug;

    my $range = $c->forward('getRange', [ $term ] );
    
    if( not defined $range ) {
      $c->log->debug( 'Search::Taxonomy::getFamilyCount: range error' );
      $c->stash->{rangeError} = "Could not find $term";
      return;
    }
      
    $c->log->debug( 'Search::Taxonomy::getFamilyCount: getting count for '
                    . "|$term|, |$range->[0]|, |$range->[1]|" )
      if $c->debug;
  
    my @rs = $c->model('PfamDB::Taxonomy')
               ->search( { lft => { '>=' => $range->[0] },
                           rgt => { '<=' => $range->[1] } },
                         { join     => [ 'pfamAncbi' ],
                           select   => [ 'pfamAncbi.pfamA_acc', 
                                         { count => 'pfamAncbi.auto_pfamA' } ],
                           as       => [ 'pfamA_acc', 'count' ],
                           group_by => [ 'pfamAncbi.auto_pfamA' ],
                         } );
  
    my %res = map{ $_->get_column('pfamA_acc') => $_->get_column('count') } @rs;
  
    $c->log->debug( 'Search::Taxonomy::getFamilyCount: got |'
                    . scalar( keys %res ) . '| family counts' )
      if $c->debug;

    $res = \%res;
    
    # cache the result
    $c->cache->set( $cacheKey, $res );
  }
  
  return $res;
}

#-------------------------------------------------------------------------------

=head2 getAllFamilyCount : Private

Retrieves, for each Pfam-A family, the count of the number of times that family
occurs for each species. Returns a reference to a hash with Pfam-A accession 
and count.

=cut

sub getAllFamilyCount : Private {
  my( $this, $c ) = @_;  

  my $cacheKey = 'allFamilyCount';
  $c->log->debug( "Search::Taxonomy::getAllFamilyCount: cacheKey: |$cacheKey|" )
    if $c->debug;
  my $res      = $c->cache->get( $cacheKey );

  if( defined $res ) {
    $c->log->debug( 'Search::Taxonomy::getAllFamilyCount: retrieved family counts from cache' )
      if $c->debug;
  } else {
    $c->log->debug( 'Search::Taxonomy::getAllFamilyCount: failed to retrieve family counts from cache; going toDB' )
      if $c->debug;

    my @rs = $c->model('PfamDB::PfamA_ncbi')
               ->search( {},
                         { select   => [ 'pfamA_acc', 
                                         { count => 'auto_pfamA' } ],
                           as       => [ 'pfamA_acc', 'count' ],
                           group_by => [ 'me.auto_pfamA' ],
                         } );
  
    # hash the results
    my %res = map{ $_->get_column('pfamA_acc') => $_->get_column('count') } @rs;

    $c->log->debug( 'Search::Taxonomy::getAllFamilyCount: found |'
                    . scalar( keys %res ) . '| family counts' )
      if $c->debug;
  
    $res = \%res;
    
    # and cache that result
    $c->cache->set( $cacheKey, $res );
  }

  return $res;
}

#-------------------------------------------------------------------------------

=head2 getFamiliesForSpecies : Private

Returns the families that are found for the single specified taxonomic term. 
This is used only by the "descend" method, to build the list of Pfam-A families 
for a set of species.

The first job is to find the range, the lft and rgt values, for the given
species in the table that stores the species tree.

=cut

sub getFamiliesForTerm : Private {
  my( $this, $c, $term ) = @_;
  
  # see if we can retrieve the families for this species from cache
  my $cacheKey = 'familiesForTerm' . $term;
  $cacheKey =~ s/[\W\s]/_/g;  
  $c->log->debug( "Search::Taxonomy::getFamilies: cacheKey: |$cacheKey|" )
    if $c->debug;
  my $res      = $c->cache->get( $cacheKey );
  
  if( defined $res ) {
    $c->log->debug( 'Search::Taxonomy::getFamiliesForTerm: retrieved families from cache' )
      if $c->debug;
  } else { 

    # find the left and right values for this specific species name
    my $range = $c->forward('getRange', [ $term ] );
  
    # "getRange" returns 0 if it couldn't find a range for the given term, or
    # a hash ref if it found the lft/rgt values
  
    # return "0" by default, as this is what $c->forward will enforce anyway
    return 0 unless ref($range) eq 'ARRAY';
  
    $c->log->debug( 'Search::Taxonomy::getFamiliesForTerm: failed to retrieve families from cache; going to DB' )
      if $c->debug;

    my @rs = $c->model('PfamDB::PfamA_ncbi')
               ->search( { 'tax.lft'    => { '>=' => $range->[0] },
                           'tax.rgt'    => { '<=' => $range->[1] } },
                         { join     => [ 'tax' ],
                           prefetch => [ 'tax' ] }
                       );
  
    my %res = map{ $_->pfamA_acc => 1 } @rs; 

    $c->log->debug( 'Search::Taxonomy::getFamiliesForSpecies: found |'
                    . scalar( keys %res ) . '| families' )
      if $c->debug;
      
    $res = \%res;
      
    # cache the result
    $c->cache->set( $cacheKey, $res );
  }
  
  return $res;
}

#-------------------------------------------------------------------------------

=head2 descend : Private

Description...

=cut

sub descend : Private {
  my( $this, $c, $query, $operator ) = @_;

  my $famAllRef = {};

  # walk over these specific keys. Need to have this as a literal list in order
  # to fix the order of precedence
  foreach my $k ( '+', '-', '', 'value'){
    next unless $query->{$k};
    
    $c->log->debug( "Search::Taxonomy::descend: key: |$k|" ) if $c->debug;
    
    # if there's an array of values...
    my $v = $query->{$k};
    if( ref($v) eq 'ARRAY' ) {

      $c->log->debug( 'Search::Taxonomy::descend: got an array' ) if $c->debug;

      # walk over the array of values
      foreach my $e ( @$v ) {

        # descend further down the tree
        my $f = $c->forward('descend', [ $e, $k ] );
        $f = undef if $f eq 0;

        # there's another level below this one
        if( keys %$famAllRef ) {
          if( $k eq '+' ) {
            $famAllRef = findCommon( $famAllRef, $f ); # AND
          } elsif( $k eq '-' ) {
            $famAllRef = uniquify(   $famAllRef, $f ); # NOT
          } else {
            $famAllRef = merge(      $famAllRef, $f ); # OR
          }          
        } else {
          $famAllRef = $f;
        }
      } # end of "foreach value"

    } elsif( $k eq 'value' ) {
      # there's a single value

      if( ref($v) eq 'HASH' ) {
        # still at a branch; recurse further
        $famAllRef = $c->forward('descend', [ $v, $operator ] );
        
      } else {
        # leaf node; $v is now a species term
        $famAllRef = $c->forward('getFamiliesForTerm', [ $v ] );
      } 
    } else {
      $c->log->warn( "Search::Taxonomy::descend: didn't do anything with |$k|$v|" );
    }
  }

  return $famAllRef if ref($famAllRef) eq 'HASH';
}

#-------------------------------------------------------------------------------

=head2 getRange: Private

Looks up the left and right values for a given species or taxonomic level.
If it finds both left and right values, they are returned as a reference to 
an array, "0" otherwise.

=cut

sub getRange : Private {
  my( $this, $c, $term ) = @_;
  
  # we want to get the left and right ranges for the term from the taxomony 
  # table
  
  # we need to remove double quotes added round the term by QueryParser
  $term =~ s/\"//g;
  
  $c->log->debug( "Search::Taxonomy::getRange: looking up term: |$term|" )
    if $c->debug;

  my $rs;
  if( $term =~ m/\S+\s+\S+/ ){
    # looks like a species name
    $c->log->debug( 'Search::Taxonomy::getRange: looks like a species term')
      if $c->debug;
         
    $rs = $c->model('PfamDB::Taxonomy')
            ->find( { species => $term } );  

  } elsif( $term =~/\S+/ ) {
    # looks like a taxonomic level other than species.
    $c->log->debug( 'Search::Taxonomy::getRange: looks like a level term' )
      if $c->debug;

    $rs = $c->model('PfamDB::Taxonomy')
            ->find( { level => $term } );
  }
  
  # return "0" by default, as this is what $c->forward will enforce anyway
  my $rv = 0;
  if( $rs->lft and $rs->rgt ) {
    $c->log->debug( 'Search::Taxonomy::getRange: got range for term: '
                    . '|' . $rs->lft . '|' . $rs->rgt . '|' )
      if $c->debug;   
    $rv = [ $rs->lft, $rs->rgt ];  
  }

  # return 0 if we don't get a range
  return $rv;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 findCommon

Returns a reference to a hash with keys that are common to both input hashes. 
Note that the values in the hash are always 1.

=cut

sub findCommon {
  my( $hashRef1, $hashRef2 ) = @_;

  my %common;
  foreach ( keys %$hashRef1 ) {
    $common{$_} = 1
      if exists $hashRef2->{$_};
  }
  return \%common;
}

#-------------------------------------------------------------------------------

=head2 merge

Returns a reference to a hash containing the key/value pairs from the two input
hashes. The hashes are merged in the order hash1, hash2, so that duplicate keys
in hash2 will overwrite those from hash1.

=cut

sub merge {
  my( $hashRef1, $hashRef2 ) = @_;
  my %merged;
  foreach my $hashRef ( $hashRef1, $hashRef2 ) {
    while( my( $k, $v) = each %$hashRef ) {
      $merged{$k} = $v;
    }
  } 
  return \%merged
}

#-------------------------------------------------------------------------------

=head2 unique

Returns a reference to a hash containing those keys from the first input hash
that are not found in the second input hash.

=cut

sub uniquify {
  my( $hashRef1, $hashRef2 ) = @_;
  my %this_not_that;
  foreach ( keys %$hashRef1 ) {
    $this_not_that{$_} = 1
      unless exists $hashRef2->{$_};
  }
  return \%this_not_that;
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
