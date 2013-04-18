#!/usr/bin/perl
#===============================================================================
#
#         FILE:SV_TranslocCheck.pl
#
#        USAGE:
#
#  DESCRIPTION:This program is used to check the breakpoints of translocation,
#              which are generated by breakdancer
#
#      OPTIONS: -i <Breakpoint_File> -b <Bam_File> -r <Reference_File> [options]
# REQUIREMENTS: samtools,phrap,cross_match,Bam_Convert2Fasta.pl
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Yuan Chen
#      COMPANY: Division of Infectious Disease, DUMC
#      VERSION: 1.0
#      CREATED: 10/13/2012
#     REVISION:
#===============================================================================

use strict;
use Getopt::Long;
use File::Temp;
use File::Basename;

my %opts;
GetOptions(\%opts,"i=s","b=s","r=s","c:i","f:i","v:i","l:i");
if(! defined($opts{i}) || ! defined($opts{b}) || ! defined($opts{r})){
    &Usage();
}

my $parInputFile=$opts{i};
my $parBamFile=$opts{b};
my $parRefFile=$opts{r};
my $parCutoff=$opts{c};
my $parFlanklen=$opts{f};
my $BaseName=basename($parInputFile);
my $parResultFile="$BaseName.rst";
my $parDetailFile="$BaseName.dtl";
my $parReadsCov=$opts{v};
my $parReadLen=$opts{l};

$parCutoff ||= 90;
$parFlanklen ||= 250;
$parReadsCov ||=800;
$parReadLen ||=100;

my $maxReadsnum=($parFlanklen*4*$parReadsCov)/$parReadLen;

my @breakpoints;
my %refchroms;

if(!-e ($parInputFile)){
    die "Can't open file: $parInputFile\n";
}

if(!-e ($parBamFile)){
    die "Can't open file: $parBamFile\n";
}

open (my $fh_BAM, "samtools view -h $parBamFile |");
while(<$fh_BAM>){
    chomp();
    if(/^\@SQ/){
        my ($chrom)=($_=~/SN\:(\S+)/);
        my ($len)=($_=~/LN\:(\d+)/);
        $refchroms{$chrom}=$len;
        #print "$chrom\t$len\n";
    }
    last if(/^\@RG/);
}
close $fh_BAM;

my $tempfile="$parInputFile.tmp";

`grep -v -i '^#' $parInputFile | sort -k 1,1 -k 2,2n -k 4,4 -k 5,5n > $tempfile`;

open(my $fh_tempfile, $tempfile);


my %deletepoints;
my $lastchrom;
my $lastsite;
my $lastmatchchrom;
my $lastmatchsite;

while(<$fh_tempfile>){
    chomp();
    my @lines=split(/\t/,$_);
    next if($lines[6] ne "CTX");
    next if($lines[8] < $parCutoff);
    next if(exists $deletepoints{$lines[0]}->{$lines[1]});
    if($lastchrom eq $lines[0]){ ##remove the breakpoints in putative repeat region
        if($lastsite eq $lines[1]){
            if ($lastmatchchrom ne $lines[3]){
                $deletepoints{$lastchrom}->{$lastsite}=1;
                next;
            }
            else{
                if(abs($lastmatchsite-$lines[4]) > 4*$parFlanklen){
                    $deletepoints{$lastchrom}->{$lastsite}=1;
                    next;
                }
            }
        }
    }

    $lastchrom=$lines[0];
    $lastsite=$lines[1];
    $lastmatchchrom=$lines[3];
    $lastmatchsite=$lines[4];
    push(@breakpoints,$_);
}
close $fh_tempfile;

unlink ($tempfile);

for(my $i=0;$i<@breakpoints;$i++){
    my @lines=split(/\t/,$breakpoints[$i]);
    if(exists $deletepoints{$lines[0]}->{$lines[1]}){
        splice(@breakpoints,$i,1);
        $i--;
    }
}

