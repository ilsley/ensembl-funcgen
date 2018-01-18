=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

  create_funcgen_db

=head1 SYNOPSIS

  Work in Progress

=head1 DESCRIPTION

  Creates a funcgen database with a few records. Written with the intent to
  create a testDB

=head1 METHODS

=cut



use strict;
use warnings;
use feature qw(say);

use Data::Dumper::Concise;
local $Data::Dumper::Sortkeys = 1;
local $Data::Dumper::Indent = 2;
use Pod::Usage;
use Getopt::Long;

use Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor;


main();

sub main {
  my $self = bless({}, __PACKAGE__);
  $self->parse_options();
  $self->get_db_adaptors('src');
  $self->create_empty_funcgen_db();
  $self->get_features();
  $self->create_dest_dnadb();
  $self->get_db_adaptors('dst');
  $self->store_features();
}



sub parse_options {
  my ($self) = @_;

  my $opts = {
  ro_usr         => 'ensro',
  rw_usr         => 'ensadmin',
  rw_pass        => 'ensembl',

  src_host       => 'mysql-ens-reg-prod-1.ebi.ac.uk',
  src_port       => 4526,
  src_dbname     => 'tj1_homo_sapiens_funcgen_92_38',

  src_dna_host   => 'mysql-ens-sta-1.ebi.ac.uk',
  src_dna_port   => 4519,
  src_dna_dbname => 'homo_sapiens_core_92_38',

  dst_host       => 'mysql-ens-reg-prod-1.ebi.ac.uk',
  dst_port       => 4526,
  dst_dbname     => 'tj1test_homo_sapiens_funcgen_92_38',

  dst_dna_host   => 'mysql-ens-reg-prod-1.ebi.ac.uk',
  dst_dna_port   => 4526,
  dst_dna_dbname => 'tj1test_homo_sapiens_core_92_38',

  species => 'homo_sapiens',
  features => 'all',
  clone_core => '/homes/juettema/src/ensembl-test/scripts/clone_core_database.pl',
  };

  GetOptions($opts, qw/
    ro_usr=s
    rw_usr=s
    rw_pass=s

    src_host=s
    src_port=i
    src_dbname=s

    src_dna_host=s
    src_dna_port=i
    src_dna_dbname=s

    dst_host=s
    dst_port=i
    dst_dbname=s

    dst_dna_host=s
    dst_dna_port=i
    dst_dna_dbname=s

    species=s
    clone_core=s
    features=s

    help
    man
  /) or pod2usage(-msg => 'Misconfigured options given', -verbose => 1, -exitval => 1);
  pod2usage(-verbose => 1, -exitval => 0) if $opts->{help};
  pod2usage(-verbose => 2, -exitval => 0) if $opts->{man};
  return $self->{opts} = $opts;
}



=head2 create_empty_funcgen_db

  Arg [1]    : None
  Description: Creates an empty funcgen DB based on the schema of the source DB
  Exceptions : SQL errors
  Returntype : None
  Caller     : Self
  Status     : Stable

=cut

sub create_empty_funcgen_db {
  my ($self) = @_;
  my $o = $self->{opts};

  my $mysql_src    = "--host $o->{src_host} --port $o->{src_port} --user $o->{ro_usr}";
  my $mysql_src_db = "$o->{src_dbname}";
  my $mysql_dst    = "--host $o->{dst_host} --port $o->{dst_port} --user $o->{rw_usr} --password=$o->{rw_pass}";
  my $mysql_dst_db = "$o->{dst_dbname}";

  say '>' x 30 . '  '. (caller(0))[3] .'  ' .'<' x 30;
  say "COPY <$mysql_src_db> FROM <$o->{src_host}> TO <$mysql_dst_db> ON <$o->{dst_host}>";

  my $cmd = '';
  $cmd = "mysql $mysql_dst -se 'DROP DATABASE IF EXISTS $mysql_dst_db'";
  _execute($cmd);
  $cmd = "mysql $mysql_dst -se 'CREATE DATABASE $mysql_dst_db'";
  _execute($cmd);
  $cmd = "mysqldump $mysql_src --no-data $mysql_src_db | sed -e 's/ AUTO_INCREMENT=[0-9]\*//' | mysql $mysql_dst $mysql_dst_db";
  _execute($cmd);

  my @tables = qw{
    analysis
    analysis_description
    epigenome
    experiment
    experimental_group
    external_db
    feature_type
    meta
    meta_coord
    regulatory_build
    example_feature
  };

  foreach my $table (@tables){
    say "Copying $table";
    $cmd = "mysqldump $mysql_src $mysql_src_db $table | sed -e 's/ AUTO_INCREMENT=[0-9]\*//'  | mysql $mysql_dst $mysql_dst_db";
    _execute($cmd);
  }
  say '!' x 30 . '  '. (caller(0))[3] .'  ' .'!' x 30;
}

=head2 _execute

  Arg [1]    : Command to be executed
  Description: Prints and execute system call e
               Exit value of the subprocess is ($?>> 8 ),
               Singal (if any) the process died from is ($? & 127) ,
               Core dump (if any) is ()$? & 128)
  Exceptions : Errors caused by the child process
  Returntype : See description
  Caller     : Self
  Status     : Stable

=cut

sub _execute {
  my ($cmd) = @_;

  say $cmd;
  system($cmd);

  if ($? == -1) {
       print "failed to execute: $!\n";
   }
   elsif ($? & 127) {
       printf "child died with signal %d, %s coredump\n",
           ($? & 127),  ($? & 128) ? 'with' : 'without';
   }
   else {
       printf "child exited with value %d\n", $? >> 8;
   }
}

