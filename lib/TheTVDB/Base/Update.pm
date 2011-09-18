package TheTVDB::Base::Update;
use Moose;
extends 'TheTVDB::Base';

has 'id'         => (
	is         => 'ro',
	isa        => 'Int',
	required   => 1
);

has 'time'       => (
	is         => 'ro',
	isa        => 'TheTVDB::Type::DateTime',
	coerce     => 1
);


'this statement is false';
