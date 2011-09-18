package TheTVDB::Updates::Series;
use Moose;
extends 'TheTVDB::Base::Update';

has 'detail'       => (
	is       => 'ro',
	isa      => 'TheTVDB::Series::Detail',
	lazy     => 1,
	default  => sub {
		my $self = shift;
		return $self->tvdb->getSeries($self->id);
	}
);


'this statement is false';
