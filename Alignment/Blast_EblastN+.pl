#!/usr/bin/perl
#This progrem transfer the BLAST+ result include the Query sites and Sbject sites to the excel file.
$vision="Vision: 2.0"; #nipx 2001-7-20
$vision="Vision: 3.0"; #nipx 2002-4-11
$vision="Vision: 4.0"; #zhangjg 2003-8-28
$vision="Vision: 5.0"; #Alvin Chen 2011-4-6
use Getopt::Std;
getopts "o:i:e:a:l:s:z:d:m:c:b:t";

print "*************\n*$vision*\n*************\n";
if ((!defined $opt_i)|| (!defined $opt_o) ) {
	die "************************************************************************
	Usage:transferall.pl -i filename -o outfile.
	  -h : help and usage.
	  -v : $vision.
	  -e : expect value(default 10)
	  -a : identity% (default 10)
	  -c : query coverage (default 0)
	  -b : subject coverage (default 0)
	  -l : alignment length (default 0)
	  -s : score (default 0)
	  -z : the block number of every query	(default 10000)
	  -d : the block number of every sbjct  (default 10000)
	  -m : detailed description of sbjct y/n (default n)
	  -t : print title (default 0)
************************************************************************\n";
}
if($opt_i eq $opt_o) { die"infile = outfile?"; }
$Expect = (defined $opt_e) ? $opt_e : 10;
$Length = (defined $opt_l) ? $opt_l : 0;
$Identity = (defined $opt_a) ? $opt_a : 10;
$Score = (defined $opt_s) ? $opt_s : 0;
$QCoverage=(defined $opt_c) ? $opt_c : 0;
$SCoverage=(defined $opt_b) ? $opt_b : 0;
$Query_num = (defined $opt_z) ? $opt_z : 10000;
$Sbjct_num = (defined $opt_d) ? $opt_d : 10000;
$Sbjct_description = (defined $opt_m) ? $opt_m : "n";
$Printtitle=(defined $opt_t)? $opt_t: 0;

open(Ofile,">$opt_o");print "Running.....\n";
open (F,$opt_i) || die"can't open $opt_i:$!\n";
$i=$q=$s=$a=0;
if($Sbjct_description eq "y")
{
	if($Printtitle==1){
		printf Ofile "Query-name\tLetter\tQueryX\tQueryY\tSbjctX\tSbjctY\tLength\tScore\tE-value\tOverlap/total\tIdentity\tSbject-Name\tSbjct_description\n";
	}
}
elsif($Sbjct_description eq "n")
{
	if($Printtitle==1){
		printf Ofile "Query-name\tLetter\tQueryX\tQueryY\tSbjctX\tSbjctY\tLength\tScore\tE-value\tOverlap/total\tIdentity\tSbject-Name\n";
	}
}
else { die"\$Sbjct_description(-m) should be y/n.\n"; }

