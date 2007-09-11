#
# Ensembl module for Bio::EnsEMBL::Funcgen::ExperimentalSubset
#
# You may distribute this module under the same terms as Perl itself

=head1 NAME

Bio::EnsEMBL::ExperimentalSet - A module to represent ExperimentalSubset object.
 

=head1 SYNOPSIS

use Bio::EnsEMBL::Funcgen::ExperimetnalSubset;

my $data_set = Bio::EnsEMBL::Funcgen::ExperimentalSubset->new(
	                                                         -DBID            => $dbID,
							 					             -ADAPTOR         => $self,
                                                             -NAME            => $name,
                                                             #do we really need ExperimentalSet or maybe just dbID?
                                                             );



=head1 DESCRIPTION

An ExperimentalSubset object is a very simple skeleton class to enable storage of associated subset states. As such there
are only very simple accessor methods for basic information, and there is no namesake adaptor, rather is is handled by the 
ExperimentalSetAdaptor.

=head1 AUTHOR

This module was created by Nathan Johnson.

This module is part of the Ensembl project: http://www.ensembl.org/

=head1 CONTACT

Post comments or questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::ExperimentalSubset;

use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw( throw );
use Bio::EnsEMBL::Funcgen::Storable;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Funcgen::Storable);


=head2 new

  Example    : my $eset = Bio::EnsEMBL::Funcgen::ExperimentalSubset->new(
                                                                        -DBID            => $dbID,
							 					                        -ADAPTOR         => $self,
                                                                        -NAME            => $name,
                                                                        );


  Description: Constructor for ExperimentalSubset objects.
  Returntype : Bio::EnsEMBL::Funcgen::ExperimentalSubset
  Exceptions : Throws if no name defined
               Throws if CellType or FeatureType are not valid or stored
  Caller     : General
  Status     : At risk

=cut

sub new {
  my $caller = shift;
	
  my $class = ref($caller) || $caller;
	
  my $self = $class->SUPER::new(@_);
	
  #do we need to add $fg_ids to this?  Currently maintaining one feature_group focus.(combi exps?)
  my ($name)
    = rearrange(['NAME'], @_);
  
  
  throw('Must provide a name argument') if ! defined $name;

  $self->{'name'} = $name;
  
  return $self;
}


=head2 name

  Example    : my $name = $exp_sset->name();
  Description: Getter for the name of this ExperimentalSubset.
  Returntype : string
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub name {
  my $self = shift;
  return $self->{'name'};
}





1;

