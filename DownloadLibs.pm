package Plugins::LocalPlayer::DownloadLibs;

use strict;

use File::Spec::Functions;

use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.localplayer');
my $log   = logger('plugin.localplayer');

my $libs = {
	'libfaad2.dll'  => { url => 'http://www.rarewares.org/files/aac/libfaad2-2.7.zip', 
						 sha => 'ae4aebf21ac0df5a2220771eff62f901ca5b238e', path => 'libfaad2.dll' },
	'libmpg123.dll' => { url => 'http://www.mpg123.de/download/win32/mpg123-1.14.4-x86.zip',
						 sha => '35046c239bd5d596a0b43eef0ef1cb73420abc57', path => 'mpg123-1.14.4-x86/libmpg123-0.dll' }
};

my $downloading = 0;

sub checkLibs {
	my ($class, $plugin) = @_;

	my $path = catdir($plugin->_pluginDataFor('basedir'), 'Bin');
	
	for my $lib (keys %$libs) {

		if (!-r catdir($path, $lib)) {

			$log->info("lib $lib not installed at $path downloading");

			my $file = catdir($path, "$lib.zip");
			my $args = { lib => $lib, digest => $libs->{$lib}->{'sha'}, path => $libs->{$lib}->{'path'},
						 dest => catdir($plugin->_pluginDataFor('basedir'), 'Bin', $lib) };

			$downloading++;

			my $http = Slim::Networking::SimpleAsyncHTTP->new( \&_downloadDone, \&_downloadError, { saveAs => $file, args => $args } );
	
			$http->get($libs->{ $lib }->{'url'});
		}
	}
}

sub _downloadDone {
	my $http = shift;

	my $file = $http->params('saveAs');
	my $lib  = $http->params('args')->{'lib'};
	my $digest = $http->params('args')->{'digest'};
	my $path   = $http->params('args')->{'path'};
	my $dest   = $http->params('args')->{'dest'};

	$log->info("downloaded $file");

	if (-r $file) {

		my $sha1 = Digest::SHA1->new;
		
		open my $fh, '<', $file;

		binmode $fh;
		
		$sha1->addfile($fh);
		
		close $fh;
		
		if ($sha1->hexdigest ne $digest) {
			
			$log->warn("digest does not match $file - $lib will not be installed");

		} else {

			$log->info("digest matches");
			
			my $zip;
			
			eval {
				require Archive::Zip;
				$zip = Archive::Zip->new();
			};
			
			if (!defined $zip) {
				
				$log->error("error loading Archive::Zip $@");
				
			} elsif (my $zipstatus = $zip->read($file)) {
				
				$log->warn("error reading zip file $file status: $zipstatus");
				
			} else {
				
				my $res = $zip->extractMember($path, $dest);

				if ($res == Archive::Zip::AZ_OK() ) {
					
					main::INFOLOG && $log->info("extracted $lib to $dest");

				} else {

					$log->warn("failed to extract $lib: src: $path to dest: $dest - $zipstatus");
				}

			}
		}

		unlink $file;
	}

	if (!--$downloading) {
		Plugins::LocalPlayer::Squeezelite->restart
	}
}

sub _downloadError {
	my $http  = shift;
	my $error = shift;

	my $lib   = $http->params('args')->{'lib'};

	$log->warn("error downloading $lib $error");

	if (!--$downloading) {
		Plugins::LocalPlayer::Squeezelite->restart
	}
}

1;