my $isSubject=0;
while (<F>)
{
	if (/Query= (\S+)/)
	{
            $isSubject=0;
		if($i==1)
		{
			#print Ofile "$query^$letter^Query:$qbegin----$qend^Sbject:$sbegin----$send^$name^$annotation^$length^$score^$expect^$identity^$over\n";
			my $qcover=((abs($qend-$qbegin))/$letter*100);
			my $scover=((abs($sbegin-$send))/$length*100);
			if($score >$Score && $expect<=$Expect && $over>=$Identity && $identity2 >= $Length && $query_num <= $Query_num && $sbjct_num <= $Sbjct_num && $qcover>=$QCoverage && $scover>=$SCoverage)
			{
				$ovalap_total = "$identity1/$identity2";
				if($Sbjct_description eq "y")
				{
					print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\t$annotation\n";
				}
				elsif($Sbjct_description eq "n")
				{
					print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\n";
				}
			}
			$i=$q=$s=0;
			$query=$letter=$qbegin=$qend=$sbegin=$send=$name=$annotation=$length=$score=$expect=$identity=$over=0;
		}
		$query=$1;
		$query_num = 0;
	}
	elsif (/^>(\S*)\s*(.*)/)
	{
		if($i==1)
		{
			my $qcover=((abs($qend-$qbegin))/$letter*100);
			my $scover=((abs($sbegin-$send))/$length*100);
			if($score >$Score && $expect<=$Expect && $over>=$Identity && $identity2 >= $Length && $query_num <= $Query_num && $sbjct_num <= $Sbjct_num && $qcover>=$QCoverage && $scover>=$SCoverage)
			{
				$ovalap_total = "$identity1/$identity2";
				if($Sbjct_description eq "y")
				{
					print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\t$annotation\n";
				}
				elsif($Sbjct_description eq "n")
				{
					print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\n";
				}
			}
			$i=$q=$s=0;
			$qbegin=$qend=$sbegin=$send=$name=$annotation=$length=$score=$expect=$identity=$over=0;
		}
		$name=$1;
		$annotation=$2;
		$a=1;
		$sbjct_num = 0;
	}
	elsif (/Length=(\d+)/)
	{
		if ($isSubject==0) {
                    $letter=$1;
                    $isSubject=1;
                }
                else{
                    $length=$1;
                    $a=0;
                }
		
	}
	elsif ($a==1)
	{
		chomp;
		$annotation.=$_;
		$annotation=~s/\s+/ /g;
	} #This sentence could get the very long annotation that is longer than one line;
	elsif (/Score = (.+) bits.+Expect\S* =\s+(\S+),\s*/)
	{
		if($i==1)
		{
			my $qcover=((abs($qend-$qbegin))/$letter*100);
			my $scover=((abs($sbegin-$send))/$length*100);
			if($score >$Score && $expect<=$Expect && $over>=$Identity && $identity2 >= $Length && $query_num <= $Query_num && $sbjct_num <= $Sbjct_num && $qcover>=$QCoverage && $scover>=$SCoverage)
			{
				$ovalap_total = "$identity1/$identity2";
				if($Sbjct_description eq "y")
				{
					print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\t$annotation\n";
				}
				elsif($Sbjct_description eq "n")
				{
					print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\n";
				}
			}
			$i=$q=$s=0;
			$qbegin=$qend=$sbegin=$send=$score=$expect=$identity=$over=0;
		}
		$query_num++;
		$sbjct_num++;
		$score=$1;$expect=$2;$expect=~s/^e/1e/;
	}
	elsif (/Identities = (\d+)\/(\d+)\s+\((.{0,4})%\)/)
	{
		$identity1=$1;
		$identity2=$2;
		$over=$3;
	}
	elsif (/Query\s+(\d+)\s*(\S+)\s+(\d+)/)
	{
		if($q==0)
		{
			$qbegin=$1;
			$query_seq = $2;
		}
		else { $query_seq .= $2; }
		$qend=$3;
		$q=1;
	}
	elsif (/Sbjct\s+(\d+)\s*\S+\s+(\d+)/)
	{
		if($s==0)
		{
			$sbegin=$1;
		}
		$send=$2;
		$s=$i=1;
	}
}

if(($score >$Score && $expect<=$Expect && $over>=$Identity && $identity2 >= $Length && $query_num <= $Query_num && $sbjct_num <= $Sbjct_num)&&($i==1))
{
	my $qcover=((abs($qend-$qbegin))/$letter*100);
	my $scover=((abs($sbegin-$send))/$length*100);
	if($qcover>=$QCoverage && $scover>=$SCoverage){
		$ovalap_total = "$identity1/$identity2";
		if($Sbjct_description eq "y")
		{
			print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\t$annotation\n";
		}
		elsif($Sbjct_description eq "n")
		{
			print Ofile "$query\t$letter\t$qbegin\t$qend\t$sbegin\t$send\t$length\t$score\t$expect\t$ovalap_total\t$over\t$name\n";
		}
	}
}
close(F);
close(Ofile);
