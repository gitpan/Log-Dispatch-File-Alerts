use 5.006001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Log::Dispatch::File::Alerts',
    'VERSION_FROM'	=> 'Alerts.pm', # finds $VERSION
    'PREREQ_PM'		=> {
    	'Log::Log4perl' => '0.32',
    	'Log::Dispatch' => '2.06',
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Alerts.pm', # retrieve abstract from module
       AUTHOR     => 'M. Jacob <jacob@j-e-b.net>') : ()),
);
