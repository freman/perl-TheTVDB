package TheTVDB::Base::Detail;
use Moose;
extends 'TheTVDB::Base';

has 'id'            => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'firstAired'    => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::DateTime',
	coerce   => 1,
);

has 'lastUpdated'   => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::DateTime',
	coerce   => 1,
);

has 'overview'      => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'name'          => (
	is       => 'ro',
	isa      => 'Str',
	required => 1
);

has 'imdbId'        => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);


'this statement is false';
