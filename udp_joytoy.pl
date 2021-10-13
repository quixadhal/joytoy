#!/usr/bin/perl -w

use strict;
use IO::Socket::INET;
use Data::Dumper;

my $serverAddress   = '127.0.0.1';
my $serverPort      = 6781;

$| = 1; # flush I/O immediately

my $programName = $ARGV[0];
my $mode = shift || "server";

if ($mode =~ /server/i) {
    my $socket = new IO::Socket::INET(
        LocalPort   => $serverPort,
        Proto       => 'udp',
    ) or die "Cannot open server socket: $!";
    my $data = undef;
    my $done = undef;

    until($done) {
        my $ok = $socket->recv($data, 1024);
        if($ok) {
            my $len = length $data;
            my $peerAddress = $socket->peerhost();
            my $peerPort = $socket->peerport();
            #print "Got $len bytes from $peerAddress:$peerPort\n" . Dumper($data);
            print "Got $len bytes from $peerAddress:$peerPort\n";
            my @fields = unpack('CCNnn!n!n!n!n!n!B16', $data);
            print "Received: " . Dumper(\@fields);
            $done = 1 if $fields[0];
            $data = undef;
        } else {
            $done = 1;
        }
    }
    sleep 2;
    $socket->close();
    print "Server done.\n";
} elsif ($mode =~ /client/i) {
    my $socket = new IO::Socket::INET(
        PeerAddr    => "$serverAddress:$serverPort",
        Proto       => 'udp',
    ) or die "Cannot open client socket: $!";
    my @data = (0, time(), 666);
    foreach (0.751, 0.0, 0.0, 0.0, -1.0, 0.0) {
        push @data, (int ($_ * 32767));
    }
    @data = (@data, 1,0,0,0,0, 0,0,0,0, 0,0,0,0);
    my $packed = pack('CCNnn!n!n!n!n!n!B16', @data);
    my $len = length $packed;
    print "Sent $len bytes to $serverAddress:$serverPort\n" . Dumper($packed);
    $socket->send($packed);
    sleep 1;
    @data = (1, time(), 777);
    foreach (-0.751, 0.0, 0.0, 0.0, 1.0, 0.0) {
        push @data, (int ($_ * 32767));
    }
    @data = (@data, 0,0,0,1,0, 0,0,0,0, 0,0,0,0);
    $packed = pack('CCNnn!n!n!n!n!n!B16', @data);
    $len = length $packed;
    print "Sent $len bytes to $serverAddress:$serverPort\n" . Dumper($packed);
    $socket->send($packed);
    sleep 2;
    $socket->close();
    print "Client done.\n";
} else {
    print "usage: $programName < client|server >\n";
}

