#!/opt/local/bin/perl -n

BEGIN {
    sub usage {
        return <<EndOfUsage;
$0: generate outline from TeX/LaTeX files
Usage: $0 [-n] a.tex b.tex...    - generates outline from filenames
       $0 [-n] -f masterfile.tex - searches masterfile.tex for \\input{}'s
       -n means don't include any body text in outline
EndOfUsage
}
    $find_inputs = '';
    while ($ARGV[0] =~ /^-/) {
        $_ = shift @ARGV;
        $suppress_body = 1, next if /^-n/;
        $find_inputs = shift @ARGV, next if /^-f/;
        die &usage if /^-h/;
    }
    if ($find_inputs) {
        # scan a single file for \input lines, then add those filenames to
        # @ARGV. 
        open(FILE, $find_inputs) or die $!;
        @lines = grep( /^\s*[^%]/, (<FILE>));
        grep(chomp, @lines);
        push(@ARGV, grep( s/\\{include|input}{([^\}]+(.tex)?)}/\1.tex/g, @lines));
        warn "Scanning @ARGV";
        close FILE;
    }
    sub emit_bodytext {
        if ($bodytext) {
            # heading line: spit out body in a multiline paragraph
            select(STDOUT); $save = $~; $~ = "BODYTEXT";
            #print $bodytext;
            write;
            $~ = $save;
        }
    }
}
format BODYTEXT =
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~
              $bodytext
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~
              $bodytext
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~
              $bodytext
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~
              $bodytext
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~
              $bodytext
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~
              $bodytext
              | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...~
              $bodytext
.

    ;
%headings = ('part'          => '',
             'chapter'       => '',
             'section'       => '     ',
             'subsection'    => '        ',
             'subsubsection' => '           ',
             'paragraph'     => '          .',
             );
$headings = join('|', (keys(%headings)));
if  ( /^\s*\\($headings)\*?{([^\}]*)}/ ) {
    &emit_bodytext;
    print ($headings{$1},$2,"\n");
    $bodytext = '';
} elsif (! $suppress_body) {
    # it's a body line
    chomp;
    s/\s+/ /; s/$/ /;
    $bodytext .= $_ if /\S/;
}

END {
    &emit_bodytext unless $suppress_body;
}
