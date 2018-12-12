package NPR;
use Dancer ':syntax';

use HTTP::Tiny;
use XML::Tiny::Simple qw/ parsestring /;
use Data::Dumper;
use Class::Date qw/ date /;
use JSON;
use NPR::Transcript;
use NPR::Query;

our $VERSION = '0.1';

hook 'before_template_render' => sub {
    my $tokens = shift;
    my $base   = uri_for('/');
    $base =~ s/\/$//;
    $base =~ s{^http://}{https://} if request->header('X-Forwarded-Proto') eq 'https';
    $tokens->{'base'} = $base;
};

get '/' => sub {
    my $podcast = NPR::Query->new( 1056 );
    var podcast => $podcast;
    template 'index', vars;
};

get '/story/:id' => sub {
    my $id = param 'id';
    # my $tran = NPR::Transcript->new( $id );
    #
    my $url = 'https://www.npr.org/templates/transcript/transcript.php';
    my $form = { storyId => $id };

    #----------------------------------------
    use Path::Tiny;
    my $path = path( 'npr/' . $id );
    -d $path or $path->mkpath( 0, 0777 );
    my $file = path('npr/'.$id.'/story.html');

    # view-source:https://www.npr.org/rss/podcast.php?id=510313

    unless ( -f $file ){
        use Mojo::UserAgent;
        my $ua = new Mojo::UserAgent;
        my $res  = $ua->get( $url, form => $form )->result;
        my $html = $res->body;
        $file->spew( $html );
    }

    my $html = $file->slurp;
    use Web::Scraper::LibXML;
    my $now = scraper {
        process ".transcript p", 'paras[]' => 'HTML';
        process ".audio-tool a", 'mp3' => '@href';
        process "title", 'title' => 'TEXT';
    };
    my $res = $now->scrape( $html );
    var res => $res;

    my $paras = $res->{paras};

    my @paras;
    for ( @$paras ){
        s{^([A-Z\s,]*?):}{<small class="text-info">$1:</small><br/>}sg;
        push @paras, $_;
    }
    var paras => \@paras;


    # my @paras = map { $_->content } $res->dom->at('div.transcript')->children('p')->each;
    # pop @paras;
    # pop @paras;

    # $tran =~ s/<p class="disclaimer">.*?<\/p>//g;
    # my $audio = $res->dom->at('.audio-tool')->children('a')->attr('href')->content;



    # var paras => \@paras;
    template 'story', vars;
};

true;
