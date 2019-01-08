package Bio::EnsEMBL::Funcgen::Report::Generator;

use strict;
use Template;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Logger;

use Bio::EnsEMBL::Funcgen::GenericGetSetFunctionality qw(
  _generic_get_or_set
);

use Role::Tiny::With;
with 'Bio::EnsEMBL::Funcgen::GenericConstructor';

sub _constructor_parameters {
  return {
    species       => 'species',
    registry      => 'registry',
    output_file   => 'output_file',
  };
}

sub species        { return shift->_generic_get_or_set('species',       @_); }
sub registry       { return shift->_generic_get_or_set('registry',      @_); }
sub output_file    { return shift->_generic_get_or_set('output_file',   @_); }
sub logger         { return shift->_generic_get_or_set('logger',        @_); }

sub init {

  my $self = shift;
  my $logger = Bio::EnsEMBL::Utils::Logger->new;
  $self->logger($logger);
  return;
}

sub template_dir {
  my $self = shift;
  return $self->template_base_dir;
}

sub template_base_dir {

  my $self = shift;
  
  my $file = __FILE__;
  use File::Basename qw( dirname basename );
  my $template_base_dir = dirname($file) . '/../../../../../templates';
  return $template_base_dir;
}

sub generate_report {

  my $self = shift;
  
  my $logger = $self->logger;
  
  $logger->init_log;
  
  $logger->info("Species:  " . $self->species . "\n");
  $logger->info("Registry: " . $self->registry . "\n");
  
  $self->_assert_template_exists;
  $self->_create_output_directory;
  $self->_load_registry;

  my $tt   = $self->_init_template_toolkit;
  my $data = $self->_data_for_template;
  
  my $output_file = $self->output_file;
  
  $logger->info("Writing report to $output_file\n");
  
  $tt->process(
      $self->template,
      $data,
      $self->output_file
  )
      || die $tt->error;

  $logger->info("Done.\n");
  $logger->finish_log;
  
  return;
}

sub _init_template_toolkit {

  my $self = shift;

  my $template_dir = $self->template_dir;
  
  my $tt = Template->new(
    ABSOLUTE     => 1,
    RELATIVE     => 1,
    INCLUDE_PATH => $template_dir,
  );
  return $tt;
}

sub _load_registry {

  my $self = shift;
  
  my $registry = $self->registry;
  Bio::EnsEMBL::Registry->load_all($registry);
}

sub _assert_template_exists {

  my $self = shift;
  
  my $template = $self->template;
  
  if (! -e $template) {
      die("Can't find $template");
  }
  return;
}

sub _create_output_directory {

  my $self = shift;
  
  my $output_file = $self->output_file;
  
  use File::Basename qw( dirname );
  my $output_directory = dirname($output_file);
  
  use File::Path qw( make_path );
  make_path( $output_directory );

  return;
}

sub _data_for_template {

  my $self = shift;

  my $static_content        = $self->_static_content;
  my $dynamic_content       = $self->_dynamic_content;
  my $in_template_functions = $self->_in_template_functions;
  
  my $combined = {
    %$static_content,
    %$dynamic_content,
    %$in_template_functions,
  };

  return $combined;
}

sub _in_template_functions {

  use Number::Format qw( format_number );

  my $de = new Number::Format(
      -thousands_sep   => ',',
      -decimal_point   => '.',
  );

  return {
  
    round_num => sub {
        my $number = shift;
        return sprintf("%.2f", $number);
    },
  
    time => sub {
      return "" . localtime
    },
  
    format_number => sub {
      my $number = shift;
      if (! defined $number) {
        return '-'
      }
      if ($number eq '') {
        return '-'
      }
      return $de->format_number($number);
    },
  };
}

sub _static_content {
  return {};
}

sub _dynamic_content {
  return {};
}

1;
