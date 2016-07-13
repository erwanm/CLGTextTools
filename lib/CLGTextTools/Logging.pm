package CLGTextTools::Logging;

#twdoc
#
# Library containing logging-related functions, especially with Log4Perl.
#
#
#/twdoc



use strict;
use warnings;
use Log::Log4perl;
use Carp qw/cluck/;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw/initLogging @possibleLogLevels confessLog warnLog cluckLog/;

our @possibleLogLevels = qw/TRACE DEBUG INFO WARN ERROR FATAL OFF/;









#twdoc createDefaultLogConfig($filename, $logLevel, $alsoToScreen, $synchronized)
#
# creates a simple log configuration for log4perl, usable with Log::Log4perl->init($config)
#
#/twdoc
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



#twdoc initLog($logConfigFileOrLevel, $logFilename, $alsoToScreen, $synchronized)
#
# initializes a log4perl object in the following way: if
# ``$logConfigFileOrLevel`` is a log level, then uses the default config
# (directed to ``$logFilename``), otherwise ``$logConfigFileOrLevel`` is
# supposed to be the log4perl config file to be used.
#
#/twdoc
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



#twdoc confessLog($logger, $msg)
#
# if ``$logger`` is defined, calls Log4perl logconfess function with ``$msg``, otherwise uses the standard function confess.
#
#/twdoc
sub confessLog {
    my ($logger, $msg) = @_;

    if (defined($logger)) {
	$logger->logconfess($msg);
    } else {
	confess($msg);
    }
}


#twdoc warnLog($logger, $msg)
#
# if ``$logger`` is defined, calls Log4perl logwarn function with ``$msg``, otherwise use the standard function warn.
#
#/twdoc
sub warnLog {
    my ($logger, $msg) = @_;
    if (defined($logger)) {
#	print STDERR "DEBUG msg= '$msg' ; logger defined...\n";
	$logger->logwarn($msg);
    } else {
#	print STDERR "nope\n";
	warn($msg);
    }

}



#twdoc cluckLog($logger, $msg)
#
# if ``$logger`` is defined, calls Log4perl logcluck function with ``$msg``, otherwise use the standard function warn.
#
#/twdoc
sub cluckLog {
    my ($logger, $msg) = @_;
    if (defined($logger)) {
	$logger->logcluck($msg);
    } else {
	cluck($msg);
    }

}

1;
