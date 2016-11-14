#!/usr/bin/ruby
require 'optparse';

##### Helper Functions #####
def print_server_list()
	puts "---------------------------";
	$peer_health.each do |peer, health|
		puts "Received #{health}% of the traffic from #{peer}.";
	end
end

def print_overall_health(status)
	puts "#{status} - NTPd Health is #{$overall_health}% with #{$peer_count} peers.";
	print_server_list();
end

##### Options Parsing #####
# Define default values for command line arguments
options = {
	:critical_threshold => 50,
	:warning_threshold => 75,
	:peer_critical_threshold => 1,
	:peer_warning_threshold => 2
};

# Parse command line arguments
OptionParser.new do |opts|
	opts.banner = "Usage: check_ntpd.rb [options]";

	opts.on("-c", "--critical [INT]", "Set the Critical Health Threshold.") do |c|
		options[:critical_threshold] = c.to_i;
	end

	opts.on("-w", "--warning [INT]", "Set the Warning Health Threshold.") do |w|
		options[:warning_threshold] = w.to_i;
	end

	opts.on("--peer_critical [INT]", "Set the Critical threshold on the number of active peers.") do |c|
		options[:peer_critical_threshold] = c.to_i;
	end

	opts.on("--peer_warning [INT]", "Set the Warning threshold on the number of active peers.") do |w|
		options[:peer_warning_threshold] = w.to_i;
	end
end.parse!

##### Variable declaration #####
$peer_count = 0;
$peer_health = {};
$selected_primary = false;
$selected_backup = 0;
$overall_health = 0;

##### Script Logic #####
# Grab the current NTP peer list
server_list = `/usr/sbin/ntpq -pn`.chomp;

# Parse the server list
# Convert string to array by new line character
server_list = server_list.split(/\n/);

# Get rid of the header row
server_list.delete_at(0);

# Get rid of the header seperator
server_list.delete_at(0);

$peer_count = server_list.size;

# Split the remaining server entries into sub arrays
for i in 0 ... $peer_count
	server_list[i] = server_list[i].gsub(/\s+/m, " ").strip.split(" ");

	# Check for first character of peer
	# space = Discarded due to high stratum and/or failed sanity checks.
	# x = Designated falseticker by the intersection algorithm.
	# . = Culled from the end of the candidate list.
	# - = Discarded by the clustering algorithm.
	# + = Included in the final selection set.
	# # = Selected for synchronization but distance exceeds maximum.
	# * = Selected for synchronization.
	# o = Selected for synchronization, pps signal in use.
	if server_list[i][0] =~ /^\*/
		$selected_primary = true;
	elsif server_list[i][0] =~ /^\+/
		$selected_backup += 1;
	end

	# Reset health count to 0
	health_count = 0;

	# Convert the Reach to Octal and then Binary
	reach = server_list[i][6].to_i(8).to_s(2);

	# Cycle through reach string to calculate the health percent
	for j in 0 ... reach.size
		health_count += reach[j..j].to_i;
	end

	# Calculate this peer's health as a percentage
	health = (health_count / reach.size) * 100;

	# Add peer to hash
	$peer_health [server_list[i][0]] = health;
end

# Cycle through peer hash and add up the peer's healths
$peer_health.each do |peer, health|
	$overall_health += health.to_i;
end

# Calculate the average health
$overall_health /= $peer_count;

##### Nagios parsing #####
# If overall health is at or below the critical threshold value, critical
if ($overall_health <= options[:critical_threshold])
	print_overall_health("Critical");
	exit 2;
# If overall health is at or below than the warning threshold value, warning
elsif ($overall_health <= options[:warning_threshold])
	print_overall_health("Warning");
	exit 1;
end


# If the number of peers is at or below the critical threshold, critical
if ($peer_count <= options[:peer_critical_threshold])
	print_overall_health("Critical");
	exit 2;
# If the number of peers is at or below the warning threshold, warning
elsif ($peer_count <= options[:peer_warning_threshold])
	print_overall_health("Warning");
	exit 1;
end

# If there are no primary NTP peers selected, critical
if ($selected_primary != true)
	print_overall_health("Critical");
	puts "No primary NTP peer selected.";
	exit 2;
# If there are no backup NTP peers selected, warning
elsif ($selected_backup < 1)
	print_overall_health("Warning");
	puts "No backup NTP peer selected.";
	exit 1;
end

# If none of the previous checks triggered an alarm, OK
print_overall_health("OK");
exit 0;
