package ValidatorPackagesTest1;

sub match_single_validator_success_expected {
	my $val = shift;
	return 1;
}

sub match_single_validator_failure_expected {
	return undef;
}

1;
