=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <ensembl-dev@ebi.ac.uk>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

package Bio::EnsEMBL::Funcgen::Parsers::BaseExternalParser;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw( throw );
use Bio::EnsEMBL::Funcgen::FeatureSet;
use Bio::EnsEMBL::Funcgen::FeatureType;
use Bio::EnsEMBL::Analysis;
#use Bio::EnsEMBL::Funcgen::Parsers::BaseImporter;
#use vars qw(@ISA)
#@ISA = ('Bio::EnsEMBL::Funcgen::Utils::Helper');

use base qw(Bio::EnsEMBL::Funcgen::Parsers::BaseImporter); #@ISA change to parent with perl 5.10



# Base functionality for external_feature parsers

#Make this inherit from Helper?
#Then change all the prints to logs

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;
  my $self = $class->SUPER::new(@_);

  #validate and set type, analysis and feature_set here
  my ($type, $db, $clobber, $archive, $import_fsets) = rearrange(['TYPE', 'DB', 'CLOBBER', 'ARCHIVE', 'IMPORT_SETS'], @_);
  
  throw('You must define a type of external_feature to import') if(! defined $type);

  if (! ($db && ref($db) &&
		 $db->isa('Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor'))){
	throw('You must provide a valid Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor');
  }

  throw('You can only specify either -clobber or -archive, but not both') if($clobber && $archive);

  $self->{'display_name_cache'} = {};
  $self->{'db'} = $db;
  $self->{type} = $type;
  $self->{'clobber'} = $clobber if defined $clobber;
  $self->{'archive'} = $archive if defined $archive;


  #This is not fully implemented yet and need to be validated against the config feature_set
  #pass something like set1,set2 and split and validate each.
  #Or do this in the calling script?

  throw('-import_sets not fully implemented yet') if defined $import_fsets;
  $self->{'import_sets'} = (defined $import_fsets) ? @{$import_fsets} : undef;
  
  $self->log("Parsing and loading $type ExternalFeatures");

  return $self;

}


=head2 db

  Args       : None
  Example    : my $feature_set_adaptor = $seld->db->get_FeatureSetAdaptor
  Description: Getter for the DBAdaptor.
  Returntype : Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor
  Exceptions : None
  Caller     : General
  Status     : Medium Risk

=cut

sub db{
  my $self = shift;

  return $self->{'db'};
}

=head2 import_sets

  Args       : None
  Example    : foreach my $import_set_name(@{$self->import_sets}){ ... do the import ... }
  Description: Getter for the list of import feature set names, defaults to all in parser config.
  Returntype : Arrayref of import feature_set names
  Exceptions : None
  Caller     : General
  Status     : Medium Risk

=cut

sub import_sets{
  my $self = shift;

  return $self->{'import_sets'} || [keys %{$self->{static_config}{feature_sets}}];
}


=head2 set_feature_sets

  Args       : None
  Example    : $self->set_feature_sets;
  Description: Imports feature sets defined by import_sets.
  Returntype : None
  Exceptions : Throws if feature set already present and clobber or archive not set
  Caller     : General
  Status     : Medium Risk

=cut

#This is done after validate and store feature_types
#Updating this will require making all external parsers use 'static_config'

sub set_feature_sets{
  my $self = shift;

  throw('Must provide a set feature_set config hash') if ! defined $self->{static_config}{feature_sets};


  my $fset_adaptor = $self->db->get_FeatureSetAdaptor;
  my $analysis_adaptor = $self->db->get_AnalysisAdaptor;
  
  foreach my $fset_name(@{$self->import_sets}){

	$self->log("Defining FeatureSet:\t$fset_name");  
	my $fset = $fset_adaptor->fetch_by_name($fset_name);

	#we don't need data sets for external_feature sets!
	#Compare against config after we have merged with defined_anld_validate etc

	if(defined $fset){
	  $self->log("Found previous FeatureSet $fset_name");

	  if($self->{'clobber'}){

		$self->rollback_FeatureSet($fset);#Need to pass \@slices here?
	  }
	  elsif($self->{'archive'}){
		my $archive_fset =  $fset_adaptor->fetch_by_name($fset_name."_v".$self->{'archive'});

		if(defined $archive_fset){
		  throw("You are trying to create an archive external feature_set which already exists:\t${fset_name}_v".$self->{archive});
		}

		my $sql = "UPDATE feature_set set name='$fset_name}_v".$self->{archive}."' where name='$fset_name'";
		$self->db->dbc->do($sql);
		undef $fset;
	  }else{
		throw("You are trying to create an external feature_set which already exists:\t$fset_name\nMaybe to want to clobber or archive?");
	  }
	}

	#Assume using static config for now
	#Will need to resolve this when it become generic
	#Maybe we set outside of config!
	#simply as analyses, feature_sets and feature_types?
	my $fset_config = 	$self->{static_config}{feature_sets}{$fset_name}{feature_set};


	if(! defined $fset){
	  my ($name, $analysis, $ftype, $display_label, $desc);	  
	  my $fset_analysis_key = (exists ${$fset_config}{-analysis})      ? '-analysis'      : '-ANALYSIS';
	  my $fset_name_key     = (exists ${$fset_config}{-name})          ? '-name'          : '-NAME';
	  my $fset_ftype_key    = (exists ${$fset_config}{-feature_type})  ? '-feature_type'  : '-FEATURE_TYPE';
	  my $fset_dlabel_key   = (exists ${$fset_config}{-display_label}) ? '-display_label' : '-DISPLAY_LABEL';
	  my $fset_desc_key     = (exists ${$fset_config}{-description})   ? '-description'   : '-DESCRIPTION';
	  my $display_name      = (exists ${$fset_config}{$fset_dlabel_key}) ? $fset_config->{$fset_dlabel_key} : $fset_name;
	  #fset config name be different from key name
	  my $fs_name           = (exists ${$fset_config}{$fset_name_key}) ? $fset_config->{$fset_name_key} : $fset_name;
	  #warn if they are different?
	  
	  
	  #Can't just deref config hash here as we need to deref the nested feature_type and analysis attrs
	  
	  $fset = Bio::EnsEMBL::Funcgen::FeatureSet->new(
													 -name         => $fs_name,
													 -feature_class=> 'external',
													 -analysis     => ${$fset_config->{$fset_analysis_key}},
													 -feature_type => ${$fset_config->{$fset_ftype_key}},
													 -display_label => $display_name,
													 -description   => $fset_config->{$fset_desc_key}
													);

	  ($fset) = @{$self->db->get_FeatureSetAdaptor->store($fset)};
	}

	#Now replace config hash with object
	#Will this reset in hash or just locally?
	#$fset_config = $fset;
	$self->{static_config}{feature_sets}{$fset_name}{feature_set} = $fset;
  }

  return;
}

