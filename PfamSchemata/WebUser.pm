
# WebUser.pm
# jt 20060912 WTSI
#
# $Id: WebUser.pm,v 1.11 2007-04-26 13:40:19 rdf Exp $
#
# $Author: rdf $

=head1 NAME

WebUser - DBIC schema definition class for the web_user database

=cut

package WebUser;

=head1 DESCRIPTION

The base class for the whole web_user database model. Config comes from the
catalyst application class.

$Id: WebUser.pm,v 1.11 2007-04-26 13:40:19 rdf Exp $

=cut

use strict;
use warnings;

use base "DBIx::Class::Schema";

#-------------------------------------------------------------------------------

__PACKAGE__->load_classes( qw/Feature_das_sources
                              Alignment_das_sources
                              Das_sources
                              ErrorLog
                              Family_count
                              News JobData
                              JobSubmission
                              JobResults
                              JobStatus
                              HmmerHistory
                              HmmerStream
                              OtherJobsHistory
                              OtherJobsStream
                              / );

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
