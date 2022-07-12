#!/usr/bin/env -S awk -f

BEGIN {
        FS="|";
        indent = "  ";
}

function output(string) {
    return"\\outpol{ " string " }";
}

# Field format
# root(,tex)?
function get_ntr_tex(field, result) {
    n = split(field, pair, ",");
    if (n < 2) { pair[2] = ""; }
    result["ntr"] = pair[1];
    result["tex"] = output(pair[2] != "" ? pair[2] : pair[1]);
    gsub(/_/, "\\_", result["tex"]);
}

function print_ntr_tex(pair) {
    printf "out_" pair["ntr"] " {{ tex " pair["tex"] " }}";
}

# Record format
# <indent> "% OUT_HACK|" <field1> ("|"<field>)*
{
    if (NF < 1 || $1 != indent "% OUT_HACK") {
        print;
        next;
    }

    comma = "";
    if ( NF < 2 ) {
        print "'% OUT_HACK' without entries after it";
        exit 1;
    }

    print;

    get_ntr_tex($2, root);
    printf indent;
    print_ntr_tex(root);

    # Print out all NTRs
    for (i = 3; i <= NF; i++ ) {
        printf " , ";
        get_ntr_tex($i, other);
        print_ntr_tex(other);
    }

    # Print out res out rule
    printf indent;
    print " :: 'Out_hack_' ::=  {{ com Ott-hack, ignore }}";
    printf indent;
    print "  | " root["ntr"] " :: :: " root["ntr"] " {{ tex " output("[[" root["ntr"] "]]") " }}";
    print "";
}
