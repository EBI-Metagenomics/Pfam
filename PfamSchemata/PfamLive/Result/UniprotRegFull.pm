use utf8;
package PfamLive::Result::UniprotRegFull;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PfamLive::Result::UniprotRegFull

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<uniprot_reg_full>

=cut

__PACKAGE__->table("uniprot_reg_full");

=head1 ACCESSORS

=head2 auto_uniprot_reg_full

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 pfama_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 uniprot_acc

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 10

=head2 seq_start

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 seq_end

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 ali_start

  data_type: 'mediumint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 ali_end

  data_type: 'mediumint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 model_start

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 model_end

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 domain_bits_score

  data_type: 'double precision'
  default_value: 0.00
  is_nullable: 0
  size: [8,2]

=head2 domain_evalue_score

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 sequence_bits_score

  data_type: 'double precision'
  default_value: 0.00
  is_nullable: 0
  size: [8,2]

=head2 sequence_evalue_score

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 in_full

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "auto_uniprot_reg_full",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "pfama_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 7 },
  "uniprot_acc",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 10 },
  "seq_start",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "seq_end",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "ali_start",
  { data_type => "mediumint", extra => { unsigned => 1 }, is_nullable => 0 },
  "ali_end",
  { data_type => "mediumint", extra => { unsigned => 1 }, is_nullable => 0 },
  "model_start",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "model_end",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "domain_bits_score",
  {
    data_type => "double precision",
    default_value => "0.00",
    is_nullable => 0,
    size => [8, 2],
  },
  "domain_evalue_score",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "sequence_bits_score",
  {
    data_type => "double precision",
    default_value => "0.00",
    is_nullable => 0,
    size => [8, 2],
  },
  "sequence_evalue_score",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "in_full",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</auto_uniprot_reg_full>

=back

=cut

__PACKAGE__->set_primary_key("auto_uniprot_reg_full");

=head1 RELATIONS

=head2 pdb_pfam_a_regs

Type: has_many

Related object: L<PfamLive::Result::PdbPfamAReg>

=cut

__PACKAGE__->has_many(
  "pdb_pfam_a_regs",
  "PfamLive::Result::PdbPfamAReg",
  { "foreign.auto_uniprot_reg_full" => "self.auto_uniprot_reg_full" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pfama_acc

Type: belongs_to

Related object: L<PfamLive::Result::PfamA>

=cut

__PACKAGE__->belongs_to(
  "pfama_acc",
  "PfamLive::Result::PfamA",
  { pfama_acc => "pfama_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 uniprot_acc

Type: belongs_to

Related object: L<PfamLive::Result::Uniprot>

=cut

__PACKAGE__->belongs_to(
  "uniprot_acc",
  "PfamLive::Result::Uniprot",
  { uniprot_acc => "uniprot_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-22 11:24:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zh9nr4L7yTey+DYPOQrISA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
