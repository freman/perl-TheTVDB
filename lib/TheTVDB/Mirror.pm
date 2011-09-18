package TheTVDB::Mirror;
use Moose;
extends 'TheTVDB::Base';

has 'path'           => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'typemask'       => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);

has 'hasXmlFiles'    => (
	is       => 'ro',
	isa      => 'Int',
	lazy     => 1,
	default  => sub {(shift->typemask & 1) == 1}
);

has 'hasBannerFiles' => (
	is       => 'ro',
	isa      => 'Int',
	lazy     => 1,
	default  => sub {(shift->typemask & 2) == 2}
);

has 'hasZipFiles'    => (
	is       => 'ro',
	isa      => 'Int',
	lazy     => 1,
	default  => sub {(shift->typemask & 4) == 4}
);


'this statement is false';
