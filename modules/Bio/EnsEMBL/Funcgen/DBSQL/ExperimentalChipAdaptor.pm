#
# Ensembl module for Bio::EnsEMBL::Funcgen::DBSQL::ExperimentalChipAdaptor
#
# You may distribute this module under the same terms as Perl itself

=head1 NAME

Bio::EnsEMBL::Funcgen::DBSQL::ExperimentalChipAdaptor - A database adaptor for fetching and
storing Funcgen ExperimentalChip objects.

=head1 SYNOPSIS

my $ec_a = $db->get_ExperimentalChipAdaptor();

my @ecs = @{$ec_a->fetch_all_by_Experiment($exp)};


=head1 DESCRIPTION

The ExperimentalChipAdaptor is a database adaptor for storing and retrieving
Funcgen ExperimentalChip objects.

=head1 AUTHOR

This module was created by Nathan Johnson.

This module is part of the Ensembl project: http://www.ensembl.org/

=head1 CONTACT

Post comments or questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::DBSQL::ExperimentalChipAdaptor;

use Bio::EnsEMBL::Utils::Exception qw( warning );
use Bio::EnsEMBL::Funcgen::ExperimentalChip;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

use vars qw(@ISA);


#May need to our this?
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 fetch_all_by_experiment_dbID

  Arg [1]    : int - dbID of Experiment
  Example    : my @ecs = @{$ec_a->fetch_all_by_experiment_dbID($ac_dbid);
  Description: Does what it says on the tin
  Returntype : Listref of Bio::EnsEMBL::Funcgen::ExperimentalChip
  Exceptions : None
  Caller     : General
  Status     : Medium Risk

=cut

sub fetch_all_by_experiment_dbID {
    my $self = shift;
    my $e_dbid = shift;

	my ($array_id, @results);

	throw("Must specify an experiemntal dbID") if(! $e_dbid);


	my $sth = $self->prepare("
		SELECT ec.experimental_chip_id
		FROM experimental_chip ec, experiment e
		WHERE ec.experiment_id = e.experiment_id
        AND e.experiment_id = $e_dbid
	");



	#can we do a generic fetch here?


	$sth->execute();


	while ($array_id = $sth->fetchrow()){
		push @results, $self->fetch_by_dbID($array_id);
	}

	return \@results;
}

=head2 fetch_by_unique_and_experiment_id

  Arg [2]    : int - ynique_id
  Arg [1]    : int - dbID of Experiment
  Example    : my $ec = ec_a->fetch_by_unique_and_experiment_id($c_uid, $exp_dbid);
  Description: Does what it says on the tin
  Returntype : Bio::EnsEMBL::Funcgen::ExperimentalChip
  Exceptions : None
  Caller     : General
  Status     : Medium Risk

=cut

sub fetch_by_unique_and_experiment_id {
    my ($self, $c_uid, $e_dbid) = @_;

	throw("Must provide and unique_id and and experiment_id") if(! $c_uid || ! $e_dbid);

	my $sth = $self->prepare("
		SELECT ec.experimental_chip_id
		FROM experimental_chip ec
		WHERE ec.unique_id = $c_uid
        AND ec.experiment_id = $e_dbid
	");


	$sth->execute();
	my ($ec_id) = $sth->fetchrow();

	
	return $self->fetch_by_dbID($ec_id) if $ec_id;
}



=head2 _tables

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns the names and aliases of the tables to use for queries.
  Returntype : List of listrefs of strings
  Exceptions : None
  Caller     : Internal
  Status     : Medium Risk

=cut

sub _tables {
	my $self = shift;
	
	return ['experimental_chip', 'ec'];
}

=head2 _columns

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns a list of columns to use for queries.
  Returntype : List of strings
  Exceptions : None
  Caller     : Internal
  Status     : Medium Risk

=cut

sub _columns {
	my $self = shift;
	
	return qw( ec.experimental_chip_id ec.unique_id ec.experiment_id ec.array_chip_id ec.description);
}

=head2 _objs_from_sth

  Arg [1]    : DBI statement handle object
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Creates OligoArray objects from an executed DBI statement
			   handle.
  Returntype : Listref of Bio::EnsEMBL::Funcgen::ExperimentalChip objects
  Exceptions : None
  Caller     : Internal
  Status     : Medium Risk

=cut

sub _objs_from_sth {
	my ($self, $sth) = @_;
	
	my (@result, $ec_id, $c_uid, $exp_id, $ac_id, $desc);
	
	$sth->bind_columns(\$ec_id, \$c_uid, \$exp_id, \$ac_id, \$desc);
	
	while ( $sth->fetch() ) {
		my $array = Bio::EnsEMBL::Funcgen::ExperimentalChip->new(
																 -dbID           => $ec_id,
																 -unique_id => $c_uid,
																 -experiment_id  => $exp_id,
																 -array_chip_id  => $ac_id,
																 -description    => $desc,
																 -adaptor        => $self,
																);

		push @result, $array;

	}
	return \@result;
}



=head2 store

  Args       : List of Bio::EnsEMBL::Funcgen::ExperimentalChip objects
  Example    : $oaa->store($ec1, $ec2, $ec3);
  Description: Stores given ExperimentalChip objects in the database. Should only be
               called once per array because no checks are made for duplicates.
			   Sets dbID and adaptor on the objects that it stores.
  Returntype : None
  Exceptions : None
  Caller     : General
  Status     : Medium Risk

=cut

sub store {
    my $self = shift;
    my @args = @_;

	my ($sarray);

	my $sth = $self->prepare("
			INSERT INTO experimental_chip
			(unique_id, experiment_id, array_chip_id, description)
			VALUES (?, ?, ?, ?)");



    foreach my $ec (@args) {
		if ( ! $ec->isa('Bio::EnsEMBL::Funcgen::ExperimentalChip') ) {
			warning('Can only store ExperimentalChip objects, skipping $ec');
			next;
		}

		if (!( $ec->dbID() && $ec->adaptor() == $self )){


			my $s_ec = $self->fetch_by_unique_and_experiment_id($ec->unique_id(), $ec->experiment_id());


			if(! $s_ec){
				$sth->bind_param(1, $ec->unique_id(), SQL_VARCHAR);
				$sth->bind_param(2, $ec->experiment_id(),  SQL_VARCHAR);
				$sth->bind_param(3, $ec->array_chip_id(),  SQL_VARCHAR);
				$sth->bind_param(4, $ec->description(),    SQL_VARCHAR);
			
				$sth->execute();
				my $dbID = $sth->{'mysql_insertid'};
				$ec->dbID($dbID);
				$ec->adaptor($self);
			}
			else{
				#do some status checks here, check IMPORTED
				#Need to account for recover in Importer?

				throw("ExperimentalChip already stored");
			}
		}
	}

	return \@args;

}


=head2 list_dbIDs

  Args       : None
  Example    : my @array_ids = @{$ec_a->list_dbIDs()};
  Description: Gets an array of internal IDs for all ExperimentalChip objects in the
               current database.
  Returntype : List of ints
  Exceptions : None
  Caller     : ?
  Status     : Medium Risk

=cut

sub list_dbIDs {
    my ($self) = @_;
	
    return $self->_list_dbIDs('experimental_chip');
}



1;

