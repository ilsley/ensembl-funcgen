=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2023] EMBL-European Bioinformatics Institute

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
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package TranscriptionFactorComplexTest;

use strict;
use warnings;

use Test::More;
use Test::Exception;

use parent qw(Bio::EnsEMBL::Funcgen::Test);

sub parameters :Test(setup) {
    my $self = shift;

    my $transcription_factor_adaptor =
        $self->{funcgen_db}->get_adaptor('TranscriptionFactor');

    my $components =
        $transcription_factor_adaptor->fetch_all_by_dbID_list([ 33, 135 ]);

    my %mandatory_constructor_parameters = (
        '-production_name' => 'dummy_name',
        '-display_name'    => 'dummy::name',
        '-components'      => $components
    );

    $self->{mandatory_constructor_parameters} =
        \%mandatory_constructor_parameters;

    my %optional_constructor_parameters = ();

    my %constructor_parameters = (%mandatory_constructor_parameters,
                                  %optional_constructor_parameters);

    $self->{constructor_parameters} = \%constructor_parameters;
}

sub define_expected :Test(setup) {
    my $self = shift;

    my $transcription_factor_adaptor =
        $self->{funcgen_db}->get_adaptor('TranscriptionFactor');

    my $components =
        $transcription_factor_adaptor->fetch_all_by_dbID_list([ 33, 135 ]);

    $self->{expected} = {
        'production_name' => 'ETV2_CEBPD',
        'display_name'    => 'ETV2::CEBPD',
        'components'      => $components
    };
}

sub dbIDs_to_fetch {return [257];}

sub getters {
    return [ 'production_name', 'display_name', 'components' ];
}

1;