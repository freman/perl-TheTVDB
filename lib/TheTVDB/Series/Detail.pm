package TheTVDB::Series::Detail;
use Moose;
extends 'TheTVDB::Base::Detail';

has 'actors'        => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'contentRating' => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'genre'         => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'zap2itId'      => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'language'      => (
	is       => 'ro',
	isa      => 'Str',
	required => 1
);

has 'network'       => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'runtime'       => (
	is       => 'ro',
	isa      => 'Maybe[Int]',
);

has 'status'        => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'banner'        => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'fanArt'        => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'poster'        => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'detail'        => (
	is       => 'ro',
	isa      => 'TheTVDB::Series::Detail',
	lazy     => 1,
	default  => sub {shift}
);

has 'seasons' => (
	is       => 'ro',
	isa      => 'HashRef[TheTVDB::Season]',
	lazy     => 1,
	default  => sub {
		my $self = shift;

		my $allXML = $self->tvdb->_downloadXML('/series/' . $self->id . '/all/en.xml');
		$allXML->{Episode} = {$allXML->{Episode}->{id} => $allXML->{Episode}} if $allXML->{Episode}->{id};

		my %seasons = ();
		foreach my $episodeID (keys %{$allXML->{Episode}}) {
			my $episode = TheTVDB::Series::Episode->importFromXML(
				tvdb      => $self->tvdb,
				xml       => $allXML->{Episode}->{$episodeID},
				episodeID => $episodeID,
				seriesID  => $self->id,
				series    => $self
			);

			$seasons{$episode->season} //= {};
			$seasons{$episode->season}->{$episode->number} = $episode;
		}


		return {map {($_ => TheTVDB::Season->new(tvdb => $self->tvdb, season => $_, episodes => $seasons{$_}))} keys %seasons};
	}
);

has 'seasonCount' => (
	is       => 'ro',
	isa      => 'Int',
	lazy     => 1,
	default  => sub {scalar keys(%{shift->seasons})}
);

sub getSeason {
	my ($self, $season) = @_;
	return $self->seasons->{$season};
}

sub getEpisode {
	my $self = shift;
	return $self->tvdb->getEpisode(series => $self, @_);
}


'this statement is false';
