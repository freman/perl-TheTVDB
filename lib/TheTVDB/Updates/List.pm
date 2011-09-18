package TheTVDB::Updates::List;
use Moose;
extends 'TheTVDB::Base';

has 'series'     => (
	is         => 'ro',
	isa        => 'ArrayRef[TheTVDB::Updates::Series]'
);

has 'episode'    => (
	is         => 'ro',
	isa        => 'ArrayRef[TheTVDB::Updates::Episode]'
);


'this statement is false';
