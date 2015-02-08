package App::AutoCRUD::View::Json;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'App::AutoCRUD::View';

use JSON;
use namespace::clean -except => 'meta';

has 'json_args' => ( is => 'bare', isa => 'HashRef',
                     default => sub {{pretty => 1}} );


sub render {
  my ($self, $data, $context) = @_;

  my $json_maker = JSON->new(%{$self->{json_args}});
  my $output = $json_maker->encode($data);

  return [200, ['Content-type' => 'application/json; charset=UTF-8'],
               [$output] ];
}

1;


__END__