open (my $fh_rstfile,">$parResultFile");
open (my $fh_dtlfile,">$parDetailFile");

my $breakpoints_count=0;
foreach my $breakpoint(@breakpoints){
    $breakpoints_count++;
    my @lines=split(/\t/,$breakpoint);
    my $chrom_a=$lines[0];
    my $site_a=$lines[1];
    my $chrom_b=$lines[3];
    my $site_b=$lines[4];
    #print "$chrom_a\t$site_a\t$chrom_b\t$site_b\n";
    my $site_a_start=$site_a-$parFlanklen;
    $site_a_start=0 if($site_a_start<0);
    my $site_b_start=$site_b-$parFlanklen;
    $site_b_start=0 if($site_b_start<0);
    my $site_a_end=$site_a+$parFlanklen;
    $site_a_end=$refchroms{$chrom_a} if ($site_a_end > $refchroms{$chrom_a});
    my $site_b_end=$site_b+$parFlanklen;
    $site_b_end=$refchroms{$chrom_b} if ($site_b_end > $refchroms{$chrom_b});
    my $FasTempfile=File::Temp::tempnam(".","fastmp");
    $FasTempfile=basename($FasTempfile);
    #print "$chrom_a\:$site_a_start\-$site_a_end $chrom_b\:$site_b_start\-$site_b_end\n";
    `perl ~/bin/perl/Alignment/Bam_Convert2Fasta.pl $parBamFile \"$chrom_a\:$site_a_start\-$site_a_end $chrom_b\:$site_b_start\-$site_b_end\" $FasTempfile`;
    #print "perl ~/bin/perl/Alignment/Bam_Convert2Fasta.pl $parBamFile \"$chrom_a\:$site_a_start\-$site_a_end $chrom_b\:$site_b_start\-$site_b_end $FasTempfile";
    my $fascheck=&fascheck("$FasTempfile.fas");
    
    if($fascheck==0){
	print $fh_rstfile "$breakpoints_count\t$breakpoint\tRepeatRegion\n";
	unlink ("$FasTempfile.fas");
	unlink ("$FasTempfile.fas.qual");
	next;
    }
    
    `phrap $FasTempfile.fas -minscore 20 -vector_bound 0 -bandwidth 2 -max_group_size 0 -view -revise_greedy`;
    #print "phrap $FasTempfile.fas -minscore 20 -vector_bound 0 -bandwidth 2 -max_group_size 0 -view -revise_greedy";
    
    &fasfilter("$FasTempfile.fas.contigs");
    
    `cross_match $FasTempfile.fas.contigs.flt $parRefFile > $FasTempfile.aln`;
    #print "cross_match $FasTempfile.fas.contigs $parRefFile > $FasTempfile.aln";
    
    my $result=&Analysis_Crossmatch($FasTempfile,$chrom_a,$site_a,$chrom_b,$site_b,$breakpoints_count);
    if($result==1){
	print $fh_rstfile "$breakpoints_count\t$breakpoint\tApproved\n";
    }
    else{
	print $fh_rstfile "$breakpoints_count\t$breakpoint\tFailed\n"
    }
    opendir(my $DH,".");
    my @tmpfiles=grep {/$FasTempfile/} readdir($DH);
    close $DH;
    unlink (@tmpfiles);
}

exit(0);

