package multimap;
use strict;

use Globals qw/%config $net %timeout_ex $field/;
use Log qw/message/;
use Translation qw/T TF/;
use Commands;
use Misc qw(offlineMode);

Plugins::register('multimap', 'multimap', \&on_unload);

my $hooks = Plugins::addHooks(
	['mainLoop_pre', \&mainLoop_pre],
);

my $chooks = Commands::register(
	['cmap', "Change lockmap", \&change_lockmap],
	['fmap', "Finish lockmap", \&finish_lockmap],
);

my $last_lock_map;
my $last_interval = 0;
my $last_change_time = 0;
my $finish_count = 0;

sub on_unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub mainLoop_pre {
	return unless $field;
	return unless $config{'multiMap'};
	return if time() < $last_change_time + $last_interval;

	if ($net && $net->getState == Network::NOT_CONNECTED) {
		Commands::run("connect");
		return;
	}

	calc_next_change_time();

	# init first lock map
	if (!$last_lock_map) {
		if ($config{'multiMap'} =~ $field->baseName) {
			$config{'lockMap'} = $field->baseName;
			$last_lock_map = $config{'lockMap'};
		} else {
			change_lockmap();
		}
		$finish_count = 0;
		return;
	}

	finish_lockmap();
	return if ($net && $net->getState == Network::NOT_CONNECTED);

	change_lockmap();
	Commands::run("autostorage") if $config{'multiMapStorage'};
}

sub change_lockmap {
	my @lockmap = split(/ /, $config{'multiMap'});
	my $randmap;

	if ($config{'multiMap'} eq $config{'lockMap'}) {
		message TF("lockMap not changed as it equals to multiMap\n"), "system";
	} else {
		while (($randmap = $lockmap[int(rand(@lockmap))]) eq $config{'lockMap'}) {
			;#do nothing
		}
		$config{'lockMap'} = $randmap;
		message TF("lockMap changed from '%s' to '%s'\n", $last_lock_map, $config{'lockMap'}), "system";
		$last_lock_map = $config{'lockMap'};
	}
}

sub finish_lockmap {
	$finish_count++;
	message TF("lockMap finished count %d\n", $finish_count), "system";

	if ($finish_count >= $config{'multiMapRest'}) {
		offlineMode();
		$finish_count = -1;
	}
}

sub calc_next_change_time {
	$last_interval = $config{'multiMapIntervalMin'} + int(rand($config{'multiMapIntervalSeed'}));
	$last_change_time = time();
	message TF("next change in %d sec\n", $last_interval), "system";
}

1;
