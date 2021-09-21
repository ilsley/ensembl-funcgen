#!/usr/bin/env perl

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <ensembl-dev@ebi.ac.uk>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

  generate_frip_report.pl \
    --registry /homes/mnuhn/work_dir_regbuild_testrun/lib/ensembl-funcgen/registry.with_previous_version.human_regbuild_testdb16.pm \
    --species homo_sapiens \
    --output_file ./test/frip.html

=cut

use strict;
use Getopt::Long;

my %options;
GetOptions (
    \%options,
    "species|s=s",
    "registry|r=s",
    "output_file|o=s",
 );

my $species     = $options{'species'};
my $registry    = $options{'registry'};
my $output_file = $options{'output_file'};

use Bio::EnsEMBL::Funcgen::Report::Frip;
my $frip_report = Bio::EnsEMBL::Funcgen::Report::Frip->new(
  -species      => $species,
  -registry     => $registry,
  -output_file  => $output_file,
);

$frip_report->generate_report;
