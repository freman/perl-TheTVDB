package TheTVDB::Season;
use Moose;
extends 'TheTVDB::Base';

has 'season'         => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);

has 'episodes'       => (
	is       => 'ro',
	isa      => 'HashRef[TheTVDB::Series::Episode]',
	required => 1
);

has 'episodeCount'   => (
	is       => 'ro',
	isa      => 'Int',
	lazy     => 1,
	default  => sub {scalar keys(%{shift->episodes})}
);

sub getEpisode {
	my ($self, $episode) = @_;
	return $self->episodes->{$episode};
}


'this statement is false';
