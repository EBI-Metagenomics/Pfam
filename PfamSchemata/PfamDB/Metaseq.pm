
# $Id: Metaseq.pm,v 1.3 2008-05-16 15:23:16 jt6 Exp $
#
# $Author: jt6 $

package PfamDB::Metaseq;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( qw( Core ) );

# set up the table
__PACKAGE__->table( 'metaseq' );

# get the columns that we want to keep
__PACKAGE__->add_columns( qw( auto_metaseq 
                              metaseq_id 
                              metaseq_acc 
                              description 
                              length 
                              sequence
                              source ) );

# set the the keys
__PACKAGE__->set_primary_key( qw( auto_metaseq ) );

# set up the relationships
__PACKAGE__->has_many( meta_pfama_reg => 'PfamDB::Meta_pfama_reg',
                       { 'foreign.auto_metaseq' => 'self.auto_metaseq' } );

# TODO this is actually wrong; there can be multiple rows for each source (multiple refs)
__PACKAGE__->has_one( meta_ref => 'PfamDB::Metagenomics_refs',
                      { 'foreign.source' => 'self.source' },
                      { proxy => [ qw( long_source pmid ) ] } );

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
