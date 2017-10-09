package avoidplayers;
use strict;

use Globals qw/%config $net %timeout_ex $field $char $playersList/;
use Log qw/message/;
use Translation qw/T TF/;
use Commands;
use Misc qw(offlineMode configModify isSafe useTeleport);

Plugins::register('avoidplayers', 'avoidplayers', \&on_unload);

my $hooks = Plugins::addHooks(
	['AI_pre', \&AI_pre],
);

my $chooks = Commands::register(
	['savd', "State avoidplayers", \&state_avoidplayers],
);

my $avoids = {};
my $avoid_count = 0;
my $avoid_change_map_count = 0;

sub on_unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub state_avoidplayers {
	message TF("avoid count is %d, change-map count is %d\n",
		$avoid_count, $avoid_change_map_count), "system";
}

sub AI_pre {
	return unless $config{'avoidPlayers'};
	return unless $field;
	return unless $char;

	return if $field->isCity || $field->baseName ne $config{'lockMap'}
		|| AI::inQueue("storageAuto", "buyAuto");

	if (isSafe()) {
		$avoids = {} if scalar(keys %$avoids);
		return;
	}

	for my Actor::Player $player (@$playersList) {
		if (!exists $avoids->{"$player->{nameID}"}) {
			$avoids->{"$player->{nameID}"} = time;
			message TF("Find a player %s(%d) nearby\n", $player->{'name'}, $player->{'nameID'}), "teleport";
		} else {
			if ($avoids->{"$player->{nameID}"}+$config{'avoidPlayers_teleportDelay'} < time &&
				AI::action ne 'attack' && AI::action ne 'items_take') {
				useTeleport(1);
				message TF("Teleport to avoid player %s(%d), timeout %d\n",
					$player->{'name'}, $player->{'nameID'},
					time-$avoids->{"$player->{nameID}"}), "teleport";
				$avoids = {};
				$avoid_count++;
				last;
			}
		}
	}

	if ($avoid_count >= $config{'avoidPlayers_countToChangeMap'}) {
		$avoid_count = 0;
		$avoid_change_map_count++;
		Commands::run("cmap");
	}
}

1;
