# TheTVDB - Basic TVDB API
#
# Copyright 2011 - Shannon Wynter (http://fremnet.net)
# This code is released under GPL3

# TODO: If seasons for a series has been called, look there rather than fetching again for episodes
package TheTVDB;

use Moose;
use Moose::Util::TypeConstraints;
use LWP;
use URI::Escape;
use XML::Simple;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;
our $VERSION = "0.1";

our $HAVEZIP = 0;
eval {require IO::Uncompress::Unzip; $HAVEZIP = 1};
warn "IO::Uncompress::Unzip not found, please install this perl module to save bandwidth\n" unless $HAVEZIP;

class_type 'DateTime';
subtype 'TheTVDB::DateTime' => as 'Maybe[DateTime]';
subtype 'TheTVDB::PipedList' => as 'Maybe[ArrayRef[Str]]';

coerce 'TheTVDB::DateTime'
	=> from 'Str'
		=> via {$_ =~ /^\d+$/ ? DateTime->from_epoch(epoch => $_) : strptime('%F', $_)}
	=> from 'Int'
		=> via {DateTime->from_epoch(epoch => $_)};

coerce 'TheTVDB::PipedList'
	=> from 'Str'
		=> via {$_ =~ s/^\||\|$//sg; [split(/\|/, $_)]};

has 'tvdb'     => (
	is       => 'ro',
	isa      => 'TheTVDB',
	lazy     => 1,
	default  => sub {shift}
);

has 'site'     => (
	is       => 'ro',
	isa      => 'Str',
	default  => 'http://www.thetvdb.com',
);

has 'session'  => (
	is       => 'ro',
	isa      => 'HashRef',
	default  => sub {{}},
);
has 'apikey'   => (
	is       => 'rw',
	isa      => 'Str',
	required => 1,
);

has 'language' => (
	is       => 'rw',
	isa      => 'Str',
	default  => 'en',
);

has 'ua'       => (
	is       => 'rw',
	isa      => 'LWP::UserAgent',
	lazy     => 1,
	default  => sub {
		my $ua = LWP::UserAgent->new;
		$ua->env_proxy();
		$ua->agent('TheTVDB/' . $VERSION);
		return $ua;
	}
);

has 'session'  => (
	is       => 'ro',
	isa      => 'HashRef',
	default  => sub { {} }
);

has 'mirrors' => (
	is       => 'ro',
	isa      => 'HashRef[ArrayRef[TheTVDB::Mirror]]',
	lazy     => 1,
	default  => sub {
		my $self = shift;
		my $hash = {xml => [], banner => [], zip => []};

		my $mirrorsXML = $self->_downloadXML('mirrors.xml', 0);

		# Fix single returns
		$mirrorsXML->{Mirror} = {$mirrorsXML->{Mirror}->{id} => $mirrorsXML->{Mirror}} if $mirrorsXML->{Mirror}->{id};

		my @mirrors = map {TheTVDB::Mirror->new(tvdb => $self, path => $_->{mirrorpath}, typemask => $_->{typemask})} values %{$mirrorsXML->{Mirror}};

		foreach my $mirror (@mirrors) {
			push @{$hash->{xml}}, $mirror if $mirror->hasXmlFiles;
			push @{$hash->{banner}}, $mirror if $mirror->hasBannerFiles;
			push @{$hash->{zip}}, $mirror if $mirror->hasZipFiles;
		}

		return $hash;
	}
);

has 'updates' => (
	is       => 'ro',
	isa      => 'TheTVDB::Updates',
	lazy     => 1,
	default  => sub {TheTVDB::Updates->new(tvdb => shift)}
);

my %seriesDetailElementMap = (
	id            => 'id',
	Actors        => 'actors',
	ContentRating => 'contentRating',
	FirstAired    => 'firstAired',
	Genre         => 'genre',
	Network       => 'network',
	Language      => 'language',
	Overview      => 'overview',
	IMDB_ID       => 'imdbId',
	Runtime       => 'runtime',
	SeriesName    => 'name',
	Status        => 'status',
	lastupdated   => 'lastUpdated',
	banner        => 'banner',
	fanart        => 'fanArt',
	poster        => 'poster',
	zap2it_id     => 'zap2itId',
);

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


sub _download {
	my ($self, $what, $usemirror) = @_;

	# API doesn't dictate key for any php access I noticed
	my $useKey = $what !~ /\.php/;

	# API doesn't dictate requirement to use mirror when not using key
	$usemirror //= $useKey;

	my $site = $self->site;
	if ($usemirror) {
		my $mirrorType = $what =~ /\.zip$/ ? 4 : ($what =~ /.xml$/ ? 1 : 2);
		$site = $self->mirror($mirrorType)->path;
	}

	my $url = $site . '/api/' . ($useKey ? $self->apikey . '/' : '') . $what;

	return $self->session->{$url} if defined $self->session->{$url};

	my $req = HTTP::Request->new(GET => $url);
	my $res = $self->ua->request($req);

	if (!$res->is_success || $res->decoded_content =~ /(?:404 Not Found|The page your? requested does not exist)/i) {
		$self->session->{$url} = 0;
		return undef;
	}
	$self->session->{$url} = $res->decoded_content;
	return $res->decoded_content;
}

sub _downloadXML {
	my ($self, $what, $usemirror) = @_;

	$what =~ s/xml$/zip/ if $HAVEZIP && $what =~ /(updates|all)\/.*\.xml$/;

	my $xml = $self->_download($what, $usemirror);
	return undef unless $xml;

	if ($what =~ /zip$/) {
		my %options = (
			Transparent => 1,
		);

		if ($what =~ /all/) {
			$options{Name} = 'en.xml';
		}

		my $zip = new IO::Uncompress::Unzip \$xml, %options or die "IO::Uncompress::Unzip failed: $what\n";
		local $/ = undef;
		$xml = <$zip>;
	}

	return XMLin($xml, SuppressEmpty => undef);
}

sub mirror {
	my ($self, $type) = @_;

	return undef unless $type && grep {$_ == $type} (1, 2, 4);

	return $self->{mirror}->{xml} ? $self->{mirror}->{xml} : ($self->{mirror}->{xml} = $self->mirrors->{xml}->[rand $#{$self->mirrors->{xml}}]) if $type == 1;
	return $self->{mirror}->{banner} ? $self->{mirror}->{banner} : ($self->{mirror}->{banner} = $self->mirrors->{banner}->[rand $#{$self->mirrors->{banner}}]) if $type == 2;
	return $self->{mirror}->{zip} ? $self->{mirror}->{zip} : ($self->{mirror}->{zip} = $self->mirrors->{zip}->[rand $#{$self->mirrors->{zip}}]) if $type == 4;
}

sub findSeriesByName {
	my ($self, $seriesName) = @_;

	my $seriesXML = $self->_downloadXML('GetSeries.php?seriesname=' . uri_escape($seriesName) . '&language=' . $self->language, 0);
	return undef unless $seriesXML;

	# Fix single depth series result
	$seriesXML->{Series} = {$seriesXML->{Series}->{id} => $seriesXML->{Series}} if $seriesXML->{Series}->{id};

	my @serieses = map {TheTVDB::Series->new(tvdb => $self, id => $_->{seriesid}, name => $_->{SeriesName}, language => $_->{language}, overview => $_->{Overview}, firstAired => $_->{FirstAired})} values %{$seriesXML->{Series}};

	return wantarray ? @serieses : \@serieses;
}

sub getSeries {
	my ($self, $series) = @_;

	if (ref $series) {
		return $series if ref $series eq 'TheTVDB::SeriesDetail';
		return undef unless ref $series eq 'TheTVDB::Series';
		$series = $series->id;
	}

	my $seriesXML = $self->_downloadXML('series/' . $series . '/' . $self->language . '.xml');
	return undef unless $seriesXML;

	my %args = ();
	while (my ($xml, $local) = each (%seriesDetailElementMap)) {
		$args{$local} = $seriesXML->{Series}->{$xml} if defined $seriesXML->{Series}->{$xml};
	}

	return TheTVDB::SeriesDetail->new(tvdb => $self, %args);
}

sub getEpisode {
	my ($self, %args) = @_;

	my $series;
	my $middleBit;
	if (defined $args{series}) {
		$series = $self->getSeries($args{series});

		if (defined $args{season} && defined $args{episode}) {
			my $pathBit = defined $args{dvd} ? 'dvd' : 'default';
			$middleBit = join '/', $pathBit, $args{season}, $args{episode};
		}
		elsif (defined $args{episode} || defined $args{absolute}) {
			$middleBit = join '/', 'absolute', $args{defined $args{episode} ? 'episode' : 'absolute'};
		}
		else {
			return undef;
		}
		$middleBit = 'series/' . $series->id . '/' . $middleBit;
	}
	elsif (defined $args{episode}) {
		return $args{episode} if ref $args{episode} eq 'TheTVDB::Series::Episode';
		$middleBit = 'episodes/' . $args{episode};
	}
	else {
		return undef;
	}

	my $episodeXML = $self->_downloadXML($middleBit . '/' . $self->language . '.xml');

	%args = ();
	while (my ($xml, $local) = each (%episodeElementMap)) {
		$args{$local} = $episodeXML->{Episode}->{$xml} if defined $episodeXML->{Episode}->{$xml};
	}
	$args{seriesId} = $series->id if $series;

	return new TheTVDB::Series::Episode(tvdb => $self, %args);
}


package TheTVDB::Base;
use Moose;

has 'tvdb'    => (
	is       => 'ro',
	isa      => 'TheTVDB',
	required => 1,
);

package TheTVDB::Updates;
use Moose;
extends 'TheTVDB::Base';

has 'day'     => (
	is      => 'ro',
	isa     => 'TheTVDB::Updates::List',
	lazy    => 1,
	default => sub {shift->_get_updates('day')}
);

has 'week'   => (
	is      => 'ro',
	isa     => 'TheTVDB::Updates::List',
	lazy    => 1,
	default => sub {shift->_get_updates('week')}
);

has 'week'   => (
	is      => 'ro',
	isa     => 'TheTVDB::Updates::List',
	lazy    => 1,
	default => sub {shift->_get_updates('month')}
);


sub _get_updates {
	my $tvdb = shift->tvdb;
	my $period = shift;
	my $updates = $tvdb->_downloadXML("/updates/updates_$period.xml");

	# Fix single depth series/episode result
	$updates->{Series}  = {$updates->{Series}->{id} => $updates->{Series}} if $updates->{Series}->{id};
	$updates->{Episode} = {$updates->{Episode}->{id} => $updates->{Episode}} if $updates->{Episode}->{id};

	my @series = map {
		TheTVDB::Update::Series->new(
			tvdb => $tvdb,
			id   => $_,
			time => $updates->{Series}->{$_}->{time}
		)
	} keys %{$updates->{Series}};

	my @episode = map {
		my $o = $updates->{Episode}->{$_};
		TheTVDB::Update::Episode->new(
			tvdb => $tvdb,
			id   => $_,
			seriesId => $o->{Series},
			time => $o->{time}
		)
	} keys %{$updates->{Episode}};

	return TheTVDB::Updates::List->new(tvdb => $tvdb, series => \@series, episode => \@episode);
}

package TheTVDB::Updates::List;
use Moose;
extends 'TheTVDB::Base';

has 'series'     => (
	is         => 'ro',
	isa        => 'ArrayRef[TheTVDB::Update::Series]'
);

has 'episode'    => (
	is         => 'ro',
	isa        => 'ArrayRef[TheTVDB::Update::Episode]'
);

package TheTVDB::Update;
use Moose;
extends 'TheTVDB::Base';

has 'id'         => (
	is         => 'ro',
	isa        => 'Int',
	required   => 1
);

has 'time'       => (
	is         => 'ro',
	isa        => 'TheTVDB::DateTime',
	coerce     => 1
);

package TheTVDB::Update::Series;
use Moose;
extends 'TheTVDB::Update';

has 'detail'       => (
	is       => 'ro',
	isa      => 'TheTVDB::SeriesDetail',
	lazy     => 1,
	default  => sub {
		my $self = shift;
		return $self->tvdb->getSeries($self->id);
	}
);

package TheTVDB::Update::Episode;
use Moose;
extends 'TheTVDB::Update';

has 'series'       => (
	is       => 'ro',
	isa      => 'TheTVDB::SeriesDetail',
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

package TheTVDB::Series;
use Moose;
extends 'TheTVDB::Base';

has 'id'         => (
	is         => 'ro',
	isa        => 'Int',
	required   => 1
);

has 'language'   => (
	is         => 'ro',
	isa        => 'Str',
	required   => 1
);

has 'name'       => (
	is         => 'ro',
	isa        => 'Str',
	required   => 1
);

has 'overview'   => (
	is         => 'ro',
	isa        => 'Maybe[Str]',
);

has 'firstAired' => (
	is         => 'ro',
	isa        => 'TheTVDB::DateTime',
	coerce     => 1,
);

has 'detail'     => (
	is         => 'ro',
	isa        => 'TheTVDB::SeriesDetail',
	lazy       => 1,
	default    => sub {
		my $self = shift;
		$self->tvdb->getSeries($self);
	}
);



sub getEpisode {
	my $self = shift;
	return $self->tvdb->getEpisode(series => $self, @_);
}

package TheTVDB::DetailBase;
use Moose;
extends 'TheTVDB::Base';

has 'id'            => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'firstAired'    => (
	is       => 'ro',
	isa      => 'TheTVDB::DateTime',
	coerce   => 1,
);

has 'lastUpdated'   => (
	is       => 'ro',
	isa      => 'TheTVDB::DateTime',
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

package TheTVDB::SeriesDetail;
use Moose;
extends 'TheTVDB::DetailBase';

has 'actors'        => (
	is       => 'ro',
	isa      => 'TheTVDB::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'contentRating' => (
	is       => 'ro',
	isa      => 'Maybe[Str]',
);

has 'genre'         => (
	is       => 'ro',
	isa      => 'TheTVDB::PipedList',
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
	isa      => 'TheTVDB::SeriesDetail',
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
			my $episodeXML = $allXML->{Episode}->{$episodeID};
			my %args = ();
			while (my ($xml, $local) = each (%episodeElementMap)) {
				$args{$local} = $episodeXML->{$xml} if defined $episodeXML->{$xml};
			}
			$args{id}       = $episodeID;
			$args{seriesId} = $self->id;
			$args{series}   = $self;

			$seasons{$episodeXML->{SeasonNumber}} //= {};
			$seasons{$episodeXML->{SeasonNumber}}->{$episodeXML->{EpisodeNumber}} = new TheTVDB::Series::Episode(tvdb => $self->tvdb, %args);
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

package TheTVDB::Series::Episode;
use Moose;
extends 'TheTVDB::DetailBase';

has 'seriesId'     => (
	is       => 'ro',
	isa      => 'Int',
	required => 1
);

has 'series'       => (
	is       => 'ro',
	isa      => 'TheTVDB::SeriesDetail',
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
	isa      => 'TheTVDB::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'director'     => (
	is       => 'ro',
	isa      => 'TheTVDB::PipedList',
	coerce   => 1,
	default  => sub {[]},
);

has 'writer'       => (
	is       => 'ro',
	isa      => 'TheTVDB::PipedList',
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


1;