sub Analysis_Crossmatch
{
    my ($TempFile,$Chrom_a,$Site_a,$Chrom_b,$Site_b,$breakcount)=@_;
    my $AlnFile="$TempFile.aln";
    my $SeqFile="$TempFile.fas.contigs";
    open(my $fh_alnfile,"$AlnFile");
    my $isReadStart=0;
    my $lastCName="";
    my %hashmap=();
    my $hashcount=0;
    my @mapinfo;
    my $isproved=0;
    my $matchcount=0;
    while(<$fh_alnfile>){
	chomp();
	next if($_ eq ""); 
	if(/^Maximal single base matches/){
            $isReadStart=1;
            next;
        }
	last if(/^\d+\smatching entries/);
	if($isReadStart==1){
	    my @lines=split(/\s+/,$_);
            my $FieldShift=0;
            $FieldShift++ if($lines[0] ne "");
	    my $contigN=$lines[5-$FieldShift];
            my $isRev=0;
            if($lines[9-$FieldShift] eq "C"){
                $isRev=1;
                $FieldShift--;
            }
            if($lastCName ne $contigN){
                if((keys %hashmap) >= 2){
                    my ($mapresult,$breakchrom_a,$breaksite_a,$breakchrom_b,$breaksite_b)=&sitecheck(\%hashmap,$Chrom_a,$Site_a,$Chrom_b,$Site_b);
                    if($mapresult==1){
                        $isproved=1;
			$matchcount++;
                        print $fh_dtlfile "\@$breakcount\-$matchcount\t$Chrom_a,$Site_a,$Chrom_b,$Site_b\t$breakchrom_a,$breaksite_a,$breakchrom_b,$breaksite_b\n";
                        print $fh_dtlfile "\#$breakcount\-$matchcount\n";
                        print $fh_dtlfile join("\n",@mapinfo),"\n";
                        print $fh_dtlfile "\>$breakcount\-$matchcount\n";
                        my $contigfile="$TempFile.fas.contigs";
                        my $seq=&searchseq($lastCName,$contigfile);
                        print $fh_dtlfile "$seq\n";
                    }
                }
                %hashmap=();
                @mapinfo=();
                $lastCName=$contigN;
                $hashcount=0;
            }
            my @outline=@lines;
            shift(@outline) if($outline[0] eq "");
            if($outline[8] eq "C"){
                $outline[8]="-";
            }
            else{
                splice(@outline,8,0,"+");
            }
	    splice(@outline,4,1);
            push(@mapinfo,join("\t",@outline));
            my $MapChrom=$lines[9-$FieldShift];
            $hashmap{$hashcount}->{'n'}=$MapChrom;
            if($isRev==0){
                $hashmap{$hashcount}->{'s'}=$lines[10-$FieldShift];
                $hashmap{$hashcount}->{'e'}=$lines[11-$FieldShift];
                $hashmap{$hashcount}->{'d'}='+';
            }
            else{
                $hashmap{$hashcount}->{'s'}=$lines[12-$FieldShift];
                $hashmap{$hashcount}->{'e'}=$lines[11-$FieldShift];
                $hashmap{$hashcount}->{'d'}='-';
            }
            $hashcount++;
	}
    }
    if((keys %hashmap) >= 2){
        my ($mapresult,$breakchrom_a,$breaksite_a,$breakchrom_b,$breaksite_b)=&sitecheck(\%hashmap,$Chrom_a,$Site_a,$Chrom_b,$Site_b);
        if($mapresult==1){
	    $isproved=1;
	    $matchcount++;
	    print $fh_dtlfile "\@$breakcount\-$matchcount\t$Chrom_a,$Site_a,$Chrom_b,$Site_b\t$breakchrom_a,$breaksite_a,$breakchrom_b,$breaksite_b\n";
	    print $fh_dtlfile "\#$breakcount\-$matchcount\n";
	    print $fh_dtlfile join("\n",@mapinfo),"\n";
	    print $fh_dtlfile "\>$breakcount\-$matchcount\n";
	    my $contigfile="$TempFile.fas.contigs";
	    my $seq=&searchseq($lastCName,$contigfile);
	    print $fh_dtlfile "$seq\n";
        }
	
    }
    if($isproved==1){
	return 1;
    }
    else{
	return 0;
    }
}

sub searchseq(){
    my ($seqName,$filename)=@_;
    open(my $fh_fasfile,$filename);
    my $seq;
    my $isout=0;
    while(<$fh_fasfile>){
        if(/^>(\S+)/){
            return $seq if($isout==1);
            if($1 eq $seqName){
                $isout=1;
            }
        }
        else{
            if($isout==1){
                $seq.=$_;
            }
        }
    }
    
    return $seq;
}

