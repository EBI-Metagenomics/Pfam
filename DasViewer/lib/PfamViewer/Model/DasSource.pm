package PfamViewer::Model::DasSource;

use strict;
use warnings;
use parent 'Catalyst::Model';
#use lib '/nfs/team71/pfam/pg6/2009/project/catalyst_test/PfamViewer';
use DataSource;

use Data::Dump qw( dump );

=head1 NAME

PfamViewer::Model::DasSource - Catalyst Model

=head1 DESCRIPTION

Catalyst Model: which returns the das alignment.

=cut 

=head2 dasAlignment

Method which makes a das request and returns the processed alignment.

=cut 

sub getDataSource{
  my( $this, $args ) = @_;
  
#  my ( $dsn   ) = $this->{dsn}         =~ m/^([\w\.\:\/\-\?\#]+)$/;
  my ( $proxy )      = $this->{proxy} || '' =~ /^([\w\:\/\.\-\?\#]+)$/;
  my ( $to )         = $this->{timeout} || 60 =~ /^\d+$/;    
  my ( $capability ) = $this->{capability} =~ /^\w+$/;
  
  # add extra params to the $args hash for creating the bio::Das::Lite object;
  $args->{ das_params }->{ timeout }    = $to;
  $args->{ das_params }->{ capability } = $capability;
  $args->{ das_params }->{http_proxy}   = $proxy if defined $proxy;
  
  # store the config file in input params;
  $args->{ input_params }->{ config } = $this->{ config };
  
  my $ds = DataSource->new( $args );
  
  return $ds;  
}

=head1 AUTHOR

Prasad Gunasekaran,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
