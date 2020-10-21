package Plugins::LocalPlayer::Squeezelite;

use strict;

use Proc::Background;
use File::ReadBackwards;
use File::Spec::Functions;

use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.localplayer');
my $log   = logger('plugin.localplayer');

my $squeezelite;
my $binary;

sub binaries {
	my $os = Slim::Utils::OSDetect::details();

	if ($os->{'os'} eq 'Linux') {
		if ($os->{'osArch'} =~ /x86_64/) {
			return qw(squeezelite-x86-64);
		}
		if ($os->{'binArch'} =~ /i386/) {
			return qw(squeezelite-i386);
		}
		if ($os->{'binArch'} =~ /arm/) {
			return qw(squeezelite-armv6hf squeezelite-armv6 squeezelite-armv5te);
		}
		# fallback to offering all linux options for case when architecture detection does not work
		return qw(squeezelite-x86-64 squeezelite-i386 squeezelite-armv6hf squeezelite-armv6 squeezelite-armv5te);
	}
	if ($os->{'os'} eq 'Darwin') {
		return qw(squeezelite-osx-i386 squeezelite-osx);
	}
	if ($os->{'os'} eq 'Windows') {
		return qw(squeezelite-win);
	}
}

sub bin {
	my $class = shift;

	my @binaries = $class->binaries;

	if (scalar @binaries == 1) {
		return $binaries[0];
	}

	if (my $b = $prefs->get("bin")) {
		for my $bin (@binaries) {
			if ($bin eq $b) {
				return $b;
			}
		}
	}

	return $binaries[0] =~ /squeezelite-osx/ ? $binaries[0] : undef;
}

sub start {
	my $class = shift;

	my $bin = $class->bin || do {
		$log->warn("no binary set");
		return;
	};

	my @params;
	my $logging;

	if ($prefs->get('output') ne '') {
		push @params, ("-o", $prefs->get('output'));
	}

	if ($prefs->get('debugs') ne '') {
		push @params, ("-d", $prefs->get('debugs') . "=debug");
	}

	if ($prefs->get('logging') || $prefs->get('debugs') ne '') {
		push @params, ("-f", $class->logFile);
		$logging = 1;
	}

	if ($prefs->get('opts') ne '') {
		push @params, split(/\s+/, $prefs->get('opts'));
	}

	my $path = Slim::Utils::Misc::findbin($bin) || do {
		$log->debug("$bin not found");
		return;
	};

	my $path = Slim::Utils::OSDetect::getOS->decodeExternalHelperPath($path);
		
	if (!-e $path) {
		$log->debug("$bin not executable");
		return;
	}

	$log->info("starting $bin @params");

	if ($logging) {
		open(my $fh, ">>", $class->logFile);
		print $fh "\nStarting Squeezelite: $path @params\n";
		close $fh;
	}
	
	eval { $squeezelite = Proc::Background->new({ 'die_upon_destroy' => 1 }, $path, @params); };

	if ($@) {

		$log->warn($@);

	} else {
		Slim::Utils::Timers::setTimer($class, Time::HiRes::time() + 1, sub {
			if ($squeezelite && $squeezelite->alive) {
				$log->debug("$bin running");
				$binary = $path;
			}
		});
	}
}

sub stop {
	my $class = shift;

	if ($squeezelite && $squeezelite->alive) {
		$log->info("killing squeezelite");
		$squeezelite->die;
	}
}

sub alive {
	return ($squeezelite && $squeezelite->alive) ? 1 : 0;
}

sub restart {
	my $class = shift;

	$class->stop;
	$class->start;
}

sub devices {
	return unless $binary;

	# run "squeezelite -l" to get devices and parse result
	my $query = "$binary -l";
	my @devices = `$query`;

	my @output;

	for my $line (@devices) {
		if (my ($name, $desc) = $line =~ /\s+(.*?)\s+\-\s+(.*)/) {
			if ($name !~ /^\d+$/) {
				# ALSA
				push @output, { name => $name, desc => $desc };
			} else {
				# Port Audio
				$desc =~ s/ \[.*?\]//; # temp strip additional text from squeezelite 1.3
				push @output, { name => $desc, desc => $name };
			}
		}
	}

	return \@output;
}

sub logFile {
	return catdir(Slim::Utils::OSDetect::dirsFor('log'), "localplayer.log");
}

sub logHandler {
	my ($client, $params, undef, undef, $response) = @_;

	$response->header("Refresh" => "10; url=" . $params->{path} . ($params->{lines} ? '?lines=' . $params->{lines} : ''));
	$response->header("Content-Type" => "text/plain; charset=utf-8");

	my $body = '';
	my $file = File::ReadBackwards->new(logFile());
	
	if ($file){

		my @lines;
		my $count = $params->{lines} || 100;

		while ( --$count && (my $line = $file->readline()) ) {
			unshift (@lines, $line);
		}

		$body .= join('', @lines);

		$file->close();			
	};

	return \$body;
}

1;
