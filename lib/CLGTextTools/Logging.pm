package CLGTextTools::Logging;

use strict;
use warnings;
use Log::Log4perl;
use Carp;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw/initLogging @possibleLogLevels confessLog warnLog cluckLog/;

our @possibleLogLevels = qw/TRACE DEBUG INFO WARN ERROR FATAL OFF/;



=head1 DESCRIPTION

Provides simplified logging procedures.

=cut








=head2 createDefaultLogConfig($filename, $logLevel, $alsoToScreen, $synchronized)

static.

creates a simple log configuration for log4perl, usable with Log::Log4perl->init($config)

=cut

sub createDefaultLogConfig {
	my ($filename, $logLevel,$alsoToScreen, $synchronized) = @_;
	my $config = "";
	if ($alsoToScreen) {
	    $config .= "log4perl.rootLogger              = $logLevel, LOGFILE, LOGSCREEN\n";
	} else {
	    $config .= "log4perl.rootLogger              = $logLevel, LOGFILE\n";
	}
	$config .= qq(
log4perl.rootLogger.Threshold = OFF
log4perl.appender.LOGFILE           = Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename  = $filename
log4perl.appender.LOGFILE.mode      = write
log4perl.appender.LOGFILE.utf8      = 1
log4perl.appender.LOGFILE.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern = [%r] %d %p %m\t from %c in %M (%F %L)%n
);
	if ($synchronized) {
		$config .= "log4perl.appender.LOGFILE.syswrite  = 1\n";
	}
	if ($alsoToScreen) {
		$config .= qq(
log4perl.appender.LOGSCREEN          = Log::Log4perl::Appender::Screen
log4perl.appender.LOGSCREEN.stderr   = 0
log4perl.appender.LOGSCREEN.layout   = PatternLayout
log4perl.appender.LOGSCREEN.layout.ConversionPattern = %p> %m%n
);
	}
	return \$config;
}



=head2 initLog($logConfigFileOrLevel, $logFilename, $alsoToScreen, $synchronized)

static.

initializes a log4perl object in the following way: if
$logConfigFileOrLevel is a log level, then uses the default config
(directed to $logFilename), otherwise $logConfigFileOrLevel is
supposed to be the log4perl config file to be used.

=cut

sub initLog {
	my ($logConfigFileOrLevel, $logFilename, $alsoToScreen, $synchronized) = @_;
  	my $logLevel = undef;
#  	if (defined($logParam)) {
	if (grep(/^$logConfigFileOrLevel/, @possibleLogLevels)) {
		Log::Log4perl->init(createDefaultLogConfig($logFilename, $logConfigFileOrLevel, $alsoToScreen, $synchronized));
	} else {
		Log::Log4perl->init($logConfigFileOrLevel);
	}
}



sub confessLog {
    my ($logger, $msg) = @_;

    if (defined($logger)) {
	$logger->logconfess($msg);
    } else {
	confess($msg);
    }
}


sub warnLog {
    my ($logger, $msg) = @_;
    if (defined($logger)) {
 	$logger->logwarn($msg);
# 	$logger->warn($msg);
    } else {
#	print STDERR "nope\n";
	warn($msg);
    }

}

sub cluckLog {
    my ($logger, $msg) = @_;
    if (defined($logger)) {
	$logger->logcluck($msg);
    } else {
	warn($msg);
    }

}

1;
