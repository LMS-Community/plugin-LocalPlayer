package Plugins::LocalPlayer::Plugin;

use strict;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Prefs;
use Slim::Utils::Log;

my $prefs = preferences('plugin.localplayer');

$prefs->init({
	autorun => sub { lc(Slim::Utils::OSDetect::details()->{osName} || '') eq 'picore' ? 0 : 1 },
	output => '',
	opts => '-s 127.0.0.1',
	debugs => '',
	logging => 0,
	loc => 1,
	bin => undef
});

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.localplayer',
	'defaultLevel' => 'WARN',
	'description'  => Slim::Utils::Strings::string('PLUGIN_LOCALPLAYER'),
});

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(@_);

	if ($prefs->get('loc')) {
		require Plugins::LocalPlayer::LocalFile;
		Slim::Player::ProtocolHandlers->registerHandler('file', 'Plugins::LocalPlayer::LocalFile');
	}

	if ($prefs->get('autorun')) {
		require Plugins::LocalPlayer::Squeezelite;
		Plugins::LocalPlayer::Squeezelite->start;
	}

	if (main::WEBUI) {
		require Plugins::LocalPlayer::Settings;
		Plugins::LocalPlayer::Settings->new;
		Slim::Web::Pages->addPageFunction("^localplayer.log", \&Plugins::LocalPlayer::Squeezelite::logHandler);
	}

	isPCP();
}

my $pcpWarning;
sub isPCP {
	return $pcpWarning if defined $pcpWarning;

	my $osDetails = Slim::Utils::OSDetect::details();
	$pcpWarning = lc($osDetails->{osName} || '') eq 'picore' ? 1 : 0;
	$pcpWarning && $log->error(Slim::Utils::Strings::string('PLUGIN_LOCALPLAYER_PCP_DETECTED'));
}

sub shutdownPlugin {
	if ($prefs->get('autorun')) {
		Plugins::LocalPlayer::Squeezelite->stop;
	}
}

1;
