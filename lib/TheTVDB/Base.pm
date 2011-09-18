package TheTVDB::Base;
use Moose;

has 'tvdb'    => (
	is       => 'ro',
	isa      => 'TheTVDB',
	required => 1,
);


'this statement is false';
