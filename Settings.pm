package Plugins::LocalPlayer::Settings;

use strict;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.localplayer');

sub name { 'PLUGIN_LOCALPLAYER' }

sub page { 'plugins/LocalPlayer/settings/basic.html' }

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;

	my $update;

	if ($params->{'saveSettings'}) {

		# only set autorun if turning it on as other params are hidden and don't get returned
		my @bool  = $params->{'autorun'} && !$prefs->get('autorun') ? qw(autorun) : qw(autorun logging loc);
		my @other = $params->{'autorun'} && !$prefs->get('autorun') ? () : qw(output bin debugs opts);

		for my $param (@bool) {

			my $val = $params->{ $param } ? 1 : 0;

			if ($val != $prefs->get($param)) {

				$prefs->set($param, $val);
				$update = 1 unless $param eq 'loc';

				if ($param eq 'autorun') {
					require Plugins::LocalPlayer::Squeezelite;
				}

				if ($param eq 'loc' && $params->{ $param }) {
					require Plugins::LocalPlayer::LocalFile;
					Slim::Player::ProtocolHandlers->registerHandler('file', 'Plugins::LocalPlayer::LocalFile');
				}
			}
		}

		for my $param (@other) {
			if ($params->{ $param } ne $prefs->get($param)) {
				$prefs->set($param, $params->{ $param });
				$update = 1;
			}
		}
	}

	if ($update) {

		$prefs->get('autorun') ? Plugins::LocalPlayer::Squeezelite->restart : Plugins::LocalPlayer::Squeezelite->stop;

		Slim::Utils::Timers::setTimer($class, Time::HiRes::time() + 1, sub {
			$class->handler2( $client, $params, $callback, @args);
		});

	} else {

		$class->handler2( $client, $params, $callback, @args);
	}

	return undef;
}

sub handler2 {
	my ($class, $client, $params, $callback, @args) = @_;

	if ($prefs->get('autorun')) {

		$params->{'binary'}   = Plugins::LocalPlayer::Squeezelite->bin;
		$params->{'binaries'} = [ Plugins::LocalPlayer::Squeezelite->binaries('update') ];
		$params->{'running'}  = Plugins::LocalPlayer::Squeezelite->alive;

		my $devices = Plugins::LocalPlayer::Squeezelite->devices;

		unshift @$devices, { name => '', desc => "Default" };

		$params->{'devices'} = $devices;

	} else {

		$params->{'running'} = 0;
	}

	for my $param (qw(autorun output bin opts debugs logging loc)) {
		$params->{ $param } = $prefs->get($param);
	}

	$params->{'isPCP'} = Plugins::LocalPlayer::Plugin::isPCP();
	$params->{'arch'} = Slim::Utils::OSDetect::OS();

	$callback->($client, $params, $class->SUPER::handler($client, $params), @args);
}

1;
