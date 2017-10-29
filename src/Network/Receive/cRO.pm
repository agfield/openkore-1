#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# cRO (Taren)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::cRO;

use strict;
use Time::HiRes;
use Socket qw(inet_aton inet_ntoa);

use Globals;
use base qw(Network::Receive::ServerType0);
use AI;
use Log qw(message debug error);
use I18N qw(bytesToString stringToBytes);
use Network::MessageTokenizer;
use Misc;
use Utils;
use Translation;
use Utils::Exceptions;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0AC9' => ['account_server_info', 'v a4 a4 a4 a4 a26 C a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
		'0AC5' => ['received_character_ID_and_Map', 'a4 Z16 a4 v a128', [qw(charID mapName mapIP mapPort mapUrl)]],
		'0AC7' => ['map_changed', 'Z16 v2 a4 v a128', [qw(map x y IP port url)]],
		'0ACD' => ['login_error', 'C Z20', [qw(type date)]],
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
		#'0367' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		#'023B' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		actor_moved 09DB
		actor_connected 09DC
		actor_exists 09DD
		actor_connected 0858
		inventory_item_added 0A0C
		inventory_items_nonstackable 0A0D
		account_id 0283
		received_characters 099D
		quest_all_list3 09F8
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{sync_ex_reply} = {
		'0367' => '02C4',
		'085A' => '0884',
		'085B' => '0885',
		'085C' => '0886',
		'085D' => '0887',
		'085E' => '0888',
		'085F' => '0889',
		'0860' => '088A',
		'0861' => '088B',
		'0862' => '088C',
		'0863' => '088D',
		'0864' => '088E',
		'0865' => '088F',
		'0866' => '0890',
		'0867' => '0891',
		'0868' => '0892',
		'0869' => '0893',
		#'023B' => '0893',
		'086A' => '0894',
		'086B' => '0895',
		'086C' => '0202',
		'086D' => '0897',
		'086E' => '0898',
		'086F' => '0899',
		'0870' => '089A',
		'0871' => '089B',
		'0872' => '089C',
		'0873' => '089D',
		'0874' => '089E',
		'0875' => '089F',
		'0876' => '08A0',
		'0877' => '08A1',
		'0878' => '08A2',
		'0879' => '08A3',
		'087A' => '08A4',
		'087B' => '08A5',
		'087C' => '08A6',
		'087D' => '08A7',
		'087E' => '08A8',
		'087F' => '08A9',
		'0880' => '08AA',
		'0881' => '0436',
		'0882' => '08AC',
		'0883' => '08AD',
		'0917' => '0941',
		'0918' => '0942',
		'0919' => '0943',
		'091A' => '0944',
		'091B' => '0945',
		'091C' => '0946',
		'091D' => '0947',
		'091E' => '0948',
		'091F' => '0949',
		'0920' => '094A',
		'0921' => '094B',
		'0361' => '094C',
		'0923' => '094D',
		'0924' => '094E',
		'0925' => '094F',
		'0926' => '0950',
		'0927' => '0951',
		'0928' => '0952',
		'0929' => '0953',
		'092A' => '0954',
		'092B' => '0955',
		'092C' => '0956',
		'092D' => '0957',
		'092E' => '0958',
		'092F' => '0959',
		'0930' => '095A',
		'0931' => '095B',
		'0932' => '095C',
		'0933' => '095D',
		'0934' => '0940',
		'0935' => '095E',
		'0936' => '0960',
		'0937' => '0961',
		'0938' => '0962',
		'0939' => '0963',
		'093A' => '0964',
		'093B' => '0965',
		'093C' => '0966',
		'093D' => '0967',
		'093E' => '0968',
		'093F' => '0969',
		'0940' => '096A',
	};

	$self->{vender_items_list_item_pack} = 'V v2 C v C3 a8 a25';
	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

sub parse_account_server_info {
    my ($self, $args) = @_;

    if (length $args->{lastLoginIP} == 4 && $args->{lastLoginIP} ne "\0"x4) {
        $args->{lastLoginIP} = inet_ntoa($args->{lastLoginIP});
    } else {
        delete $args->{lastLoginIP};
    }

    @{$args->{servers}} = map {
        my %server;
        @server{qw(ip port name users display)} = unpack 'a4 v Z20 v2 x2', $_;
        if ($masterServer && $masterServer->{private}) {
            $server{ip} = $masterServer->{ip};
        } else {
            $server{ip} = inet_ntoa($server{ip});
            $server{ip} = "char.ro.zhaouc.com";
        }
        $server{name} = bytesToString($server{name});
        \%server
    } unpack '(a32)*', $args->{serverInfo};
}

sub sync_received_characters {
	my ($self, $args) = @_;
	if (exists $args->{sync_Count}) {
		$charSvrSet{sync_Count} = $args->{sync_Count};
		$charSvrSet{sync_CountDown} = $args->{sync_Count};
	}

	if ($config{'XKore'} ne '1') {
		# FIXME twRO client really sends only one sync_received_characters?
		$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
		$charSvrSet{sync_CountDown}--;
	}
}

