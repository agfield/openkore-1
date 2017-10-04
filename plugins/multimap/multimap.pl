package multimap;
use strict;

use Globals qw/%config $net %timeout_ex $field/;
use Log qw/message/;
use Translation qw/T TF/;
use Commands;

my $hooks = Plugins::addHooks(
	['AI_pre', \&AI_pre],
);

Plugins::register('multimap', 'multimap', sub { Plugins::delHooks($hooks) });

my $last_lock_map;
my $last_interval = 0;
my $last_change_time = 0;

sub AI_pre {
	return unless $config{'multiMap'};
	return if time() < $last_change_time + $last_interval;

	my @lockmap = split(/ /, $config{'multiMap'});
	my $randmap;

	if (!$last_lock_map && $config{'multiMap'} =~ $field->baseName) {
		$config{'lockMap'} = $field->baseName;
	} else {
		while (($randmap = $lockmap[int(rand(@lockmap))]) eq $config{'lockMap'}) {
			;#do nothing
		}
		$config{'lockMap'} = $randmap;
		Commands::run("autostorage");
	}

	message TF("lockMap changed from '%s' to '%s'\n", $last_lock_map, $config{'lockMap'}), "system";

	$last_lock_map = $config{'lockMap'};
	$last_interval = $config{'multiMapIntervalMin'} + int(rand($config{'multiMapIntervalSeed'}));
	$last_change_time = time();

	message TF("next change in %d sec\n", $last_interval), "system";
}

1;
