package multimap;
use strict;

use Globals qw/%config $net %timeout_ex $field $char/;
use Log qw/message/;
use Translation qw/T TF/;
use Commands;
use Misc qw(offlineMode configModify quit);

Plugins::register('multimap', 'multimap', \&on_unload);

my $hooks = Plugins::addHooks(
	['mainLoop_pre', \&mainLoop_pre],
);

my $chooks = Commands::register(
	['cmap', "Change lockmap", \&change_lockmap],
	['fmap', "Finish lockmap", \&finish_lockmap],
	['smap', "State lockmap", \&state_lockmap],
);

my $current_multimap_index = 0;
my $current_multimap_lvmin = 0;
my $current_multimap_lvmax = 0;
my @current_multimap = ();

my $last_interval = 0;
my $last_change_time = 0;
my $finish_count = 0;

sub on_unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub find_sutible_multimap {
	my $lv = shift;

	for (my $i = 0; $i < $config{'multiMapNr'}; $i++) {
		next unless $config{"multiMap$i"};
		my @multimap = split(/ /, $config{"multiMap$i"});
		my $lvmin = shift @multimap;
		my $lvmax = shift @multimap;
		return ($i, $lvmin, $lvmax, @multimap) if $lv >= $lvmin and $lv < $lvmax;
	}

	return (0, 0, 0, ());
}

sub change_lockmap {
	my $newmap;

	if ($#current_multimap + 1 < 2) {
		$newmap = $current_multimap[0];
		#message TF("lockMap not changed as only one map in multimap\n"), "system";
	} else {
		while (($newmap = $current_multimap[int(rand(@current_multimap))]) eq $config{'lockMap'}) {
			;#do nothing
		}
		#message TF("lockMap changed from '%s' to '%s'\n", $config{'lockMap'}, $newmap), "system";
	}

	configModify('lockMap', $newmap);
}

sub finish_lockmap {
	$finish_count++;

	if ($finish_count >= $config{'multiMapRest'}) {
		offlineMode();
		$finish_count = -1;
	}
}

sub calc_next_change_time {
	$last_interval = $config{'multiMapIntervalMin'} + int(rand($config{'multiMapIntervalSeed'}));
	$last_change_time = time();
}

sub state_lockmap {
	message TF("lockMap is %s, ", $config{'lockMap'}), "system";
	message TF("finished count is %d, ", $finish_count), "system";
	message TF("next change in %d sec\n", $last_change_time+$last_interval-time), "system";
}

sub multimap_init {
	($current_multimap_index, $current_multimap_lvmin, $current_multimap_lvmax,
		@current_multimap) = find_sutible_multimap($char->{'lv'});
	if (!@current_multimap) {
		message TF("can't find sutible multimap for base level %d\n", $char->{'lv'}), "system";
		quit();
		return;
	}

	message TF("use multiMap%d: %s\n", $current_multimap_index,
		$config{"multiMap$current_multimap_index"}), "system";

	my $tmp = $field->baseName;
	if (grep(/$tmp/, @current_multimap)) {
		configModify('lockMap', $tmp);
		#message TF("lockMap init to current map %s\n", $config{'lockMap'}), "system";
	} else {
		change_lockmap();
	}

	calc_next_change_time();
	state_lockmap();
}

sub mainLoop_pre {
	return unless $config{'multiMapEnable'};
	return unless $field;
	return unless $char;

	multimap_init() if !@current_multimap or $char->{'lv'} >= $current_multimap_lvmax;

	return if time() < $last_change_time + $last_interval;

	if ($net && $net->getState == Network::NOT_CONNECTED) {
		Commands::run("connect");
		return;
	}

	# real loop for finish & change map
	finish_lockmap();

	if ($net && $net->getState != Network::NOT_CONNECTED) {
		change_lockmap();
		Commands::run("autostorage") if $config{'multiMapStorage'};
	}

	calc_next_change_time();
	state_lockmap();
}

1;
