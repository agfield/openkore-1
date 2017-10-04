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

	# init first lock map
	if (!$last_lock_map) {
		if ($config{'multiMap'} =~ $field->baseName) {
			$config{'lockMap'} = $field->baseName;
			calc_next_change_time();
		} else {
			change_lockmap();
		}
		$finish_count = 0;
		return;
	}

	# we have finished a map
	$finish_count++;
	message TF("lockMap finished count %d\n", $finish_count), "system";

	if ($finish_count >= $config{'multiMapRest'}) {
		offlineMode();
		calc_next_change_time();
		$finish_count = -1;
		return;
	}

	change_lockmap();
	Commands::run("autostorage") if $config{'multiMapStorage'};
}

sub change_lockmap {
	my @lockmap = split(/ /, $config{'multiMap'});
	my $randmap;

	while (($randmap = $lockmap[int(rand(@lockmap))]) eq $config{'lockMap'}) {
		;#do nothing
	}
	$config{'lockMap'} = $randmap;
	message TF("lockMap changed from '%s' to '%s'\n", $last_lock_map, $config{'lockMap'}), "system";

	calc_next_change_time();
}

sub calc_next_change_time {
	$last_lock_map = $config{'lockMap'};
	$last_interval = $config{'multiMapIntervalMin'} + int(rand($config{'multiMapIntervalSeed'}));
	$last_change_time = time();
	message TF("next change in %d sec\n", $last_interval), "system";
}

1;
