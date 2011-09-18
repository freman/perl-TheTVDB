package TheTVDB::Updates::Episode;
use Moose;
extends 'TheTVDB::Base::Update';

has 'series'       => (
	is       => 'ro',
	isa      => 'TheTVDB::Series::Detail',
	lazy     => 1,
	default  => sub {
		my $self = shift;
		return $self->tvdb->getSeries($self->seriesId);
	}
);

has 'seriesId'     => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);

has 'detail'       => (
	is       => 'ro',
	isa      => 'TheTVDB::Series::Episode',
	lazy     => 1,
	default  => sub {
		my $self = shift;
		return $self->tvdb->getEpisode(episode => $self->id);
	}
);


'this statement is false';