sub sitecheck(){
    my ($refhashmap,$Chrom_a,$Site_a,$Chrom_b,$Site_b)=@_;
    my %hashmap=%{$refhashmap};
    my $ismap_a=0;
    my $ismap_b=0;
    my $flank_a_s=$Site_a-$parFlanklen*1.5;
    my $flank_a_e=$Site_a+$parFlanklen*1.5;
    my $flank_b_s=$Site_b-$parFlanklen*1.5;
    my $flank_b_e=$Site_b+$parFlanklen*1.5;
    my $mapcount=0;
    my $breakchrom_a;
    my $breakchrom_b;
    my $breaksite_a;
    my $breaksite_b;
    foreach my $count(sort {$a<=>$b} keys %hashmap){
        my $chrom=$hashmap{$count}->{'n'};
        my $map_s=$hashmap{$count}->{'s'};
        my $map_e=$hashmap{$count}->{'e'};
        my $map_d=$hashmap{$count}->{'d'};
        my $issearch=0;
        if($chrom eq $Chrom_a){
            if(($flank_a_s <= $map_s && $flank_a_e >= $map_s) || ($flank_a_s <= $map_e && $flank_a_e >=$map_e)){
                $ismap_a=1;
                $issearch=1;
            }
        }
        elsif($chrom eq $Chrom_b){
            if(($flank_b_s <= $map_s && $flank_b_e >= $map_s) || ($flank_b_s <= $map_e && $flank_b_e >=$map_e)){
                $ismap_b=1;
                $issearch=1;
            }
        }
        else{
            delete $hashmap{$count};
        }
        if($issearch==1){
            if($mapcount==0){
                $breakchrom_a=$chrom;
                if($map_d eq "+"){
                    $breaksite_a=$map_e;
                }
                else{
                    $breaksite_a=$map_s;
                }
            }
            else{
                $breakchrom_b=$chrom;
                if($map_d eq "+"){
                    $breaksite_b=$map_s;
                }
                else{
                    $breaksite_b=$map_e;
                }
            }
            $mapcount++;
        }
    }
    if($ismap_a==1 && $ismap_b==1){
        return (1,$breakchrom_a,$breaksite_a,$breakchrom_b,$breaksite_b);
    }
    else{
        return 0;
    }
    
}

sub fasfilter(){
    my $filein=shift;
    my $fileout="$filein.flt";
    open (my $fh_filein,$filein);
    open (my $fh_fileout,">$fileout");
    my $seq;
    my $seqN;
    while(<$fh_filein>){
	chomp();
	if(/^>\S+/){
	    if(length($seq)>=$parFlanklen){
		print $fh_fileout "$seqN\n$seq\n";
	    }
	    $seqN=$_;
	    $seq="";
	}
	else{
	    $seq=$seq.$_;
	}
    }
    if(length($seq)>=$parFlanklen){
	print $fh_fileout "$seqN\n$seq\n";
    }
    close $fh_filein;
    close $fh_fileout;
}

sub fascheck()
{
    my $fasfile=shift;
    my $seqcount;
    open(my $fh_fasfile,$fasfile);
    while(<$fh_fasfile>){
	$seqcount++ if(/^>/);
    }
    if($seqcount>$maxReadsnum){
	return 0;
    }
    else{
	return 1;
    }
}


sub Usage #help subprogram
{
    print << "    Usage";

	Usage: $0 -i <Breakpoint_File> -b <Bam_File> -r <Reference_File> [options]

        Options: -c     Cutoff of the breakpoint score, default 90

                 -f     Flanking length from the breakpoint (both sides), default 250
		 
		 -v     Maximum coverage, default 800
		 
		 -l     Reads length, default 100

    Usage

	exit(0);
};