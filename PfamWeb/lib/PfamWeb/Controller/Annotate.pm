
# Annotate.pm
# jt 20061020 WTSI
#
# $Id: Annotate.pm,v 1.22 2009-12-04 22:58:06 jt6 Exp $

=head1 NAME

PfamWeb::Controller::Annotate - accept user annotations

=cut

package PfamWeb::Controller::Annotate;

=head1 DESCRIPTION

Accepts user annotations.

$Id: Annotate.pm,v 1.22 2009-12-04 22:58:06 jt6 Exp $

=cut

use utf8;
use strict;
use warnings;

use base 'Catalyst::Controller';

use IO::All;
use Email::Valid;
use PfamWeb::CustomContainer;
use HTML::Widget::Element;
use Digest::MD5 qw( md5_hex );

# constants to encode the result of checking the form submission for tampering
# and timeouts, etc.
use constant { SUBMISSION_VALID        => 0,
               SUBMISSION_AJAX_FAILED  => 1,
               SUBMISSION_NO_COOKIE    => 2,
               SUBMISSION_MESSED_WITH  => 3,
               SUBMISSION_TIMED_OUT    => 4,
               SUBMISSION_INVALID      => 5,
               SUBMISSION_EMAIL_FAILED => 6 };

# set a custom container for the HTML::Widget form, to make it a wee bit
# easier to style
BEGIN {
  HTML::Widget::Element->container_class( 'PfamWeb::CustomContainer' );
}

#-------------------------------------------------------------------------------

=head1 METHODS

=head2 begin : Private

Checks input parameters and populates the stash accordingly.

=cut

sub begin : Private {
  my ( $this, $c, $entry_arg ) = @_;

  # get a handle on the entry and detaint it
  my $tainted_entry = $c->req->param('acc')   ||
                      $c->req->param('id')    ||
                      $c->req->param('entry') ||
                      $entry_arg              ||
                      '';

  # build the email subject line based on the accession (if given)

  if ( $tainted_entry =~ m/^(P([FB])\d{5,6})$/i ) {
    $c->log->debug( "Annotate::begin: found a Pfam entry ($1)" )
      if $c->debug;

    if ( $2 eq 'F' ) {
      $c->log->debug( 'Annotate::begin: got a pfam A entry' )
        if $c->debug;

      my $pfam = $c->model('PfamDB::Pfama')->find( { pfama_acc => $1 } );

      $c->stash->{type} = 'A';
      $c->stash->{acc}  = $pfam->pfama_acc;
      $c->stash->{id}   = $pfam->pfama_id;

      $c->stash->{subject} = 'Annotation submission for Pfam A entry "'
                             . $pfam->pfama_id . '" (' . $pfam->pfama_acc . ')';

    }
     elsif ( $2 eq 'B' ) {
      $c->log->debug( 'Annotate::begin: got a pfam B entry' )
        if $c->debug;

      $c->stash->{type} = 'B';
      $c->stash->{acc}  = $1;

      $c->stash->{subject} = "Annotation submission for Pfam B entry $1";
    }

  }
  elsif ( $tainted_entry =~ m/^(CL\d{4})$/i ) {
    $c->log->debug( 'Annotate::begin: found a clan entry' )
      if $c->debug;

    my $clan = $c->model('PfamDB::Clan')->find( { clan_acc => $1 } )
      if defined $1;

    $c->stash->{type} = 'C';
    $c->stash->{acc}  = $clan->clan_acc;
    $c->stash->{id}   = $clan->clan_id;

    $c->stash->{subject} = 'Annotation submission for Pfam clan '
                           . $c->stash->{id} . ' (' . $c->stash->{acc} . ')';

  }
  else {
    $c->log->debug( 'Annotate::begin: did not find a recognised accession' )
      if $c->debug;

    $c->stash->{subject} = 'Annotation submission';
  }

  $c->log->debug( 'Annotate::begin: subject will be: |'
                  . $c->stash->{subject} . '|' )
    if $c->debug;
}

#-------------------------------------------------------------------------------
#- visible actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 annotate : Path

The main entry point for the annotation form. Builds the form widget
and hands straight off to the template.

=cut

