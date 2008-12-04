package LWP::Curl;

use warnings;
use strict;
use WWW::Curl::Easy;
use Carp qw(croak);
use Data::Dumper;
use HTML::Entities;

=head1 NAME

LWP::Curl - LWP methods implementation with Curl engine

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';


=head1 SYNOPSIS

Use libcurl like LWP, $lwpcurl->get($url), $lwpcurl->timeout(15) don't care about Curl API and don't care about html encode

    use LWP::Curl;

    my $lwpcurl = LWP::Curl->new();
	my $content = $lwpcurl->get('http://search.cpan.org','http://www.cpan.org'); 
	#get the page http://search.cpan.org passing with referer http://www.cpan.org

=cut


=head1 Constructor

=head2 new()

Creates and returns a new LWP::Curl object, hereafter referred to as
the "lwpcurl".

    my $lwpcurl = LWP::Curl->new()

=over 4

=item * C<< timeout => sec >>

Set the timeout value in seconds. The default timeout value is
180 seconds, i.e. 3 minutes.

=item * C<< headers => [0|1] >>

Show HTTP headers when return a content. The default is false '0'

=item * C<< user_agent => 'agent86' >>

Set the user agent string. The default is  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)'

=item * C<< followlocation => [0|1] >>

If the spider receive a HTTP 301 ( Redirect ) they will follow?. The default is 1.

=item * C<< auto_encode => [0|1] >>

Turn on/off auto encode urls, for get/post.

=item * C<< maxredirs => number >>

Set how deep the spider will follow  when receive HTTP 301 ( Redirect ). The default is 3.

=back

=cut

sub new {

    # Check for common user mistake
    croak("Options to LWP::Curl should be key/value pairs, not hash reference") 
        if ref($_[1]) eq 'HASH'; 
	
    my ($class, %args) = @_;

	my $self = {};
	
	my $log = delete $args{log} ;

	my $timeout = delete $args{timeout};
    $timeout = 3*60 unless defined $timeout;

   	my $headers = delete $args{headers};
	$headers = 0 unless defined $headers;

	my $user_agent = delete $args{user_agent};
	$user_agent =  'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)'
		unless defined $user_agent;

	my $maxredirs = delete $args{max_redirs};
	$maxredirs = 3 unless defined $maxredirs;
	
	my $followlocation = delete $args{followlocation};
	$followlocation = 1 unless defined $followlocation;
	
	my $auto_encode = delete $args{auto_encode};
	$auto_encode = 1 unless defined $auto_encode;

	$self->{retcode} = undef;	
	my $debug = 0;
	$self->{debug} = $debug;    
	print STDERR "\n Hash Debug: \n" . Dumper($self) . "\n" if $debug;
	$self->{agent} = WWW::Curl::Easy->new();
	$self->{agent}->setopt(CURLOPT_TIMEOUT,$timeout);
	$self->{agent}->setopt(CURLOPT_USERAGENT, $user_agent);
    $self->{agent}->setopt(CURLOPT_HEADER,$headers);
	$self->{agent}->setopt(CURLOPT_AUTOREFERER,1); # always true
	$self->{agent}->setopt(CURLOPT_MAXREDIRS,$maxredirs);
	$self->{agent}->setopt(CURLOPT_FOLLOWLOCATION,$followlocation);
	$self->{agent}->setopt(CURLOPT_SSL_VERIFYPEER,0);
     #CURLOPT_COOKIESESSION,$cookie;

	return bless $self, $class;
}


=head1 METHODS

=head2 $lwpcurl->get($url,$referer)

  Get content of $url, passando $referer se definido

    use LWP::Curl;
	my $referer = 'http://www.example.com';
	my $get_url = 'http://www.example.com/foo';
    my $lwpcurl = LWP::Curl->new();
	my $content = $lwpcurl->get($get_url, $referer); 
=cut

sub get {
    my ($self, $url, $referer) = @_;
	
	if(!$referer){
		$referer = "";
	}

	encode($url) if $self->{auto_encode};

	$self->{agent}->setopt(CURLOPT_REFERER,$referer);
	$self->{agent}->setopt(CURLOPT_URL,$url);
    $self->{agent}->setopt(CURLOPT_HTTPGET, 1); 

    my $content =  "";
	open (my $fileb, ">", \$content);
	$self->{agent}->setopt(CURLOPT_WRITEDATA,$fileb);
	$self->{retcode} = $self->{agent}->perform;

	if ($self->{retcode} == 0) {
   	     #print("\nTransfer went ok\n") if $self->{debug};
		 return $content;
	} else {
        croak("An error happened: Host $url ".$self->{agent}->strerror($self->{retcode})." ($self->{retcode})\n");
	}
}

