package TheTVDB::Series;
use Moose;
extends 'TheTVDB::Base';

has 'id'         => (
	is         => 'ro',
	isa        => 'Int',
	required   => 1
);

has 'language'   => (
	is         => 'ro',
	isa        => 'Str',
	required   => 1
);

has 'name'       => (
	is         => 'ro',
	isa        => 'Str',
	required   => 1
);

has 'overview'   => (
	is         => 'ro',
	isa        => 'Maybe[Str]',
);

has 'firstAired' => (
	is         => 'ro',
	isa        => 'TheTVDB::Type::DateTime',
	coerce     => 1,
);

has 'detail'     => (
	is         => 'ro',
	isa        => 'TheTVDB::Series::Detail',
	lazy       => 1,
	default    => sub {
		my $self = shift;
		$self->tvdb->getSeries($self);
	}
);



sub getEpisode {
	my $self = shift;
	return $self->tvdb->getEpisode(series => $self, @_);
}


'this statement is false';
