
# $Id$		 -*-perl-*-



# You should have a couple of IP addresses at your disposal

# This code is not supposed to be included into the distribution.


use Test::More;
use Net::DNS::Nameserver;
use Net::DNS::Resolver;
use strict;
use Data::Dumper;
plan tests => 3;

use vars qw(
	    $address
	    $TestPort
            $lameloop
            $tcptimeout
	    );




$lameloop = 0;
$TestPort = 53000 + int(rand(1000));
$address  = "127.0.0.1";

my $nameserver;

$nameserver=Net::DNS::Nameserver->new(
	LocalAddr        => $address,
	LocalPort        => $TestPort,
	ReplyHandler => \&reply_handler,
	NotifyHandler => \&notify_handler,
	Verbose          => 0,
	);



my $resolver=Net::DNS::Resolver->new(
    nameservers => [ $address ],
    port       => $TestPort,
    persistent_tcp => 1,
    debug    => 0,
    tcp_timeout => 2,
    );



sub reply_handler {
    my ($qname, $qclass, $qtype, $peerhost,$query,$conn) = @_;
    die "Sockhost failure" if ($conn->{"sockhost"} ne "127.0.0.1");
    die "Sockport failure" if ($conn->{"sockport"} ne $TestPort);
    use Data::Dumper;
    print Dumper $conn;
#    print "QNAME: $qname QTYPE: $qtype\n";
    # mark the answer as authoritive (by setting the 'aa' flag
    return ("NXDOMAIN");
}



sub notify_handler{
    my ($qname, $qclass, $qtype, $peerhost, $query,$conn) = @_;
    #print "NOTIFY: QNAME: $qname QTYPE: $qtype\n";
    # mark the answer as authoritive (by setting the 'aa' flag

    return ("NXDOMAIN",[],[],[],{ opcode => "NS_NOTIFY_OP" } );
}



my $notify_packet=Net::DNS::Packet->new("example.com", "SOA", "IN");
$notify_packet->header->opcode("NS_NOTIFY_OP");

#
# For each nameserver fork-off seperate process
#
#


my $pid;
 FORK: {
     no strict 'subs';  # EAGAIN
     if ($pid=fork) {# assign result of fork to $pid,

	 # Parent process here
	 $resolver->usevc(1);

	 $resolver->send("bla.foo","A");
	 my $answer=$resolver->send($notify_packet);
	 is($answer->header->opcode,"NS_NOTIFY_OP", "OPCODE set in reply");
	 sleep 1;
	 $resolver->send("bla.foo","A");
	 is($resolver->errorstring,"unknown error or no error","read_tcp failed after connection reset");


	 $resolver->send("bla.foo","A");
	 is($resolver->errorstring,"timeout","timout received");



     } elsif (defined($pid)) {
	  # Child process here
	  #parent process pid is available with getppid
	  # exec will transfer control to the child process,
	  $nameserver->loop_once(60);
	  $nameserver->loop_once(10);
	  exit;

      } elsif ($! == EAGAIN) {
	  # EAGAIN is the supposedly recoverable fork error
	  sleep 5;
	  redo FORK;
      }else {
	  #weird fork error
	  die "Can't fork: $!\n";
      }
}




$resolver->nameservers($address);
