# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# LoremIpsumPlugin is Copyright (C) 2013-2024 Michael Daum http://michaeldaumconsulting.com
#
# Inspired by Text::Lorem Copyright (C) 2003 Fotango Ltd.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::LoremIpsumPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Error qw(:try);

use constant TRACE => 0; # toggle me
use constant DEFAULT_CORPUS => 'classic';

sub new {
  my $class = shift;

  my $this = bless({
    @_
  }, $class);

  return $this;
}

sub finish {
  my $this = shift;

  undef $this->{wordlist};
  undef $this->{sentences};
}

sub LOREM {
  my ($this, $session, $params, $theTopic, $theWeb) = @_;

  my $type = $params->{type} || 'paragraph';

  # known types:
  # - word
  # - words: num words
  # - headline: min/max words
  # - sentence: min/max words
  # - sentences: num words, min/max words
  # - paragraph: min/max sentences
  # - paragraphs num paragraphs, min/max sentences
  # - image: width, height, text, category(ies), format, mono

  my $result;
  try {
    my $sub = "handle_".$type;

    throw Error::Simple("unknown lorem type") unless $this->can($sub);
    $result = $this->$sub($params);
  } catch Error with {
    my $msg = shift;

    $msg =~ s/ at .*$//g;
    $result = "<span class='foswikiAlert'>$msg</span>";
  };

  return Foswiki::Func::decodeFormatTokens($result);
}

sub _sentences {
  my ($this, $corpus) = @_;

  $corpus //= DEFAULT_CORPUS;

  unless (defined $this->{sentences}{$corpus}) {
   Foswiki::Func::readTemplate("loremipsum");
    
    my $data = Foswiki::Func::expandTemplate($corpus);
    throw Error::Simple("corpus not found") unless $data;

    #$this->{sentences}{$corpus} = [grep {!/^\s*$/} map { s/^\s+|\s+$//g; $_ } split(/[\.?!]+/, $data)];
    $this->{sentences}{$corpus} = _extractSentences($data);
    throw Error::Simple("no words found") unless scalar(@{$this->{sentences}{$corpus}}); # never reach
  }

  return $this->{sentences}{$corpus};
}

sub _numSentences {
  my ($this, $corpus) = @_;

  return scalar(@{$this->_sentences($corpus)});
}

