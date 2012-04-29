package ZenIRCBot;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.01_01';

use AnyEvent::Redis;
use JSON;

=head1 NAME

ZenIRCBot - Perl API for ZenIRCBot

=head1 SYNOPSIS

  use ZenIRCBot;

  my $bot = ZenIRCBot->new();
  $bot->register_commands('ZenIRCBot::Test', [
      { name => 'foo', description => 'Returns bar' }
  ]);

  $bot->subscribe(sub {
      my ($msg, $channel) = @_;
      
      if ($msg->{version} == 1 and $msg->{type} eq 'privmsg') {
          if ($msg->{data}->{message} =~ m/foo/) {
              $bot->send_privmsg(
                  $msg->{data}->{channel},
                  sprintf("%s: bar", $msg->{data}->{sender})
              );
          }
      }
  });

  $bot->run;

=head1 DESCRIPTION

Perl API for ZenIRCBot.

=head1 METHODS

=head2 Standard API Methods

See the L<ZenIRCBot documentation|http://zenircbot.readthedocs.org/en/latest/index.html> 
for more information.

=cut

sub new {
    my $class = shift;
    my $host = shift // 'localhost';
    my $port = shift // 6379;
    my $db = shift // 0;
    
    my $redis = AnyEvent::Redis->new(
        host => $host,
        port => $port,
        on_error => sub { warn @_; }
    );
    # TODO handle db 

    bless({
        redis => $redis,
        services => [],
    }, $class);
}

sub redis { return $_[0]->{redis}; }


=head2 subscribe($func)

Set callback for redis publish events.

=head3 callback($message, $channel)

The callback function is called on Redis subscribe events, with the message
hashref and channel name.

=cut

sub subscribe {
    my ($self, $func) = @_;
    die "Not a CODEREF" if (ref $func ne "CODE");
    $self->get_redis_client->subscribe('in', sub {
        my ($raw, $channel) = @_;
        my $json = JSON->new->allow_nonref;
        my $msg = $json->decode($raw);
        &{$func}($msg, $channel);
    });
}

# Blocking AE loop
sub run {
    my $self = shift;
    AnyEvent->condvar->recv;
}

# ZenIRC functions from std api
sub send_privmsg {
    my ($self, $to, $message) = @_;
    if (ref $to ne 'ARRAY') {
        $to = [$to];
    }

    for my $channel (@{$to}) {
        my $json = JSON->new->allow_nonref->allow_blessed->convert_blessed;
        my $data = $json->encode({
            version => 1,
            type => 'privmsg',
            data => {
                to => $channel,
                message => $message
            }
        });
        
        $self->get_redis_client->publish('out', $data);
    }
}

sub send_admin_message {
    my ($self, $message) = @_;
    $self->redis->get('zenircbot:admin_spew_channels', sub {
        $self->send_privmsg(@_, $message) if (@_);
    });
}

sub register_commands {
    my ($self, $service, $commands) = @_;
    
    return if (!defined($commands));
    $commands = [$commands]
      if (ref($commands) ne "ARRAY");
    
    $self->{cv} = $self->get_redis_client->subscribe('in', sub {
        my $raw = shift;
        
        my $json = JSON->new->allow_nonref;
        my $message = $json->decode($raw);

        if ($message->{version} == 1 and $message->{type} eq 'privmsg') {
            if ($message->{data}->{message} eq 'commands') {
                for my $command (@{$commands}) {
                    $self->send_privmsg(
                        $message->{data}->{sender},
                        sprintf(
                            "%s: %s - %s",
                            $service,
                            $command->{name},
                            $command->{description}
                    ));
                }
            }
        }
    });

    $self->send_admin_message(sprintf("%s online!", $service));
}

sub get_redis_client {
    my ($self) = @_;
    return AnyEvent::Redis->new(
        host => $self->{host},
        port => $self->{port},
        on_error => sub { warn @_; }
    );
}

1;
__END__

=head1 SEE ALSO

L<ZenIRCBot|http://github.com/wraithan/zenircbot>

L<ZenIRCBot Documentation|http://zenircbot.readthedocs.org/en/latest/index.html>

=head1 AUTHOR

Anthony Johnson C<< <aj@ohess.org> >>

