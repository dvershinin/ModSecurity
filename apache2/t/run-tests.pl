#!/usr/bin/perl
#
# Run unit tests.
#
# Syntax:
#          All: run-tests.pl
#	 All in file: run-tests.pl file
#	 Nth in file: run-tests.pl file N
#
use strict;
use File::Basename qw(basename dirname);

my @TYPES = qw(tfn op);
my $TEST = "./msc_test";
my $SCRIPT = basename($0);
my $SCRIPTDIR = dirname($0);
my $PASSED = 0;
my $TOTAL = 0;

if (defined $ARGV[0]) {
	runfile(dirname($ARGV[0]), basename($ARGV[0]), $ARGV[1]);
	done();
}

for my $type (sort @TYPES) {
	my $dir = "$SCRIPTDIR/$type";
	my @cfg = ();

	# Get test names
	opendir(DIR, "$dir") or quit(1, "Failed to open \"$dir\": $!");
	@cfg = grep { /\.t$/ && -f "$dir/$_" } readdir(DIR);
	closedir(DIR);

	for my $cfg (sort @cfg) {
		runfile($dir, $cfg);
	}

}
done();


sub runfile {
	my($dir, $cfg, $testnum) = @_;
	my $fn = "$dir/$cfg";
	my @data = ();
	my $edata;
	my @C = ();
	my $n = 0;
	my $pass = 0;

	open(CFG, "<$fn") or quit(1, "Failed to open \"$fn\": $!");
	@data = <CFG>;
	
	$edata = q/@C = (/ . join("", @data) . q/)/;
	eval $edata;
	quit(1, "Failed to read test data \"$cfg\": $@") if ($@);

	unless (@C) {
		msg("\nNo tests defined for $fn");
		return;
	}

	msg("\nLoaded ".@C." tests from $fn");
	for my $t (@C) {
		$n++;
		next if (defined $testnum and $n != $testnum);

		my %t = %{$t || {}};
		my $id = sprintf("%6d", $n);
		my $in = $t{input};
		my $rc = 0;
		my $param;

		if ($t{type} eq "tfn") {
			$param = escape($t{output});
		}
		elsif ($t{type} eq "op") {
			$param = escape($t{param});
		}
		else {
			quit(1, "Unknown type \"$t{type}\" - should be one of: " . join(",",@TYPES));
		}

		open(TEST, "|-", $TEST, $t{type}, $t{name}, $param, (exists($t{ret}) ? ($t{ret}) : ())) or quit(1, "Failed to execute test \"$cfg\": $!");
		print TEST "$in";
		close TEST;


		$rc = $?;
		$pass += $rc ? 0 : 1;
		msg(sprintf("%s) %s \"%s\": %s", $id, $t{type}, $t{name}, ($rc ? "failed" : "passed")));
		
	}

	$TOTAL += $testnum ? 1 : $n;
	$PASSED += $pass;

	msg(sprintf("Passed: %2d; Failed %2d", $pass, $testnum ? (1 - $pass) : ($n - $pass)));
}

sub escape {
	my @new = ();
	for my $c (split(//, $_[0])) {
		push @new, ((ord($c) >= 0x20 and ord($c) <= 0x7e) ? $c : sprintf("\\x%02x", ord($c)));
	}
	join('', @new);
}

sub msg {
	print STDOUT "@_\n" if (@_);
}

sub quit {
	my($ec,$msg) = @_;
	$ec = 0 unless (defined $_[0]);

	msg("$msg") if (defined $msg);

	exit $ec;
}

sub done {
	if ($PASSED != $TOTAL) {
		quit(1, "\n$PASSED/$TOTAL tests passed.");
	}

	quit(0, "\nAll tests passed ($TOTAL).");
}