sub annotate : Path {
  my ( $this, $c ) = @_;

  # create the widget
  my $w = $c->forward( 'build_form' );

  # stash the widget, tell the template to build the form using that widget,
  # set the template and we're done
  $c->stash->{widget}    = $w->result;
  $c->stash->{buildForm} = 1;
  $c->stash->{template}  = 'pages/annotation.tt';

  $c->stash->{intendedRefreshUri} = $c->forward( 'build_refresh_uri' );

  # cache the annotation form for two weeks. We should be able to cache the
  # raw form safely, because the JS in it will still fire to retrieve the
  # time stamp. As long as we don't cache that, we should be fine !
  #$c->cache_page( 1209600 );
}

#-------------------------------------------------------------------------------

=head2 getTs : Local

This method is called by an AJAX request and returns, as plain text, the time
that the call was made. That timestamp is inserted into the submission form
by the calling javascript. We also return a cookie, containing a checksum
that's generated by digesting the timestamp with a salt that we get from the
server config.

See L<checkTimeOut> for a full explanation of the process.

=cut

sub getTs : Local {
  my ( $this, $c ) = @_;

  my $salt = $this->{salt};
  my $ts   = time;

  my $cs = md5_hex( $salt, $ts );
  $c->log->debug( "Annotate::getTs: checksum: |$cs|, timestamp: |$ts|" )
    if $c->debug;

  # set the value of the cookie to be the checksum and make it expire in
  # one hour, although we'll enforce that when we check the form submission
  # anyway
  $c->res->cookies->{token} = { value    => $cs,
                                expires  => '+1h' };

  # return the timestamp as a plain text string
  $c->res->content_type( 'text/plain' );
  $c->res->body( $ts );

  # and make damned sure this isn't cached by certain browsers...
  $c->res->header( 'Pragma'        => 'no-cache' );
  $c->res->header( 'Expires'       => 'Thu, 01 Jan 1970 00:00:00 GMT' );
  $c->res->header( 'Cache-Control' => 'no-store, no-cache, must-revalidate,'.
                                      'post-check=0, pre-check=0, max-age=0' );

  # we're done. The View will see that the response has a body and hand it
  # back to the browser unmolested.
}

#-------------------------------------------------------------------------------

=head2 submit : Local

Validates the input from the annotation form. Returns to the
annotation form if there were problems or forwards to the method that
sends an email.

=cut

sub submit : Local {
  my ( $this, $c ) = @_;

  # create the widget again
  my $w = $c->forward( 'build_form' );

  # process the form input through the widget
  my $r = $w->process( $c->req );

  # see if the form submission timed out or if the submission process has
  # been messed with
  my $submissionFault = $c->forward( 'checkTimeOut' );

  # check for submission faults first, since if there is anything funny going
  # on, we don't care what the input was
  if ( $submissionFault ) {

    $c->log->debug( 'Annotate::submit: fault with form submission' )
      if $c->debug;

    # drop the widget into the stash, along with the status value from the
    # form submission check. That will be interpreted by the template, which
    # will display an appropriate message
    $c->stash->{widget} = $r;
    $c->stash->{submissionError} = $submissionFault;

  }
  else {
    # the form was submitted in a valid process, so go ahead and validate
    # the input parameters

    if ( $r->has_errors ) {
      $c->log->debug( 'Annotate::submit: there were validation errors' )
        if $c->debug;

      # drop the widget into the stash, along with the status flag
      $c->stash->{widget} = $r;
      $c->stash->{submissionError} = SUBMISSION_INVALID;

    }
    else {
      $c->log->debug( 'Annotate::submit: no errors in the user input' )
        if $c->debug;

      # the input parameters validated, so send an email. Check to
      # see if something went wrong
      if ( $c->forward( 'sendMail' ) ) {
        $c->stash->{widget} = $r;
        $c->stash->{submissionError} = SUBMISSION_EMAIL_FAILED;
      }
      else {
        $c->log->debug( "Annotate::submit: submission was valid" )
          if $c->debug;

        # finally, if we got to here, it worked !
        $c->stash->{submissionError} = SUBMISSION_VALID;

        # decide where we should redirect the user
        $c->stash->{refreshUri} = $c->forward( 'build_refresh_uri' );
      }
    }
  }

  # hand off to the annotation form template, which can decide either to render
  # the form again, including the error messages, or just show a 'success'
  # message
  $c->stash->{template}  = 'pages/annotation.tt';
}

#-------------------------------------------------------------------------------
#- private actions -------------------------------------------------------------
#-------------------------------------------------------------------------------

=head2 build_refresh_uri : Private

