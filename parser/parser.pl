#!/usr/bin/perl -l

use YAML qw(LoadFile);
use Data::Dumper;
use JSON;
use Getopt::Long;

my $output; # container for collected output
my $ruleFile = $ARGV[0];
my $ruleSet = loadRules($ruleFile);
my $debug = 0;

my @in;

if($ruleSet->{command}) {
    print "executing $ruleSet->{command}";

    open(IN, "$ruleSet->{command}|");
    @in = <IN>;
    close(IN);
}
else {
    print "Reading from stdin";
    @in = <STDIN>;
}
map { chomp } @in; # clean input, lop off all the newlines

parse($ruleSet, \@in);

sub loadRules {
    my ($rulePack) = @_;
    my $yml = LoadFile($rulePack);
    return($yml);
}

sub parse {
    my ($ruleSet, $content) = @_;
    my $objectTypes = $ruleSet->{objects};

    my %hash;   # container for extracted objects

    foreach my $type ( sort keys %{ $objectTypes } ) {
        print "Processing output for object type $type";

        my $rule = $objectTypes->{$type};
        unless ( validateContentParser( $rule ) ) {
            warn "Content parser for object type $type failed validation";
            next;
        }

        my @x = @{$content};

        my $properties = $objectTypes->{$type}->{properties};   # get sub parser rules for object construction

        if($rule->{start} && $rule->{end}) { # stanza style object, has a definitive start and stop
            my $lock = 0;

            my @array;  # container for line by line output as the first stage rule gleans object data from incoming data.
            my $object; # hashref for extracted key/value pairs

            while( @x ) {

                my $line = shift @x;

                if($lock && $line =~ $rule->{end}) {    #end of the objects

                    if ( $rule->{lastIsNext} ) { # if the end marker matches the start of a new object
                        unshift @x, $line; # put it back on the stack
                    }
                    elsif ( $rule->{discardLast} ) { # if the end marker is something we don't need to keep
                        # do nothing, leave it off the stack
                    }
                    else {
                        push @object, $line;
                    }

                    print "Releasing lock, $rule->{end} on: $line";
                    $lock = 0;  # release the stanza lock

                    # TODO: Invoke property rules to populate the object hashref
                    my $newObject = parseObject( $properties, \@array);

                    $hash{$type}{ $object->{name} } = { %{$newObject}, %{$object} };

                    # reset
                    $object = {};
                    @array = ();
                    next;
                }
                elsif($lock) {                 # stanza lock is set, store the line.
                    push @array, $line;
                }
                elsif(!$lock) {
                    if( my @tokens = $line =~ $rule->{start} ) {

                        print "Setting lock, matched $rule->{start} on: $line";
                        $lock++;

                        if( $rule->{tokens} ) {
                            map { $object->{$_} = shift @tokens } @{$rule->{tokens}};
                        }
                        else {
                            $object->{name} = $1;
                        }
                    }
                }
            }

            print Dumper(\%hash);

        }
        elsif($rule->{match}) { # mutually exclusive with start/end rules, intended for single line matches
            foreach my $line ( @{ $content } ) {

                if( @tokens = $line =~ $rule->{match} ) {



                }
            }
        }
    }
}

sub parseObject {
    my ($properties, $array) = @_;
    my $hashref = {};

    map { 
        my $x = $_;
        foreach $regexp ( keys %{$properties} ) {
            if( my @tokens = $x =~ $regexp ) {
                map { $hashref->{$_} = shift @tokens } @{$properties->{$regexp}->{tokens}};
                xlate( $properties->{$regexp}->{xlate}, $hashref )  if( defined $properties->{$regexp}->{xlate});
                transform( $properties->{$regexp}->{transform}, $hashref )  if( defined $properties->{$regexp}->{transform});
            } 
        }        
    } @{$array};


    return($hashref);
}

sub xlate {
    my( $xlate, $hashref ) = @_;    

    map {  
        my $key = $_; 
        my $sub = $xlate->{$key}; 
        $hashref->{$key} = $sub->{ $hashref->{$key} } if $hashref->{$key}
    } keys %{$xlate};
} 

sub transform {
    my( $transform, $hashref ) = @_;    
   
    map { 
       my $key = $_;

       print "transform: $key, $transform->{$key}";
       $hashref->{$key} =~ $transform->{$key};
    } keys %{$transform}; 
}

sub validateContentParser {
    my ($rule) = @_;

    if( defined $rule->{start} && defined $rule->{end} ) {
        my $valid = 0; # expect 2

        $@ = 0;
        eval { 'foo' =~ $rule->{start}; }; # we don't care if it matches, just that it doesn't explode
        $valid++ unless $@; $@ = 0;
        eval { 'foo' =~ $rule->{end}; }; 
        $valid++ unless $@; $@ = 0;

        print "content parser validation: $valid";
        return(1) if $valid eq 2;
    }


}

sub validateObjectParser {



}
