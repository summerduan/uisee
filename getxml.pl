#!/usr/bin/perl

# load module
use DBI;
#use strict;
use Cwd;
use File::Basename;
use WWW::BugzillaCheetahGNEW;
use Spreadsheet::WriteExcel;
use Encode;
use XML::Simple;
use Data::Dumper;
#global variables
#my $branch = $ARGV[0];
my $startdate;
my $enddate;


my $ostr_regex='^(((((1[6-9]|[2-9]\d)\d{2})-(0?[13578]|1[02])-(0?[1-9]|[12]\d|3[01]))|(((1[6-9]|[2-9]\d)\d{2})-(0?[13456789]|1[012])-(0?[1-9]|[12]\d|30))|(((1[6-9]|[2-9]\d)\d{2})-0?2-(0?[1-9]|1\d|2[0-8]))|(((1[6-9]|[2-9]\d)(0[48]|[2468][048]|[13579][26])|((16|[2468][048]|[3579][26])00))-0?2-29-))\s(20|21|22|23|[0-1]?\d):[0-5]?\d)(:[0-5]?\d)?(\s*\+\d+)?$';
if($ARGV[1] =~ /$ostr_regex/ && $ARGV[2] =~ /$ostr_regex/)
{

  ($startdate) = ( $ARGV[1] =~ /$ostr_regex/ );
  ($enddate) = ( $ARGV[2] =~ /$ostr_regex/ );
  print "startdate : $startdate. \n";
  print "enddate   : $enddate. \n";
}
else
{
  print "str not match. $ARGV[1],$ARGV[2] \n";
  die("please check time type.ARGV[1],ARGV[2].");
}


my $dbh;
my %g_dbconf;

# gerrit database configuration
%g_dbconf = (
        "hostaddr" => "localhost",
        "port" => "5432",
        "dbname" => "reviewdbtemp",
        "user" => "gerrit",
        "password" => "gerrit");

# connect to the gerrit database
$dbh = pgsqldb_connect($g_dbconf{'hostaddr'},$g_dbconf{'user'}, $g_dbconf{'password'}, $g_dbconf{'dbname'});


# iterate through resultset
# print values
our @gsubject;
#my @gsubject;
my @gproject;
my @grev;
my @gowner;

my $xmlfile = dirname($0) . "/default.xml";
my $userxs = XML::Simple->new(ForceArray=>['name']);
my $userxml = $userxs->XMLin($xmlfile);
my $default_branch = $userxml->{default}->{revision};
print $default_branch."\n";
my %projects = %{$userxml->{project}};
my $branch=$default_branch;
#Dumper($userxml);

foreach my $project (keys %projects)
{
    my $projecta =$projects{$project};
    if(exists $projecta->{"revision"})
    {
       $revision = $projecta->{"revision"};
    }
    else
    {
       $branch=$default_branch;
    }
    print $project . ";" . $branch . "\n";
    # execute SELECT query
    my $sth = $dbh->prepare("select changes.last_updated_on,changes.dest_project_name,changes.dest_branch_name,changes.subject,patch_sets.revision,accounts.full_name from changes,patch_sets,accounts where changes.status='M' and changes.last_updated_on >= '$startdate' and changes.last_updated_on <= '$enddate' and changes.dest_branch_name='refs/heads/$branch' and changes.dest_project_name='$project'and changes.change_id=patch_sets.change_id and changes.current_patch_set_id=patch_sets.patch_set_id and changes.owner_account_id=accounts.account_id order by changes.last_updated_on asc");
    $sth->execute();
    
    while(my $ref = $sth->fetchrow_hashref())
    {
        push(@gsubject,$ref->{'subject'});
        push(@gproject,$ref->{'dest_project_name'});
        push(@grev,$ref->{'revision'});
        push(@gowner,$ref->{'full_name'});
    
        print "$ref->{'full_name'},$ref->{'subject'},$ref->{'last_updated_on'},$ref->{'dest_project_name'},$ref->{'revision'},$branch\n";
    }
}
# clean up
$dbh->disconnect();


sub pgsqldb_connect
{
        my ($host, $username, $password, $database)=@_;
        # connect
        my $dbh = DBI->connect("DBI:Pg:dbname=$database;host=$host;port=5432", $username, $password, {'RaiseError' => 1});

        return $dbh;
}