Figures out the refresh URI for the page. The URI is returned, rather than
being stashed, so that it can be used other than as a META refreshUri value.

=cut

sub build_refresh_uri : Private {
  my ( $this, $c ) = @_;

  # decide where we should redirect the user
  my $target;
  if ( $c->stash->{type} eq 'A' ) {
    $target = '/family';
  }
  elsif( $c->stash->{type} eq 'B' ) {
    $target = '/pfamb';
  }
  elsif( $c->stash->{type} eq 'C' ) {
    $target = '/clan';
  }
  else {
    $target = '/';
  }

  return $c->uri_for( $target, $c->stash->{acc} );
}

#-------------------------------------------------------------------------------

=head2 checkTimeOut : Private

This method is intended to check whether the annotation form was submitted by
a legitimate user or by a script.

As the form loads, an AJAX request is made to the server. This has two
functions:

=over

=item 1. The AJAX response contains the timestamp for the request, which is
         added to a hidden field in the form by a snippet of javascript embedded
         in the page.

=item 2. A cookie is set, containing a checksum, which is the MD5 digest of the
         salt (stored in the server config) and the same timestamp.

=back

When the form is submitted (or rather, when the server receives values that look
like they've come from this form, since we could be getting values that are
sent by an illegitimate user/script) the server tries to read the timestamp from
the form and the checksum from the cookie. It performs the following checks:

=over

=item 1. Is the timestamp parameter in the form set to a a valid integer, which
         will be the case if the AJAX call was successful ? This should stop an
         attacking script submitting the form without having made the AJAX call.

=item 2. Was a cookie available to the server ? If there's no cookie, either a
         legitimate user doesn't have cookies enabled, which could be a problem,
         or a script tried to submit to the server without having made the
         AJAX call.

=item 3. Does the checksum value retrieved from the cookie match one that we
         calculate using our secret seed and the timestamp that we found in the
         form ? If not, the form parameter and the cookie were generated at
         different times, so it's unlikely that a legitimate user is trying to
         submit a form.

=item 4. Finally, is the timestamp in the form is younger than the timeout period
         that's defined in the server config ? If the form (actually, the hidden
         parameter) is older than our timeout period, either a legitimate user fell
         asleep whilst filling it in, or an illegitimate user is trying to submit
         values a long time after they scraped the form.

=back

All of this is based on a PHP/jQuery implementation of the process from:

=over

=item http://15daysofjquery.com/examples/contact-forms/

=back

=cut

sub checkTimeOut : Private {
  my ( $this, $c ) = @_;

  # assume it's failed...
  my $timedOut = SUBMISSION_TIMED_OUT;

  # make sure we can retrieve the timestamp for the form generation from the
  # hidden parameter in the form itself
  return SUBMISSION_AJAX_FAILED unless( defined $c->req->param( 'ts' ) and
                                                $c->req->param( 'ts' ) =~ /^(\d+)$/ );
  my $ts = $1;

  # the checksum from the cookie
  my $cookie = $c->req->cookie( 'token' );
  return SUBMISSION_NO_COOKIE unless defined $cookie;

  my $token = $cookie->value;

  # see if the cookie token matches the one we calculate by checksumming the
  # timestamp from the form using our secret salt
  my $salt = $this->{salt};
  my $cs   = md5_hex( $salt, $ts );
  return SUBMISSION_MESSED_WITH unless $token eq $cs;

  # check the form hasn't timed out
  return SUBMISSION_TIMED_OUT if ( $ts + $this->{submissionTimeOut} ) < time;

  # finally, nothing else has failed, so...
  return SUBMISSION_VALID;
}

#-------------------------------------------------------------------------------

=head2 sendMail : Private

Builds an annotation submission email and sends it to the address
specified in the config.

=cut

