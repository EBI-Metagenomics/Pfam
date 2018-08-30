use utf8;
package PfamDB::Author;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamDB::Author

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<author>

=cut

__PACKAGE__->table("author");

=head1 ACCESSORS

=head2 author_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 author

  data_type: 'tinytext'
  is_nullable: 0

=head2 orcid

  data_type: 'varchar'
  is_nullable: 1
  size: 19

=cut

__PACKAGE__->add_columns(
  "author_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "author",
  { data_type => "tinytext", is_nullable => 0 },
  "orcid",
  { data_type => "varchar", is_nullable => 1, size => 19 },
);

=head1 PRIMARY KEY

=over 4

=item * L</author_id>

=back

=cut

__PACKAGE__->set_primary_key("author_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<au_id_orcid>

=over 4

=item * L</author_id>

=item * L</orcid>

=back

=cut

__PACKAGE__->add_unique_constraint("au_id_orcid", ["author_id", "orcid"]);

=head1 RELATIONS

=head2 pfama_authors

Type: has_many

Related object: L<PfamDB::PfamaAuthor>

=cut

__PACKAGE__->has_many(
  "pfama_authors",
  "PfamDB::PfamaAuthor",
  { "foreign.author_id" => "self.author_id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-08-30 08:56:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oMZUIEVc9X+Im6zlmVVwbA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
