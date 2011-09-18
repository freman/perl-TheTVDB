package TheTVDB::Type;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime;
use DateTime::Format::Strptime qw/strptime/;

class_type 'DateTime';
subtype 'TheTVDB::Type::DateTime' => as 'Maybe[DateTime]';
subtype 'TheTVDB::Type::PipedList' => as 'Maybe[ArrayRef[Str]]';

coerce 'TheTVDB::Type::DateTime'
	=> from 'Str'
		=> via {$_ =~ /^\d+$/ ? DateTime->from_epoch(epoch => $_) : strptime('%F', $_)}
	=> from 'Int'
		=> via {DateTime->from_epoch(epoch => $_)};

coerce 'TheTVDB::Type::PipedList'
	=> from 'Str'
		=> via {$_ =~ s/^\||\|$//sg; [split(/\|/, $_)]};
