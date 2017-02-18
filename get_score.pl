#!/usr/bin/perl

use strict;
use warnings;
use LWP::Simple;
use Data::Dumper;
use DateTime;
use DBI();

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#-- MAIN --#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

my $db = "hockey";
my $username = "username";
my $password = 'password';
my $host = "hostname";
my $db_port = "3306";

#my $date = '2017-02-11';
my $date = getURIDate();

my $url = "http://live.nhle.com/GameData/GCScoreboard/${date}.jsonp";
#my $url = "http://live.nhle.com/GameData/GCScoreboard/2017-02-04.jsonp";

# Read team name from command line
my $team = $ARGV[0];

# Get number of goals scored by my team
my @gameDetails = getGameDetails($team, $url);
my $gameStatus = getTeamsGameDetails(@gameDetails,$team);

#print Dumper $gameStatus;

my $awayTeamScore = $gameStatus->{ats};
my $awayTeamName = $gameStatus->{ata};
my $homeTeamScore = $gameStatus->{hts};
my $homeTeamName = $gameStatus->{hta};
my $gameStage = $gameStatus->{bsc};
my $homeTeamFinal = $gameStatus->{htc};
my $awayTeamFinal = $gameStatus->{atc};
my $gameID = $gameStatus->{id};

my $dsn = "DBI:mysql:database=$db;host=$host;port=$db_port";
my $dbh = DBI->connect($dsn, $username, $password);
my $sth = $dbh->prepare("SELECT * from status where gameID=$gameID");
$sth->execute();
my $queryResults =  $sth->fetchrow_hashref();
#print Dumper $queryResults;

my $recordedScore;
if (defined $queryResults) 
{ 
 $sth = $dbh->prepare("SELECT homescore, awayscore from status where gameID=$gameID");
 $sth->execute();
 $recordedScore =  $sth->fetchrow_hashref();
} 
else 
{ 
 $dbh->do("INSERT INTO status VALUES ('NULL', $gameID, \'$homeTeamName\', \'$awayTeamName\', \'$date\', \'$homeTeamScore\', \'$awayTeamScore\','NULL')");
 print "UNDEFINED!\n"; 
}

$sth->finish();

if ($homeTeamName eq $team)
{
 ## Has Game Started?
 if ($gameStage)
 {
  print "Current $team goals: $homeTeamScore\n";
  print "DB $team goals: $recordedScore->{homescore}\n";
   if ($homeTeamScore gt $recordedScore->{homescore}) 
   { 
    print "SCORE!!!!! Updating DB...\n";
    `/usr/bin/irsend SEND_START HockeyGoal KEY_SOUND`;
    sleep(1);
    `/usr/bin/irsend SEND_STOP HockeyGoal KEY_SOUND`;
    $dbh->do("UPDATE status SET homescore=$homeTeamScore WHERE gameID=$gameID");
   }
   if ($homeTeamScore lt $recordedScore->{homescore}) 
   {
    print "THEY TOOK IT AWAY!!!!! Updating DB...\n";
    $dbh->do("UPDATE status SET homescore=$homeTeamScore WHERE gameID=$gameID");
   }
   ## Is Game over?
  if ($gameStage eq "final")
  {
   ## Did we Win?
   if ($homeTeamFinal eq "winner")
   {
    $dbh->do("UPDATE status SET winner=\'$team\', awayscore=$awayTeamScore WHERE gameID=$gameID");
    print "$team won\n";
    `/usr/bin/irsend SEND_START HockeyGoal KEY_SOUND`;
    sleep(1);
    `/usr/bin/irsend SEND_STOP HockeyGoal KEY_SOUND`;
   }
   else 
   {
    $dbh->do("UPDATE status SET winner=\'$awayTeamName\', awayscore=$awayTeamScore WHERE gameID=$gameID");
   }
  } 
 }
}
if ($awayTeamName eq $team)
{
 ## Has Game Started?
 if ($gameStage)
 {
  print "Current $team goals: $awayTeamScore\n";
  print "DB $team goals: $recordedScore->{awayscore}\n";
   if ($awayTeamScore gt $recordedScore->{awayscore}) 
   {
    print "SCORE!!!!! Updating DB...\n";
    `/usr/bin/irsend SEND_START HockeyGoal KEY_SOUND`;
    sleep(1);
    `/usr/bin/irsend SEND_STOP HockeyGoal KEY_SOUND`;
    $dbh->do("UPDATE status SET awayscore=$awayTeamScore WHERE gameID=$gameID");
   }
   if ($awayTeamScore lt $recordedScore->{awayscore}) 
   {
    print "THEY TOOK IT AWAY!!!!! Updating DB...\n";
    $dbh->do("UPDATE status SET awayscore=$awayTeamScore WHERE gameID=$gameID");
   }
  ## Is Game over?
  if ($gameStage eq "final")
  {
   ## Did we Win?
   if ($awayTeamFinal eq "winner")
   {
    $dbh->do("UPDATE status SET winner=\'$team\',homescore=$homeTeamScore WHERE gameID=$gameID");
    print "$team won\n";
    `/usr/bin/irsend SEND_START HockeyGoal KEY_SOUND`;
    sleep(1);
    `/usr/bin/irsend SEND_STOP HockeyGoal KEY_SOUND`;
   }
   else 
   {
    $dbh->do("UPDATE status SET winner=\'$homeTeamName\', homescore=$homeTeamScore WHERE gameID=$gameID");
   }
  } 
 }
}

$dbh->disconnect();
#~#~#~#~#~#~#~#~#~#~#~#~#~#~#-- FUNCTIONS --#~#~#~#~#~#~#~#~#~#~#~#~#~#~#

# Build URL based on current date

sub getURIDate
{
 my $dt = DateTime->today(time_zone=>'local');
 return ( $dt->date);
}

# Retrieve JSON from API

sub getGameDetails
{
 my @games;
 my $teamscore;
 
 my $json = get( $url );
 chomp($json);
 my @results = split(/\{/, $json);
 
 foreach (@results)
 {
  my $rec = {};
  for my $field ( split /,/ )
  {
   (my $key, my $value) = split /:/, $field;
   $key =~ s/[\'|\"]//g;
   if (defined $value)
   {
    $value =~ s/[\'|\"]//g;
   }
   $rec->{$key} = $value;
  }
  push @games, $rec;
 }
return(@games);
}
 
# Return my team's game information

sub getTeamsGameDetails
{
 for my $i ( 0 .. $#gameDetails)
 {
  if (defined $gameDetails[$i]{ata})
  {
   if ($gameDetails[$i]{ata} eq $team)
   {
    my $teamHash = $gameDetails[$i];
    return($teamHash);
   }
   if ($gameDetails[$i]{hta} eq $team)
   {
    my $teamHash = $gameDetails[$i];
    return($teamHash);
   } 
  }
 }
}