=head2 get_features

  Arg [1]    : get_features
  Description:
  Exceptions :
  Returntype :
  Status     :

=cut

sub get_features {
  my ($self) = @_;
  say '>' x 30 . '  '. (caller(0))[3] .'  ' .'<' x 30;
# ToDo: Check: Duplicated call, same done in get_db_adaptors
  my @all_example_features = @{ $self->{src_a}->{ExampleFeature}->fetch_all};
  if($self->{opts}->{features} eq 'all'){
    foreach my $ef (@all_example_features) {
      my $table = $ef->ensembl_object_type;
      my $id   = $ef->ensembl_id;
      my $feature = $self->{src_a}->{$table}->fetch_by_dbID($id);
      if($feature->can('slice')){
        push(@{$self->{feature_slice_objects}}, $feature);
      }
      push(@{$self->{features}->{$table}}, $feature);
    }
  }
}


=head2 store_features

  Arg [1]    :
  Description: Stores the example RegulatoryFeature in the target DB. It does
               so by removing the old adaptor and then calling store. Note that
               the method relies on that the basic tables have been copied before.
  Exceptions : None
  Returntype : None
  Status     : Stable

=cut

sub store_features {
  my ($self) = @_;

  say '>' x 30 . '  '. (caller(0))[3] .'  ' .'<' x 30;
  foreach my $table (reverse sort keys %{$self->{features}}){
    say '*' x10 . " Table: $table " . '*' x 10;
    for my $feature ( @{$self->{features}->{$table}} ){
      say "\tID: ". $feature->dbID;
      $feature->{adaptor} = undef;
      $feature->{dbID} = undef;
      $self->{dst_a}->{$table}->store($feature);
    }
  }

#  my $rf = $self->{rf};
#  $rf->{adaptor} = {};
#  $self->{dst_a}->{rf}->store($rf);


}


#ToDo: May need specific transcripts for Tarbase
=head2

  Arg [1]    :
  Description: https://www.ebi.ac.uk/seqdb/confluence/display/ENSCORE/Creating+a+test+database
  Exceptions :
  Returntype :
  Status     : Stable

=cut

sub create_dest_dnadb {
  my ($self) = @_;

  say '>' x 30 . '  '. (caller(0))[3] .'  ' .'<' x 30;
  my $o       = $self->{opts};
  my $obj     = $self->{feature_slice_objects};
  my $species = $o->{species};

  my @regions;
  foreach my $o (@{$obj}){
    my $seq_region_name = $o->seq_region_name;
    my $start           = $o->start;
    my $end             = $o->end;
    my $string = "[\"$seq_region_name\", $start, $end]";
    push (@regions, $string);
  }

  my $region = join(',', @regions);
  my $core_json= qq{
    {
      "$species" : {
        "core" : {
          "regions" : [
            $region
          ],
          "adaptors" : [
            { "name" : "transcript", "method" : "fetch_all_by_Slice"},
            { "name" : "gene",       "method" : "fetch_all_by_Slice"},

          ]
        }
      }
    }

  };
  #Could be tmp file
  my $file_json = 'clone_core.json';
  open my $fh_out, '>', $file_json or die "$!";
    say $fh_out $core_json;
  close($fh_out);

  my $cmd = $o->{clone_core};
  $cmd .=  ' -json '        . $file_json;
  $cmd .=  ' -host '        . $o->{src_dna_host};
  $cmd .=  ' -port '        . $o->{src_dna_port};
  $cmd .=  ' -user '        . $o->{ro_usr};
  $cmd .=  ' -dbname '      . $o->{src_dna_dbname};
  $cmd .=  ' -dest_host '   . $o->{dst_host};
  $cmd .=  ' -dest_port '   . $o->{dst_port};
  $cmd .=  ' -dest_dbname ' . $o->{dst_dna_dbname};
  $cmd .=  ' -dest_user '   . $o->{rw_usr};
  $cmd .=  ' -dest_pass '   . $o->{rw_pass};
  $cmd .=  ' -species '     . $species;

 _execute($cmd);
}

=head2 get_db_adaptors

  Arg [1]    :
  Description: Creates the adaptors based on ExampleFeature table
  Exceptions :
  Returntype :
  Caller     :
  Status     : Stable

=cut

sub get_db_adaptors {
  my ($self, $type) = @_;

  if($type ne 'src' and $type ne 'dst') {
    die "Type must be src or dst";
  }
  my $o = $self->{opts};

  my $dnadb_a =  new Bio::EnsEMBL::DBSQL::DBAdaptor(
      -host    => $o->{$type.'_dna_host'},
      -user    => $o->{ro_usr},
      -port    => $o->{$type.'_dna_port'},
      -dbname  => $o->{$type.'_dna_dbname'},

      );

  my $db_a =  new Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor(
      -host    => $o->{$type.'_host'},
      -user    => $o->{rw_usr},
      -pass    => $o->{rw_pass},
      -port    => $o->{$type.'_port'},
      -dbname  => $o->{$type.'_dbname'},
      -dnadb   => $dnadb_a,
      );

  my $adaptors  = $db_a->get_available_adaptors;
  $self->{$type.'_a'}->{ExampleFeature} = $db_a->get_ExampleFeatureAdaptor;

  my @all_example_features = @{ $self->{$type.'_a'}->{ExampleFeature}->fetch_all};
  my %unique = map { $_->ensembl_object_type => $adaptors->{$_->ensembl_object_type}  } @all_example_features;

  foreach my $table (sort keys %unique){
    my $method = 'get_'.$table.'Adaptor';
    $self->{$type.'_a'}->{$table} = $db_a->$method;
  }

}
