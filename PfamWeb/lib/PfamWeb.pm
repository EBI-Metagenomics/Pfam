
# PfamWeb.pm
# jt 20060316 WTSI
#
# $Id: PfamWeb.pm,v 1.17 2006-10-23 12:16:50 jt6 Exp $

=head1 NAME

PfamWeb - application class for the Pfam website

=cut

package PfamWeb;

=head1 DESCRIPTION

This is the main class for the Pfam website catalyst application. It
handles configuration of the application classes and error reporting
for the whole application.

$Id: PfamWeb.pm,v 1.17 2006-10-23 12:16:50 jt6 Exp $

=cut

use strict;
use warnings;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
# Static::Simple: will serve static files from the application's root
# directory
#
use Catalyst qw/
				-Debug
				ConfigLoader
				Prototype
				Session
				Session::Store::FastMmap
				Session::State::Cookie
				Session::State::URI
				Cache::FastMmap
				Static::Simple
				HTML::Widget
				/;

# add PageCache as the last plugin to enable page caching. Careful
# though... doesn't work with Static::Simple

# add the following to enable session handling:
#                Session
#                Session::Store::FastMmap
#                Session::State::Cookie

our $VERSION = '0.01';

#-------------------------------------------------------------------------------

=head1 CONFIGURATION

Configuration is done through a series of external "Apache-style"
configuration files.

=cut

# grab the location of the configuration file from the environment and
# detaint it. Doing this means we can configure the location of the
# config file in httpd.conf rather than in the code
my( $conf ) = $ENV{PFAMWEB_CONFIG} =~ /([\w\/-]+)/;

__PACKAGE__->config( file => $conf );
__PACKAGE__->setup;

#-------------------------------------------------------------------------------

=head2 reportError : Private

Records site errors in the database. Because we could be getting
failures constantly, e.g. from SIMAP web service, we want to avoid
just mailing admins about that, so instead we insert an error message
into a database table.

The table has four columns:

=over 8

=item message

the raw message from the caller

=item num

the number of times this precise message has been seen

=item first

the timestamp for the first occurrence of the message

=item last

the timestamp for that most recent occurence of the
message. Automatically updated on insert or update

=back

An external script or plain SQL query should then be able to retrieve
error logs when required and we can keep track of errors without being
deluged with mail.

=cut

sub reportError : Private {
  my( $this, $c ) = @_;

  foreach my $e ( @{$c->error} ) {

	$c->log->debug( "PfamWeb::reportError: reporting a site error: |$e|" );

	my $rs = $c->model( "WebUser::ErrorLog" )->find( { message => $e } );

	if( $rs ) {
	  $rs->update( { num => $rs->num + 1 } );
	} else {
	  eval {
		$c->model( "WebUser::ErrorLog" )->create( { message => $e,
													num     => 1,
													first   => [ "CURRENT_TIMESTAMP" ] } );
	  };
	  if( $@ ) {
		# really bad; an error while reporting an error...
		$c->log->error( "PfamWeb::reportError: couldn't create a error log: $@" );
	  }
	}
	
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
