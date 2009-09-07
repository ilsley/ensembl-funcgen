=head1 NAME

Bio::Das::ProServer::SourceAdaptor::ensembl_funcgen_reads

=head1 DESCRIPTION

This is a SourceAdaptor module to retrieve raw read alignments and profiles.
Supports both standard and hydra implementation using the GenerateDASConfig function of the eFG environment.


=head1 LICENSE

  Copyright (c) 1999-2009 The European Bioinformatics Institute and
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

package Bio::Das::ProServer::SourceAdaptor::ensembl_funcgen_reads;

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);


#To Do
# Move transport stuff to transport? This module should only be for config parsing and display functions
# Integrate colour ini file parsing from webcode to use same default colours as web display for different
# feature types.

sub init {
    my $self                = shift;
    $self->{'capabilities'} = {
        'features' => '1.0',
        'stylesheet' => '1.0',
    };
    $self->{'dsnversion'} = '1.1';
    #$self->{'coordinates'} = {
    #	'http://www.dasregistry.org/dasregistry/coordsys/CS_DS40' => '7:140079754,140272033'
    #};
	
	my %valid_data_formats = (
							  reads   => 1,#can we make this more useful?
							  profile => 1,
							 );
	
	#Should check transport here?

	if(defined $self->hydra){
	  #Set title based on table name
 	  #This need to be generic for standard and hydra source

	  my $hydra_name = $self->config->{'hydraname'};
	  my $full_name = $self->dsn;	  
	  #Leave dsn as is?
	  #Causes failure when querying
	  ($self->{'title'} = $full_name) =~ s/${hydra_name}_//;
	  #reconstitute table name here
	  $self->{'table_name'} = $self->config->{'basename'}.'_'.$self->{'title'};


	  #This assumes first token of title is display/data type
	  #e.g. reads or profile
	  my $dtype = (split/_/, $self->{'title'})[0];
	  $self->{'title'} =~ s/${dtype}_//;
	  $self->{'description'} = $self->{'title'}.' '.$dtype;	
	  $self->{'title'} =  $self->{'title'}."_${dtype}";


	  #strip the trailing s if reads
	  #This is not really the DAS type, which is the type of annotation
	  #And is normally used to retrieve additional info from the annotation server
	  #Should we change this to the feature type name?

	  ($self->{'display_type'} = $dtype) =~ s/reads$/read/;


	  if(! exists $valid_data_formats{$dtype}){
		warn 'The table name '.$self->{'table_name'}.' does not specify a valid format ('.join(',', keys %valid_data_formats).')e.g. bed_reads_ES_DNase';
		return;
	  }
	  
	  #Can we set title to same name for two different types? e.g. reads or profile?
	  #Yes, so long as we set the description to differentiate between the two		
	  #$self->{'title'} =~ s/${dtype}_//;
	  #$self->{'description'} = $self->{'title'}.' '.$dtype;	
	  #No? It seems we may not be able to display two track with the same name???


	  #We need to be selective about the tables we use here
	  #Looks like default is to use all tables
	  #Need to set config basename as bed\_
	  #wild cards screw up dsn name generation so handle here instead
	}
	else{
	  #All the above should be set in the config
	}

#	warn "dsn is ".$self->dsn;
#	warn "title is ".$self->title;
#	warn "table_name is ".$self->{'table_name'};


	#Now set feature colour here based on feature_type

}

sub title {
    my $self = shift;

    return $self->{'title'};
}

