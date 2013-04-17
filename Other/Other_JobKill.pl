#!/usr/bin/perl
use strict;

my ($startid,$endid)=@ARGV;
if(@ARGV<2){
	print "Usage:$0 StartId EndId\n";
	exit(1);
}

for(my $i=$startid;$i<=$endid;$i++){
	print "bkill $i\n";
	`bkill $i`;
}

print "All jobs have been killed\n";
exit(0);
