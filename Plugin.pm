package Plugins::LocalPlayer::Plugin;

use strict;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Prefs;
use Slim::Utils::Log;

my $prefs = preferences('plugin.localplayer');

$prefs->init({ autorun => 1, output => '', opts => '', debugs => '', logging => 0, loc => 1, bin => undef });

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.localplayer',
	'defaultLevel' => 'WARN',
	'description'  => Slim::Utils::Strings::string('PLUGIN_LOCALPLAYER'),
}); 

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(@_);

	if (Slim::Utils::OSDetect::OS() =~ /win/) {
		require Plugins::LocalPlayer::DownloadLibs;
		Plugins::LocalPlayer::DownloadLibs->checkLibs($class);
	}

	if ($prefs->get('loc')) {
		require Plugins::LocalPlayer::LocalFile;
		Slim::Player::ProtocolHandlers->registerHandler('file', 'Plugins::LocalPlayer::LocalFile');
	}

	if ($prefs->get('autorun')) {
		require Plugins::LocalPlayer::Squeezelite;
		Plugins::LocalPlayer::Squeezelite->start;
	}
	
	if (!$::noweb) {
		require Plugins::LocalPlayer::Settings;
		Plugins::LocalPlayer::Settings->new;
		Slim::Web::Pages->addPageFunction("^localplayer.log", \&Plugins::LocalPlayer::Squeezelite::logHandler);
	}
}

sub shutdownPlugin {
	if ($prefs->get('autorun')) {
		Plugins::LocalPlayer::Squeezelite->stop;
	}
}

1;
