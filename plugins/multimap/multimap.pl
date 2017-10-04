package multimap;
use strict;

use Globals qw/%config $net %timeout_ex $field/;
use Log qw/message/;
use Translation qw/T TF/;
use Commands;

Plugins::register('multimap', 'multimap', \&on_unload);

my $hooks = Plugins::addHooks(
	['AI_pre', \&AI_pre],
);

my $chooks = Commands::register(
	['cmap', "Change lockmap", \&change_lockmap],
);

my $last_lock_map;
my $last_interval = 0;
my $last_change_time = 0;

sub on_unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub AI_pre {
	return unless $config{'multiMap'};
	return if time() < $last_change_time + $last_interval;

	if (!$last_lock_map && $config{'multiMap'} =~ $field->baseName) {
		$config{'lockMap'} = $field->baseName;
		calc_next_change_time();
	} else {
		change_lockmap();
		Commands::run("autostorage") if $config{'multiMapStorage'};
	}
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
