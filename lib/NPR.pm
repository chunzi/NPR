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
    my $tran = NPR::Transcript->new( $id );

    var tran => $tran;
    template 'story', vars, { layout => undef };
};

true;