sub build_features {
    my ($self, $opts) = @_;
    
    my $segment       = $opts->{'segment'};
    my $gStart        = $opts->{'start'};
    my $gEnd          = $opts->{'end'};

    ### using max bins
    #if( $opts->{'maxbins'} && $gStart && $gEnd) {
    #    return $self->merge_features($opts);
    #}

    my $dsn           = $self->{'dsn'};
    my $dbtable       =  $self->{'table_name'};#$dsn;
    #print Dumper $dbtable;
    
    #########
    # if this is a hydra-based source the table name contains the hydra name and needs to be switched out
    #
    #my $hydraname     = $self->config->{'hydraname'};
    #if ($hydraname) {
    #    my $basename = $self->config->{'basename'};
    #    $dbtable =~ s/$hydraname/$basename/;
    #}
  
  
    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qbounds       = qq(AND start <= '$gEnd' AND end >= '$gStart') if($gStart && $gEnd);
	#feature_id | seq_region | start   | end     | name                   | score | strand | note
    my $query         = qq(SELECT * FROM $dbtable WHERE  seq_region = $qsegment $qbounds); # ORDER BY start);
    my $ref           = $self->transport->query($query);
    my @features      = ();
    
    for my $row (@{$ref}) {

        my ($start, $end, $score) = ($row->{'start'}, $row->{'end'}, $row->{'score'});
        my $type;

		#Can we change this to use ori instead?
		#Remove type or use fill-in?
		
        if ($self->{'display_type'} eq 'profile') {
		  $type = 'profile_read';
		} 
		elsif ($self->{'display_type'} eq 'read') {
		  $type = $row->{'strand'} eq '+' ? 'forward' : 'reverse';
		  $type .= '_read';
		  $row->{'strand'} = '';#???? Populating this leads to display on +/-ve strand, we want it just on the -ve strand
        }
		#Not used anymore
		#else {
        #    $type = ($score > 0) ? 'uniq' : 'non-uniq';y
        #}
		

		#The less data we push here the quicker the display.
		#Omit method, label?

		push @features, {
            'id'          => $row->{'feature_id'},
            'label'       => $row->{'name'} !~ m/^.$/ ? $row->{'name'} : $row->{'feature_id'},
            #'method'      => $self->config->{'method'},
            'type'        => $type,#$self->{'type'},
            'typecategory'=> $self->config->{'category'} || 'sequencing',#required for style sheet
            'start'       => $row->{'start'},
            'end'         => $row->{'end'},
            'ori'         => $row->{'strand'},#Can we just set this to ''?
            'score'       => $row->{'score'},
            #'note' => [],
        };

    }    
   
    #warn "No. of features: ".scalar(@features)."\n";
    return @features;
}


#We need to define a base base_funcgen.pm which will have method to access colours dependant on 
#modification.
#This should mirror what the main site uses


sub das_stylesheet
{
    my $self = shift;


	#This should use a format or type config rather than the name

	#These need to use the same config as the reg feat panel
	#There fore we need to encode the feature type in the file name

    if ($self->{'dsn'} =~ m/_profile/) {
        return <<EOT;
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
    <STYLESHEET version="1.0">
 <CATEGORY id="sequencing">
            <TYPE id="profile_read">
                <GLYPH>
                    <TILING>
                        <LABEL>no</LABEL>
                        <HEIGHT>30</HEIGHT>
                        <COLOR1>brown4</COLOR1>
                        <MIN>0</MIN>
                        <MAX>15</MAX>
                    </TILING>
                </GLYPH>
            </TYPE>
 </CATEGORY>
    </STYLESHEET>
</DASSTYLE>
EOT

    } else {

	  #Can we use FARROW and RARROW here?
	  #These will set orientation, so will be displayed in separate tracks?
	  #SOUTHWEST & NORTHEAST define direction of arrow
	  #Can we harcode <ORIENTATION> here, will this override the feature ori? No it doesn't
	  #Turn off labels by default..this is not yet supported by the browser
	  #Do we need a default in here?
	  

        return <<EOT;
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
    <STYLESHEET version="1.0">
    <CATEGORY id="sequencing">
             <TYPE id="forward_read">
                <GLYPH>
                    <ARROW>
                        <LABEL>no</LABEL>
                        <HEIGHT>10</HEIGHT>
                        <FGCOLOR>black</FGCOLOR>
                        <BUMP>1</BUMP>
                        <BAR_STYLE>full</BAR_STYLE>
                        <SOUTHWEST>no</SOUTHWEST>
                    </ARROW>
                </GLYPH>
            </TYPE>
            <TYPE id="reverse_read">
                <GLYPH>
                    <ARROW>
                        <LABEL>no</LABEL>
                        <HEIGHT>10</HEIGHT>
                        <FGCOLOR>darkgreen</FGCOLOR>
                        <BUMP>1</BUMP>
                        <BAR_STYLE>full</BAR_STYLE>
                        <NORTHEAST>no</NORTHEAST>
                    </ARROW>
                </GLYPH>
            </TYPE>
        </CATEGORY>
    </STYLESHEET>
</DASSTYLE>
EOT
    }
}

1;



