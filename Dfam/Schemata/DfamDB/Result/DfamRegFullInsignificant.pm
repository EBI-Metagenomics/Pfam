package DfamDB::Result::DfamRegFullInsignificant;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

DfamDB::Result::DfamRegFullInsignificant

=cut

__PACKAGE__->table("dfam_reg_full_insignificant");

=head1 ACCESSORS

=head2 auto_dfam_reg_full

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 dfam_acc

  data_type: 'varchar'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0
  size: 7

=head2 auto_dfamseq

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 seq_start

  data_type: 'mediumint'
  default_value: 0
  is_nullable: 0

=head2 seq_end

  data_type: 'mediumint'
  default_value: 0
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

=cut

__PACKAGE__->add_columns(
  "auto_dfam_reg_full",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "dfam_acc",
  {
    data_type => "varchar",
    default_value => 0,
    is_foreign_key => 1,
    is_nullable => 0,
    size => 7,
  },
  "auto_dfamseq",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "seq_start",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
  "seq_end",
  { data_type => "mediumint", default_value => 0, is_nullable => 0 },
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
);
__PACKAGE__->set_primary_key("auto_dfam_reg_full");

=head1 RELATIONS

=head2 dfam_acc

Type: belongs_to

Related object: L<DfamDB::Result::Dfam>

=cut

__PACKAGE__->belongs_to(
  "dfam_acc",
  "DfamDB::Result::Dfam",
  { dfam_acc => "dfam_acc" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->belongs_to(
  "dfamseq",
  "DfamDB::Result::Dfamseq",
  { auto_dfamseq => "auto_dfamseq" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-11 15:01:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KnihZD1tAzsUY1CG/48+aw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