#Can't use this anymore as we have to use static_config for all parsers which use set_feature_sets

#
#=head2 validate_and_store_feature_types
#
#  Args       : None
#  Example    : $self->validate_and_store_feature_types;
#  Description: Imports feature types defined by import_sets.
#  Returntype : None
#  Exceptions : None
#  Caller     : General
#  Status     : High Risk - Now using BaseImporter::validate_and_store_config for vista
#
#=cut
#
##Change all external parsers to use BaseImporter::validate_and_store_config
#
#sub validate_and_store_feature_types{
#  my $self = shift;
#
#  #This currently only stores ftype associated with the feature_sets
#  #Havent't we done this already in the InputSet parser
#  #Need to write BaseImporter and inherit from there.
#
#  #InputSet does all loading, but depends on 'user_config'
#  #Where as we are using hardcoded config here
#  #Which are import_sets currently defaults to feature_sets keys
#
#  #we could simply call this static_config and let user_config over-write static config with warnings?
#  #on an key by key basis? (top level only?)
#
#
#  my $ftype_adaptor = $self->db->get_FeatureTypeAdaptor;
#
#  foreach my $import_set(@{$self->import_sets}){
#
#	my $ftype_config = ${$self->{static_config}{feature_sets}{$import_set}{feature_type}};
#	my $ftype = $ftype_adaptor->fetch_by_name($ftype_config->{'name'});
#
#	$self->log("Validating $import_set FeatureType:\t".$ftype_config->{'name'});
#
#	if(! defined $ftype){
#	  $self->log("FeatureType '".$ftype_config->{'name'}."' for external feature_set ".$self->{'type'}." not present");
#	  $self->log("Storing using type hash definitions");
#	
#	  $ftype = Bio::EnsEMBL::Funcgen::FeatureType->new(
#													   -name => $ftype_config->{'name'},
#													   -class => $ftype_config->{'class'},
#													   -description => $ftype_config->{'description'},
#													  );
#	  ($ftype) = @{$ftype_adaptor->store($ftype)};
#	}
#
#	#Replace hash config with object
#	$self->{static_config}{feature_types}{$ftype_config->{'name'}} = $ftype;
#  }
#
#  return;
#}
#






=head2 project_feature

  Args [0]   : Bio::EnsEMBL::Feature
  Args [1]   : string - Assembly e.g. NCBI37
  Example    : $self->project($feature, $new_assembly);
  Description: Projects a feature to a new assembly via the AssemblyMapper
  Returntype : Bio::EnsEMBL::Feature
  Exceptions : Throws is type is not valid.
  Caller     : General
  Status     : At risk - is this in core API? Move to Utils::Helper?

=cut



# --------------------------------------------------------------------------------
# Project a feature from one slice to another
sub project_feature {
  my ($self, $feat, $new_assembly) = @_;

  # project feature to new assembly
  my $feat_slice = $feat->feature_Slice;


  if(! $feat_slice){
	throw('Cannot get Feature Slice for '.$feat->start.':'.$feat->end.':'.$feat->strand.' on seq_region '.$feat->slice->name);
  }

  my @segments = @{ $feat_slice->project('chromosome', $new_assembly) };

  if(! @segments){
	$self->log("Failed to project feature:\t".$feat->display_label);
	return;
  }
  elsif(scalar(@segments) >1){
	$self->log("Failed to project feature to distinct location:\t".$feat->display_label);
	return;
  }

  my $proj_slice = $segments[0]->to_Slice;
  
  if($feat_slice->length != $proj_slice->length){
	$self->log("Failed to project feature to comparable length region:\t".$feat->display_label);
	return;
  }


  # everything looks fine, so adjust the coords of the feature
  $feat->start($proj_slice->start);
  $feat->end($proj_slice->end);
  $feat->strand($proj_slice->strand);
  my $slice_new_asm = $self->slice_adaptor->fetch_by_region('chromosome', $proj_slice->seq_region_name, undef, undef, undef, $new_assembly);
  $feat->slice($slice_new_asm);

  return $feat;

}

sub slice_adaptor{
  my $self = shift;

  if(! defined $self->{'slice_adaptor'}){
	$self->{'slice_adaptor'} = $self->db->get_SliceAdaptor;
  }
  
  return $self->{'slice_adaptor'};
}


1;
