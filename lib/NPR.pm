package NPR;
use Dancer ':syntax';

use HTTP::Tiny;
use XML::Tiny::Simple qw/ parsestring /;
use Data::Dumper;
use Class::Date qw/ date /;
use JSON;
use NPR::Transcript;

our $VERSION = '0.1';

hook 'before_template_render' => sub {
    my $tokens = shift;
    my $base   = uri_for('/');
    $base =~ s/\/$//;
    $base =~ s{^http://}{https://} if request->header('X-Forwarded-Proto') eq 'https';
    $tokens->{'base'} = $base;
};

get '/' => sub {
    my $url_stories = 'http://api.npr.org/query?id=1056&fields=title,storyDate,transcript&dateType=story&sort=dateDesc&output=JSON&apiKey=MDExMTA1NDUwMDEzNjQyNjc4NDFmZjZkOA001';

    my $res = HTTP::Tiny->new->get($url_stories);
    die "Failed wget $url_stories\n" unless $res->{success};

    my $json    = $res->{content};
    my $hash    = decode_json $json;
    my $stories = $hash->{list}{story};
    my $title   = $hash->{list}{title}{'$text'};

    my @stories;
    for (@$stories) {
        my $id             = $_->{id};
        my $title          = $_->{title}{'$text'};
        my $url_transcript = $_->{transcript}{link}{'$text'};
        push @stories, { id => $id, title => $title, url => $url_transcript };

        # printf "%s - %s %s\n", $id, $title, $url_transcript;
    }
    var title   => $title;
    var stories => \@stories;
    template 'index', vars;
};

get '/story/:id' => sub {
    my $id = param 'id';
    my $tran = NPR::Transcript->new( $id );

    var tran => $tran;
    template 'story', vars, { layout => undef };
};

true;
