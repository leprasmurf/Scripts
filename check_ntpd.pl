#!/usr/bin/perl -w
use Getopt::Long;
use strict;

# Variable declaration
my $ntpq_path = `/usr/bin/which ntpq || echo "/sbin/ntpq"`;
chomp($ntpq_path);
my @server_list = `$ntpq_path -pn`;
my %server_health;
my $peer_count;
my $overall_health = 0;
my $good_count;
my $selected_primary;
my $selected_backup = 0;

# Read in options from command line
GetOptions(
		"critical=i" => \(my $critical_threshold = '50'),
		"warning=i" => \(my $warning_threshold = '75'),
		"peer_critical=i" => \(my $peer_critical_threshold = '1'),
		"peer_warning=i" => \(my $peer_warning_threshold = '2'),
		"help" => \&display_help,
);

# Cleanup server list
# Cycle through and remove useless information
for(my $i = 0; $i < @server_list; $i++) {
	# Disregard localhost enties
	if($server_list[$i] =~ /LOCAL|LOCL/) {
		splice(@server_list, $i, 1);
		$i--;
	# Remove the header line
	} elsif($server_list[$i] =~ /jitter$|disp$/) {
		splice(@server_list, $i, 1);
		$i--;
	# Remove the header seperator
	} elsif($server_list[$i] =~ /^===/) {
		splice(@server_list, $i, 1);
		$i--;
	# Remove failed NTPq returns
	} elsif($server_list[$i] =~ /^No association/) {
		splice(@server_list, $i, 1);
		$i--;
	}
}

# Get number of peers
$peer_count = @server_list;

# Cycle through peers
for(my $i = 0; $i < @server_list; $i++) {
	#split each element of the peer line
	my @tmp_array = split(" ", $server_list[$i]);

	# Check for first character of peer
	# space = Discarded due to high stratum and/or failed sanity checks.
	# x = Designated falseticker by the intersection algorithm.
	# . = Culled from the end of the candidate list.
	# - = Discarded by the clustering algorithm.
	# + = Included in the final selection set.
	# # = Selected for synchronization but distance exceeds maximum.
	# * = Selected for synchronization.
	# o = Selected for synchronization, pps signal in use.
	if(substr($tmp_array[0], 0, 1) eq '*') {
		$selected_primary = "true";
	} elsif(substr($tmp_array[0], 0, 1) eq '+') {
		$selected_backup++;
	}

	$good_count = 0;

	# Read in the octal number in column 6
	my $x = oct($tmp_array[6]);

	# while $x is not 0
	while($x) {
		# 1's place 0 or 1?
		$good_count += $x % 2;
		# Bit shift to the right
		$x = $x >> 1;
	}

	# Calculate good packets received
	$x = int(($good_count / 8) * 100);

	# Set percentage in hash
	$server_health{$tmp_array[0]} = $x;
}

# Cycle through hash and tally weighted average of peer health
while(my($key, $val) = each(%server_health)) {
	$overall_health += $val * (1 / $peer_count);
}

########################### Nagios Status checks ###########################
#if overall health is at or below critical threshold, crit
if($overall_health <= $critical_threshold) {
	print_overall_health("Critical");
	print_server_list();
	exit 2;
#if overall health is at below warning and above critical threshold, warn
} elsif($overall_health <= $warning_threshold) {
	print_overall_health("Warning");
	print_server_list();
	exit 1;
}

#if the number of peers is below the critical threshold, crit
if($peer_count <= $peer_critical_threshold) {
	print_overall_health("Critical");
	print_server_list();
	exit 2;
#if the number of peers is below the warning threshold, warn
} elsif($peer_count <= $peer_warning_threshold) {
	print_overall_health("Warning");
	print_server_list();
	exit 1;
}

#check to make sure we have one backup and one selected ntp server
#if there is no primary ntp server selected, crit
if($selected_primary ne "true") {
	print_overall_health("Critical");
	print_server_list();
	exit 2;
#if there is no backup ntp server selected, warn
} elsif($selected_backup < 1) {
	print_overall_health("Warning");
	print_server_list();
	exit 1;
}

print_overall_health("OK");
print_server_list();
exit 0;

sub print_server_list {
	print "------------------------------------------------------\n";
	while(my($key, $val) = each(%server_health)) {
		print "Received " . $val . "% of the traffic from " . $key . "\n";
	}
}

sub print_overall_health {
	print $_[0] . " - NTPd Health is " . $overall_health . "% with " . $peer_count . " peer(s).\n";
	print "Thresholds:  Health (" . $warning_threshold . "%|" . $critical_threshold . "%); Peers (" . $peer_warning_threshold . "|" . $peer_critical_threshold . ")\n";
}

sub display_help {
	print "This nagios check determines the health of NTPd on a system by calculating ";
	print "the overall health of the peers associated with the daemon.  This check also ";
	print "verifies other attributes, such as the number of peers available, and whether ";
	print "a peer has been selected to be the sync source.  The overall health percentage ";
	print "is a cumulative average of the reach over the peers.\n";
	print "\n";
	print "Example:  If 3 peers are listed, and 1 of the 3 dropped 2 of the last 8 packets, ";
	print "the health of that peer would be 75%, and the overall health would be about 92% ";
	print "((100 + 100 + 75) / 3).\n";
	print "\n";
	print "Available Options:\n";
	print "\t--critical|-c <num>\t-Set the critical threshold for overall health (default:50)\n";
	print "\t--warning|-w <num>\t-Set the warning threshold for overall health (default:75)\n";
	print "\t--peer_critical <num>\t-Set the critical threshold for number of peers (default:1)\n";
	print "\t--peer_warning <num>\t-Set the warning threshold for number of peers (default:2)\n";
	print "\t--help|-h\t\t-display this help\n";
	exit 0;
}