sub sendMail : Private {
  my ( $this, $c ) = @_;

  if ( $c->debug ) {
    $c->log->debug( 'Annotate::sendMail: sending an annotation mail' );
    $c->log->debug( 'Annotate::sendMail:   acc:   |' . $c->stash->{acc} . '|' );
    $c->log->debug( 'Annotate::sendMail:   id:    |' . $c->stash->{id} . '|' );
    $c->log->debug( 'Annotate::sendMail:   user:  |' . $c->req->param('user') . '|' );
    $c->log->debug( 'Annotate::sendMail:   email: |' . $c->req->param('email') . '|' );
    $c->log->debug( 'Annotate::sendMail:   ann:   |' . $c->req->param('annotation') . '|' );
    $c->log->debug( 'Annotate::sendMail:   refs:  |' . $c->req->param('refs') . '|' );
  }

  # validate the user-supplied email address. We check this because it could be a
  # conduit for email header injection, but the other params are used only in the
  # template, where they get passed through the HTML filter before the email
  # is sent to RT
  return 'Not a valid E-mail address'
    unless Email::Valid->address( -address => $c->req->param('email') );

  # see if there was an uploaded alignment
  my @parts;
  if ( $c->req->upload('alignment') ) {
    my $u = $c->req->upload('alignment');
    $c->log->debug( 'Annotate::sendMail: attaching upload to mail (' . $u->filename . ')' )
      if $c->debug;

    # build an email 'part' for it
    my $attachment = Email::MIME->create( attributes => { content_type => $u->type,
                                                          disposition  => 'attachment',
                                                          filename     => $u->filename },
                                          body      => io( $u->tempname )->all );
    push @parts, $attachment;
  }

  # stuff the stash
  $c->stash->{user}       = $c->req->param('user');
  $c->stash->{email}      = $c->req->param('email');
  $c->stash->{annotation} = $c->req->param('annotation');
  $c->stash->{refs}       = $c->req->param('refs');

  # render the email body
  my $mailTxt = $c->view('TT')->render($c, 'components/annotationEmail.tt' );

  # build the contents of the mail in the stash and send it
  $c->stash->{email} = {
    header     => [ To      => $this->{annotationEmail},
                    From    => $c->stash->{email},
                    Subject => $c->stash->{subject} ],
    parts      => [ $mailTxt, @parts ]
  };

  $c->forward( $c->view('Email') );

  if ( scalar @{ $c->error } ) {
    $c->log->error( 'Annotate::sendMail: problem when submitting an annotation: '
                    . join "\n", @{ $c->error } );
    $c->clear_errors;
  }

  return scalar @{ $c->error };
}

#-------------------------------------------------------------------------------

=head2 build_form : Private

Builds an HTML::Widget form for the annotation page.

=cut

sub build_form : Private {
  my ( $this, $c ) = @_;

  # get a widget
  my $w = $c->widget( 'annotationForm' )->method( 'post' );
  $w->subcontainer( 'div' );

  # set the action - always the same for the annotation form
  $w->action( $c->uri_for( 'submit' ) );

  #----------------------------------------
  # add the form fields

  if ( $c->req->param('acc') ) {
    $w->element( 'Hidden', 'acc' )
      ->value( $c->req->param('acc') );
  }

  # hidden parameter to store the timestamp
  $w->element( 'Hidden', 'ts' )
    ->value( 'empty' );

  # hidden parameter for the accession
  $w->element( 'Hidden', 'acc' )
    ->value( $c->stash->{acc} );

  # user's name
  $w->element( 'Textfield', 'user' )
     ->label( 'Name *' )
     ->size( 30 )
     ->maxlength( 200 );

  # email address
  $w->element( 'Textfield', 'email' )
    ->label( 'Email address *' )
    ->size( 30 )
    ->maxlength( 100 );

  # the annotation itself
  $w->element( 'Textarea', 'annotation' )
    ->label( 'Annotation details *' )
    ->cols( 50 )
    ->rows( 15 );

  # supporting references
  $w->element( 'Textarea', 'refs' )
    ->label( 'References' )
    ->cols( 50 )
    ->rows( 5 );

  # an alignment upload field
  $w->element( 'Upload', 'alignment' )
    ->label( 'Upload an alignment file' )
    ->accept( 'text/plain' )
    ->size( 30 );

  # a submit button
  $w->element( 'Submit', 'submit' )
    ->value('Send your comments');

  # and a reset button
  $w->element( 'Reset', 'reset' );

  #----------------------------------------
  # set some constraints on form values

  # required fields
  $w->constraint( All => qw/ user email annotation /)
    ->message( 'This is a required item' );

  # need a valid email address (or, at least, a correctly formatted one)
  $w->constraint( Email => qw/ email /)
    ->message( 'You did not supply a valid email address' );

  # tidy up the input a little
  foreach my $column ( qw/ user annotation refs / ) {
    $w->filter( HTMLEscape => $column );
    $w->filter( TrimEdges  => $column );
  }

  #----------------------------------------
  # finally, return the widget

  return $w;

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