sub received_characters_info {
	my ($self, $args) = @_;

	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});
	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	$timeout{charlogin}{time} = time;
}

sub received_character_ID_and_Map {
	my ($self, $args) = @_;
	message T("Received character ID and Map IP from Character Server\n"), "connection";
	$net->setState(4);
	undef $conState_tries;
	$charID = $args->{charID};

	if ($net->version == 1) {
		undef $masterServer;
		$masterServer = $masterServers{$config{master}} if ($config{master} ne "");
	}

	my ($map) = $args->{mapName} =~ /([\s\S]*)\./; # cut off .gat
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	#$map_ip = makeIP($args->{mapIP});
	#$map_ip = $masterServer->{ip} if ($masterServer && $masterServer->{private});
	$map_ip = $args->{mapUrl};
	$map_ip =~ s/:[0-9]+//;
	$map_port = $args->{mapPort};
	message TF("----------Game Info----------\n" .
		"Char ID: %s (%s)\n" .
		"MAP Name: %s\n" .
		"MAP IP: %s\n" .
		"MAP Port: %s\n" .
		"-----------------------------\n", getHex($charID), unpack("V1", $charID),
		$args->{mapName}, $map_ip, $map_port), "connection";
	checkAllowedMap($map_noinstance);
	message(T("Closing connection to Character Server\n"), "connection") unless ($net->version == 1);
	$net->serverDisconnect(1);
	main::initStatVars();
}

sub map_changed {
	my ($self, $args) = @_;
	$net->setState(4);

	my $oldMap = $field ? $field->baseName : undef; # Get old Map name without InstanceID
	my ($map) = $args->{map} =~ /([\s\S]*)\./;
	my $map_noinstance;
	($map_noinstance, undef) = Field::nameToBaseName(undef, $map); # Hack to clean up InstanceID

	checkAllowedMap($map_noinstance);
	if (!$field || $map ne $field->name()) {
		eval {
			$field = new Field(name => $map);
		};
		if (my $e = caught('FileNotFoundException', 'IOException')) {
			error TF("Cannot load field %s: %s\n", $map_noinstance, $e);
			undef $field;
		} elsif ($@) {
			die $@;
		}
	}

	my %coords = (
		x => $args->{x},
		y => $args->{y}
	);
	$char->{pos} = {%coords};
	$char->{pos_to} = {%coords};

	undef $conState_tries;
	for (my $i = 0; $i < @ai_seq; $i++) {
		ai_setMapChanged($i);
	}
	AI::SlaveManager::setMapChanged ();
	$ai_v{portalTrace_mapChanged} = time;

	#$map_ip = makeIP($args->{IP});
	$map_ip = $args->{url};
	$map_ip =~ s/:[0-9]+//;
	$map_port = $args->{port};
	message(swrite(
		"---------Map  Info----------", [],
		"MAP Name: @<<<<<<<<<<<<<<<<<<",
		[$args->{map}],
		"MAP IP: @<<<<<<<<<<<<<<<<<<",
		[$map_ip],
		"MAP Port: @<<<<<<<<<<<<<<<<<<",
		[$map_port],
		"-------------------------------", []),
		"connection");

	message T("Closing connection to Map Server\n"), "connection";
	$net->serverDisconnect unless ($net->version == 1);

	# Reset item and skill times. The effect of items (like aspd potions)
	# and skills (like Twohand Quicken) disappears when we change map server.
	# NOTE: with the newer servers, this isn't true anymore
	my $i = 0;
	while (exists $config{"useSelf_item_$i"}) {
		if (!$config{"useSelf_item_$i"}) {
			$i++;
			next;
		}

		$ai_v{"useSelf_item_$i"."_time"} = 0;
		$i++;
	}
	$i = 0;
	while (exists $config{"useSelf_skill_$i"}) {
		if (!$config{"useSelf_skill_$i"}) {
			$i++;
			next;
		}

		$ai_v{"useSelf_skill_$i"."_time"} = 0;
		$i++;
	}
	$i = 0;
	while (exists $config{"doCommand_$i"}) {
		if (!$config{"doCommand_$i"}) {
			$i++;
			next;
		}

		$ai_v{"doCommand_$i"."_time"} = 0;
		$i++;
	}
	if ($char) {
		delete $char->{statuses};
		$char->{spirits} = 0;
		delete $char->{permitSkill};
		delete $char->{encoreSkill};
	}
	undef %guild;
	if ( $char->cartActive ) {
		$char->cart->close;
		$char->cart->clear;
	}

	Plugins::callHook('Network::Receive::map_changed', {
		oldMap => $oldMap,
	});
	$timeout{ai}{time} = time;
}

1;