sub _words {
  my ($this, $corpus) = @_;

  $corpus //= DEFAULT_CORPUS;

  unless (defined $this->{wordlist}{$corpus}) {
    Foswiki::Func::readTemplate("loremipsum");

    my $data = Foswiki::Func::expandTemplate($corpus);
    throw Error::Simple("corpus not found") unless $data;

    $this->{wordlist}{$corpus} = [map { my $tmp = $_; $tmp =~ s/[^\w'\-,]//g; lc($tmp) } split(/\s+/, $data)];
    throw Error::Simple("no words found") unless scalar(@{$this->{wordlist}{$corpus}}); # never reach
  }

  return $this->{wordlist}{$corpus};
}

sub _numWords {
  my ($this, $corpus) = @_;

  return scalar(@{$this->_words($corpus)});
}

sub handle_word {
  my ($this, $params) = @_;

  return $this->_words($params->{corpus})->[int(rand($this->_numWords($params->{corpus})))];
}

sub handle_sentence {
  my ($this, $params) = @_;

  my $sentence = $this->_sentences($params->{corpus})->[int(rand($this->_numSentences($params->{corpus})))];
  $sentence =~ s/\n/ /g; # strip off newlines in sentences
  
  $sentence = ucfirst($sentence);

  unless ($sentence =~ /[\.\?!]$/) {
    my @puncts = ('.', '.', '.', '.', '.', '.', '?', '!');
    my $punc = $puncts[int(rand(scalar(@puncts)))];
    $sentence .= $punc;
  }

  return $sentence;
}

sub handle_words {
  my ($this, $params) = @_;

  my $num = $params->{num} || 3;
  my $sep = $params->{separator} || ' ';
  $params->{separator} = $params->{word_separator};

  my @words;
  push @words, $this->handle_word($params) for (1 .. $num);

  return join($sep, @words);
}

sub handle_headline {
  my ($this, $params) = @_;

  my $min = $params->{min} || 3;
  my $max = $params->{max} || 7;

  $params->{num} = $min + int(rand($max-$min));

  my $words = $this->handle_words($params);

  return ucfirst($words);
}


sub handle_sentences {
  my ($this, $params) = @_;

  my $num = $params->{num} || 3;
  my $sep = $params->{separator} || ' ';
  $params->{separator} = $params->{sentence_separator};

  my @sentences;
  push @sentences, $this->handle_sentence($params) for (1 .. $num);

  return join($sep, @sentences);
}

sub handle_paragraph {
  my ($this, $params) = @_;

  my $min = $params->{min} || 5;
  my $max = $params->{max} || 10;

  $params->{num} = $min + int(rand($max-$min));

  return $this->handle_sentences($params);
}

sub handle_paragraphs {
  my ($this, $params) = @_;

  my $num = $params->{num} || 3;
  my $sep = $params->{separator} // "\n\n";
  $params->{separator} = $params->{paragraph_separator};

  my @paragraphs;
  push @paragraphs, $this->handle_paragraph($params) for (1 .. $num);

  return join($sep, @paragraphs);
}

sub handle_image {
  my ($this, $params) = @_;

  my $format = $params->{format} || '<img src=\'$url\' width=\'$width\' height=\'$height\' alt=\'$alt\' class=\'$class\' $style title=\'$title\'>';
  my $width = $params->{width} || 240;
  my $height = $params->{height} || 160;
  my $style = $params->{style} || '';
  $style = "style='$style'" if $style;

  my $search = $params->{search};

  if (defined $search) {
    $search = '?'.$search;
  } else {
    $search = 'random';
  }

  my $class = "loremImage";
  $class .= " $params->{class}" if $params->{class};

  my $align = $params->{align};
  if (defined $align) {
    $class .= " foswikiLeft" if $align eq 'left';
    $class .= " foswikiRight" if $align eq 'right';
    $class .= " foswikiCenter" if $align eq 'center';
  }

  my $alt = $params->{alt} || $params->{search} || 'random';
  my $title = $params->{title} || $alt;

  my $url;
  if ($search eq "random") {
    $url = '//source.unsplash.com/random/$widthx$height';
  } else {
    $url = '//source.unsplash.com/$widthx$height/$search';
  }

  $format =~ s/\$url/$url/g;
  $format =~ s/\$alt/$alt/g;
  $format =~ s/\$title/$title/g;
  $format =~ s/\$width/$width/g;
  $format =~ s/\$height/$height/g;
  $format =~ s/\$search/$search/g;
  $format =~ s/\$class/$class/g;
  $format =~ s/\$style/$style/g;

  return $format;
}

sub _writeDebug {
  print STDERR "LoremIpsumPlugin::Core - $_[0]\n" if TRACE;
}

# from Text::Sentence
sub _extractSentences {
  my $text = shift;

  return [] unless $text;

  my $capital_letter = '[\p{Uppercase}]';
  my $punctuation = '(?:\.|\!|\?)';

  # this needs to be alternation, not character class, because of
  # multibyte characters

  my $opt_start_quote = q/['"]?/; # "'
  my $opt_close_quote = q/['"]?/; # "'

  # these are distinguished because (eventually!) I would like to do
  # locale stuff on quote characters

  my $opt_start_bracket = q/[[({]?/; # }{
  my $opt_close_bracket = q/[\])}]?/;

  my @sentences = $text =~ /
    (
                                # sentences start with ...
        $opt_start_quote        # an optional start quote
        $opt_start_bracket      # an optional start bracket
        $capital_letter         # a capital letter ...
        .+?                     # at least some (non-greedy) anything ...
        $punctuation            # ... followed by any one of !?.
        $opt_close_quote        # an optional close quote
        $opt_close_bracket      # and an optional close bracket
    )
    (?=                         # with lookahead that it is followed by ...
        (?:                     # either ...
            \s+                 # some whitespace ...
            $opt_start_quote    # an optional start quote
            $opt_start_bracket  # an optional start bracket
            $capital_letter     # an uppercase word character (for locale
                                # sensitive matching)
        |               # or ...
            \n\n        # a couple (or more) of CRs
        |               # or ...
            \s*$        # optional whitespace, followed by end of string
        )
    )
    /gxs
    ;

  return \@sentences;
}

1;
