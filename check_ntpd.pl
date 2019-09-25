#!/usr/bin/perl -w

#Plugin checks ntpq, then chronyc, then systemd_timesyncd;
#You should use only ONE method for time sync and remove other packages
#Plugin search ntpq binary, then chronyc binary, then /etc/systemd/timesyncd.conf config file.

use Getopt::Long;
use strict;

GetOptions(
                "critical=i" => \(my $critical_threshold = '50'),
                "warning=i" => \(my $warning_threshold = '75'),
                "peer_critical=i" => \(my $peer_critical_threshold = '1'),
                "peer_warning=i" => \(my $peer_warning_threshold = '2'),
                "help" => \&display_help,
);

$ENV{PATH}="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin";
my $use_ntp = 1;
my $use_chrony = 0;
my $use_systemd_timesyncd = 0;

my $chronyc_path;
my $ntpq_path = `/usr/bin/which ntpq 2>/dev/null`;

if ($? != 0) { 
     $use_ntp = 0; 
     $chronyc_path = `/usr/bin/which chronyc 2>/dev/null`;
     if ($? == 0) { $use_chrony = 1; }
     else {
       if (-e "/etc/systemd/timesyncd.conf") { $use_systemd_timesyncd=1; }
     }
}
if ( $use_ntp==0 && $use_chrony==0 && $use_systemd_timesyncd==0 ) {
        print "No ntpq or chronyc or systemd-timesyncd found. You need to setup timesync";
        exit 3;
}

my %server_health;
my $peer_count = 0;
my $overall_health = 0;
my $good_count = 0;
my $selected_primary;
my $selected_backup = 0;


if ( $use_ntp==1 ) {
     print "ntpq check ";
     $ntpq_path =~ s/\n//g;
     #ignore IPv6 interfaces
     my $ntpq_options="-4pn";
     #Solaris 9 and Solaris 10 have no -4 option in ntpq
     my $osvers = `uname -r`;
     if ( $osvers  =~ "5.10" || $osvers  =~ "5.9") { $ntpq_options="-pn" }
     my @server_list = `$ntpq_path $ntpq_options 2>/dev/null`;

     # Cleanup server list
     for(my $i = 0; $i < @server_list; $i++) {
        if($server_list[$i] =~ /LOCAL/) {
                splice(@server_list, $i, 1);
                $i--;
        } elsif($server_list[$i] =~ /^===/) {
                splice(@server_list, $i, 1);
                $i--;
        } elsif($server_list[$i] =~ /jitter$/) {
                splice(@server_list, $i, 1);
                $i--;
        } elsif($server_list[$i] =~ /disp$/) {
                splice(@server_list, $i, 1);
                $i--;
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
        my $rearch = oct($tmp_array[6]);

        # while $rearch is not 0
        while($rearch) {
                # 1s place 0 or 1?
                $good_count += $rearch % 2;
                # Bit shift to the right
                $rearch = $rearch >> 1;
        }

        # Calculate good packets received
        $rearch = int(($good_count / 8) * 100);

        # Set percentage in hash
        $server_health{$tmp_array[0]} = $rearch;
     }

     # Cycle through hash and tally weighted average of peer health
     while(my($key, $val) = each(%server_health)) {
        $overall_health += $val * (1 / $peer_count);
     }
}

if ($use_chrony == 1) {
     print "chrony check ";
     $chronyc_path =~ s/\n//g;
     my @server_list = `$chronyc_path -4n sources 2>/dev/null`;

     # Cleanup server list
     for(my $i = 0; $i < @server_list; $i++) {
        if($server_list[$i] =~ /Cannot talk to daemon/) {
                splice(@server_list, $i, 1);
                $i--;
        } elsif($server_list[$i] =~ /^===/) {
                splice(@server_list, $i, 1);
                $i--;
        } elsif($server_list[$i] =~ /Stratum *Poll *Reach *LastRx *Last *sample/) {
                splice(@server_list, $i, 1);
                $i--;
        } elsif($server_list[$i] =~ /Number of sources/) {
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

        # Check for second character of peer
        # '*' = current synced
        # '+' = combined 
        # '-' = not combined,
        # ?' = unreachable
        # 'x' = time may be in error
        # '~' = time too variable.
        if(substr($tmp_array[0], 1, 1) eq '*') {
                $selected_primary = "true";
        } elsif(substr($tmp_array[0], 1, 1) eq '+') {
                $selected_backup++;
        }

        $good_count = 0;
        # Read in the octal number in column 4

        my $rearch = oct($tmp_array[4]);

        # while $rearch is not 0
        while($rearch) {
                # 1s place 0 or 1?
                $good_count += $rearch % 2;
                # Bit shift to the right
                $rearch = $rearch >> 1;
        }

        # Calculate good packets received
        $rearch = int(($good_count / 8) * 100);

        # Set percentage in hash
        $server_health{$tmp_array[1]} = $rearch;
     }

     # Cycle through hash and tally weighted average of peer health
     while(my($key, $val) = each(%server_health)) {
        $overall_health += $val * (1 / $peer_count);
     }


}

if ($use_systemd_timesyncd == 1) {
   print "systemd-timedated ";
   my $systemd_timesyncd_config = `cat /etc/systemd/timesyncd.conf | grep -v ^#`;
   my $systemd_timesyncd_status = `systemctl status systemd-timesyncd | sed -n 's|"||g; s|^ *||; s|Status: ||p'`;
   my $RC;
   if ($systemd_timesyncd_status =~ "^Synchronized to time server") { print "OK "; $RC = 0; }
   else { print "Critical "; $RC = 2; }
   print "$systemd_timesyncd_status";
   print "---------------------------\n";
   print "systemd-timedated.service config (/etc/systemd/timesyncd.conf)\n$systemd_timesyncd_config\n";
   exit $RC;
}

########################### Nagios Status checks ###########################
#if overall health is below critical threshold, crit
if($overall_health <= $critical_threshold) {
        print_overall_health("Critical");
        print_server_list();
        exit 2;
}

#if overall health is below warning and above critical threshold, warn
if(($overall_health <= $warning_threshold) && ($overall_health > $critical_threshold)) {
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

print_overall_health("OK");
print_server_list();
exit 0;

sub print_server_list {
        print "---------------------------\n";
        while(my($key, $val) = each(%server_health)) {
                print "Received " . $val . "% of the traffic from " . $key . "\n";
        }
}

sub print_overall_health {
        print $_[0] . " - NTPd Health is " . $overall_health . "% with " . $peer_count . " peers.\n";
}

sub display_help {
        print "This nagios check is to determine the health of the NTPd client on the local system.  It uses the reach attribute from 'ntpq -pn' to determine the health of each listed peer, and determines the average health based on the number of peers.  For example, if there are 3 peers, and one peer has dropped 2 of the last 8 packets, it's health will be 75%.  This will result in an overall health of about 92% ((100+100+75) / 3).\n";
        print "\n";
        print "Available Options:\n";
        print "\t--critical|-c <num>\t-Set the critical threshold for overall health (default:50)\n";
        print "\t--warning|-w <num>\t-Set the warning threshold for overall health (default:75)\n";
        print "\t--peer_critical <num>\t-Set the critical threshold for number of peers (default:1)\n";
        print "\t--peer_warning <num>\t-Set the warning threshold for number of peers (default:2)\n";
        print "\t--help|-h\t\t-display this help\n";
        exit 0;
}
