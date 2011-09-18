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
		TheTVDB::Updates::Series->new(
			tvdb => $tvdb,
			id   => $_,
			time => $updates->{Series}->{$_}->{time}
		)
	} keys %{$updates->{Series}};

	my @episode = map {
		my $o = $updates->{Episode}->{$_};
		TheTVDB::Updates::Episode->new(
			tvdb => $tvdb,
			id   => $_,
			seriesId => $o->{Series},
			time => $o->{time}
		)
	} keys %{$updates->{Episode}};

	return TheTVDB::Updates::List->new(tvdb => $tvdb, series => \@series, episode => \@episode);
}


'this statement is false';
