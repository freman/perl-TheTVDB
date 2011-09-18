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
warn "IO::Uncompress::Unzip not found, please install this perl module to save bandwidth" unless $HAVEZIP;

use TheTVDB::Type;
use TheTVDB::Updates::Episode;
use TheTVDB::Updates::List;
use TheTVDB::Updates::Series;
use TheTVDB::Base;
use TheTVDB::Base::Update;
use TheTVDB::Base::Detail;
use TheTVDB::Series;
use TheTVDB::Mirror;
use TheTVDB::Series::Episode;
use TheTVDB::Series::Detail;
use TheTVDB::Updates;
use TheTVDB::Season;


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

	return TheTVDB::Series::Detail->new(tvdb => $self, %args);
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

	return TheTVDB::Series::Episode->importFromXML(
		tvdb      => $self->tvdb,
		xml       => $episodeXML->{Episode},
		($series ? (seriesId => $series->id) : ())
	);
}



'this statement is false';
