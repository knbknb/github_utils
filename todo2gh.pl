#!/usr/bin/perl

# source: 
# weblog of perl hacker  Yanick Champoux, from Canada
# http://babyl.ca/techblog/entry/todo2gh 
# https://github.com/yanick/

=pod
With this little beauty, you can do
	
$ todo2gh.pl lib

in the root of your project and it'll sniff all the modules and scripts and, for all TODO found of the format
	
# TODO frobusnicate the loop
# some details that will end up in the issue's body

it'll prompt you if you want to create an issue and automagically convert the TODO to
	
# TODO [GH3] frobusnicate the loop
# some details that will end up in the issue's body

Meanwhile, a new issue will now live on GitHub, with the proper title and label, and a nice link in the body leading to that exact place in the code.

Enjoy!
=cut

#use 5.16.0;
use 5.14.2;
 
use strict;
use warnings;
 
use Path::Iterator::Rule;
use Path::Tiny;
use List::AllUtils qw/ indexes before apply first /;
use Git::Repository;
use IO::Prompt::Tiny qw/prompt/;
use Net::GitHub;
use Getopt::Long; 
 
my $git = Git::Repository->new( work_tree => '.' );
 
# my remote is always named 'github', you might have to
# adapt to your habits
my( $project ) = first { /^origin/ } $git->run( 'remote', '-v' );
$project =~ s/^.*?://;
$project =~ s/\.git.*$//;
 
my $verbose = '';   # option variable with default value (false)
my $path    =  '.';       # option variable with default value (false)
my $pass    =  '';       # option variable with default value (false)
    GetOptions ('verbose' => \$verbose, 'pass=s' => \$pass, 'path' => \$path);

my $github = Net::GitHub->new(
    login => 'knbknb',
    pass => $pass,
);
 
$github->set_default_user_repo( split '/', $project );
 
Path::Iterator::Rule->new
    ->file
    ->name( qr/\.p[lm]$|\.R$/ )
        # I'm too lazy for the next() dance...
    ->and( sub{
        my $path = path($_);
 
        my @lines = $path->lines;
        process_todo( $path, $_, \@lines ) for indexes {
            /^ \s* \# \s* (?:TODO|FIXME) /x and not /\[GH\d+\]/
        } @lines;
 
        return 0; # we don't want to collect the files
    })
    ->all( @ARGV );
 
sub process_todo {
    my( $file, $nbr ) = @_;
    my @lines = @{$_[2]};
 
    my $subject = $lines[$nbr] =~ s/^.*?#\s*(?:TODO|FIXME)\s*//r;
    my @body = apply { s/^\s*#\s?// } before { !/^\s*#/ }  @lines[$nbr+1..$#lines];
 
    # TODO don't assume master
    my $url = "https://github.com/$project/blob/master/$file#L$nbr";
    $url .= '-' . ($nbr+@body) if @body;
 
    say $subject;
    say "";
    say @body;
 
    prompt( "create Issue? (y/N)", 'n' ) =~ /y/i or return;
 
    my $isu = $github->issue->create_issue( {
        "title" => $subject,
        "body" => join( '', @body, "\n\n", $url ),
        labels => [ 'code todo' ],
    } ) or die "error in creating issue";
 
    say "issue ", $isu->{number}, " created";
    say $isu->{html_url};
    say "";
 
    my $issue = $isu->{number};
 
    $lines[$nbr] =~ s/(TODO|FIXME)/$1 [GH$issue]/;
 
    $file->spew(@lines);
}