=head2 $lwpcurl->post($url,$hash_form,$referer) 
 
  POST the $hash_form fields in $url, passing $referer if defined

    use LWP::Curl;

    my $lwpcurl = LWP::Curl->new();

	my $referer = 'http://www.examplesite.com/';
	my $post_url = 'http://www.examplesite.com/post/';

	my $hash_form = { 
		'field1' => 'value1',
		'field2' => 'value2',
	}

	my $content = $lwpcurl->post($post_url, $hash_form, $referer); 

=cut

sub post {
   my ($self, $url, $hash_form, $referer) = @_;
	
	if(!$referer){
		$referer = "";
	}

	if(!$hash_form){
		warn( qq{POST Data not defined} );
	}else{
		#print STDERR Dumper $hash_form;
	}


	my $post_string = "";
    foreach my $var (keys %{$hash_form}){
		$post_string = $post_string . "$var=$hash_form->{$var}";
		$post_string = $post_string . "&";
		#print STDERR "var: $var - $hash_form->{$var}\n";
	}

	$url = encode($url) if $self->{auto_encode};
	$post_string = encode($post_string) if $self->{auto_encode};
	
	$self->{agent}->setopt(CURLOPT_POSTFIELDS, $post_string);
	$self->{agent}->setopt(CURLOPT_POST,1);
	$self->{agent}->setopt(CURLOPT_HTTPGET,0);

	$self->{agent}->setopt(CURLOPT_REFERER,$referer);
	$self->{agent}->setopt(CURLOPT_URL,$url);
	my $content =  "";
	open (my $fileb, ">", \$content);
	$self->{agent}->setopt(CURLOPT_WRITEDATA,$fileb);
	$self->{retcode} = $self->{agent}->perform;

	if ($self->{retcode} == 0) {
   	     #print("Transfer went ok\n");
		 #print STDERR $content; 
		 return $content;
   	     #my $response_code = $selfcurl->getinfo(CURLINFO_HTTP_CODE);
	} else {
       croak("An error happened: Host $url ".$self->{agent}->strerror($self->{retcode})." ($self->{retcode})\n");
	}
}

=head2 $lwpcurl->timeout($sec)

  Set timeout, default 180

=cut

sub timeout {
	my ($self, $timeout) = @_;
	if(!$timeout) {
		return $self->{timeout};
	}
	$self->{agent}->setopt(CURLOPT_TIMEOUT,$timeout);
}

=head2 $lwpcurl->auto_encode($value)

  Turn on/off auto_encode

=cut

sub auto_encode {
	my ($self, $value) = @_;
	if(!$value) {
		return $self->{auto_encode};
	}else{
		$self->{auto_encode} = $value;
	}
}

=head2 $lwpcurl->agent_alias($alias)
   
   Copy from L<WWW::Mechanize> begin here
   ____________________________________
   Sets the user agent string to the expanded version from a table of actual user strings.
   I<$alias> can be one of the following:

=over 4

=item * Windows IE 6

=item * Windows Mozilla

=item * Mac Safari

=item * Mac Mozilla

=item * Linux Mozilla

=item * Linux Konqueror

=back

   then it will be replaced with a more interesting one.  For instance,
   ____________________________________

   Copy from L<WWW::Mechanize> ends here, but the idea and the data structure is a copy too :) 
   
   $lwpcurl->agent_alias( 'Windows IE 6' );

	   sets your User-Agent to
	    
		Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)

=cut

sub agent_alias {
	my ($self,$alias) = @_;

	# CTRL+C from WWW::Mechanize, thanks for petdance
	# ------------	
	my %known_agents = (
			'Windows IE 6'      => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
			'Windows Mozilla'   => 'Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6',
			'Mac Safari'        => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/85 (KHTML, like Gecko) Safari/85',
			'Mac Mozilla'       => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401',
			'Linux Mozilla'     => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624',
			'Linux Konqueror'   => 'Mozilla/5.0 (compatible; Konqueror/3; Linux)',
	);


	if ( defined $known_agents{$alias} ) {
		$self->{agent}->setopt(CURLOPT_USERAGENT, $known_agents{$alias});
		}
		else {
			 warn( qq{Unknown agent alias "$alias"} );
		}
}

=head1 TODO

This is a small list of features I'm plan to add. Feel free to contribute with your wishlist and comentaries!

=over 4

=item * Test for the upload method

=item * Improve the Documentation and tests

=item * Support Cookies

=item * Support Proxys

=item * PASS in all tests of LWP

=item * Make a patch to L<WWW::Mechanize>, todo change engine, like "new(engine => 'LWP::Curl')"

=back

=head1 AUTHOR

Lindolfo Rodrigues de Oliveira Neto, C<< <lorn at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-lwp-curl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=LWP-Curl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc LWP::Curl


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=LWP-Curl>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/LWP-Curl>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/LWP-Curl>

=item * Search CPAN

L<http://search.cpan.org/dist/LWP-Curl>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to Breno G. Oliveira for the great tips.    

=head1 COPYRIGHT & LICENSE

Copyright 2008 Lindolfo Rodrigues de Oliveira Neto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of LWP::Curl