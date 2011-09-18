package TheTVDB::Series::Episode;
use Moose;
extends 'TheTVDB::Base::Detail';

my %episodeElementMap = (
	id            => 'id',
	EpisodeNumber => 'number',
	EpisodeName   => 'name',
	FirstAired    => 'firstAired',
	Language      => 'language',
	Overview      => 'overview',
	IMDB_ID       => 'imdbId',
	lastupdated   => 'lastUpdated',
	GuestStars    => 'guestStars',
	Director      => 'director',
	Writer        => 'writer',
	ProductionCode => 'productionCode',
	DVD_discid    => 'dvdDiscId',
	DVD_season    => 'dvdSeason',
	DVD_episodenumber => 'dvdEpisodeNumber',
	DVD_Chapter   => 'dvdChapter',
	SeasonNumber  => 'season',
	seasonid      => 'seasonId',
	seriesid      => 'seriesId',
);

has 'seriesId'     => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'series'       => (
	is       => 'ro',
	isa      => 'TheTVDB::Series::Detail',
	lazy     => 1,
	default  => sub {
		my $self = shift;
		$self->tvdb->getSeries($self->seriesId);
	}
);

has 'seasonId'     => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'season'       => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'number'       => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'guestStars'   => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'director'     => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'writer'       => (
	is       => 'ro',
	isa      => 'TheTVDB::Type::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'productionCode' => (
	is       => 'ro',
	isa      => 'Maybe[Int|Str]',
);

has 'dvdDiscId'    => (
	is       => 'ro',
	isa      => 'Maybe[Num|Str]', # seriously, who types "disc 1"
);

has 'dvdSeason'    => (
	is       => 'ro',
	isa      => 'Maybe[Num]',
);

has 'dvdEpisodeNumber' => (
	is       => 'ro',
	isa      => 'Maybe[Num]',
);

has 'dvdChapter'    => (
	is       => 'ro',
	isa      => 'Maybe[Num]',
);

has 'absoluteNumber'    => (
	is       => 'ro',
	isa      => 'Maybe[Int]',
);

has 'image'    => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

sub importFromXML {
	my ($class, %args) = @_;
	my %callArgs = ();

	my $xml       = $args{xml};
	my $episodeID = $args{episodeID};

	while (my ($xname, $local) = each (%episodeElementMap)) {
		$callArgs{$local} = $xml->{$xname} if defined $xml->{$xname};
	}

	$callArgs{tvdb}     = $args{tvdb};
	$callArgs{id}       //= $episodeID;
	$callArgs{seriesId} = $args{seriesId} if $args{seriesId};
	$callArgs{series}   = $args{series} if $args{series};

	return $class->new(%callArgs);
}

1;