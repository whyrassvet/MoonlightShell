function lavat
    set -l f ~/.config/fastfetch/matugen-colors.txt
    if test -f $f
        set -l c (cat $f)
        command lavat -g -c (string upper (string replace '#' '' $c[1])) -k (string upper (string replace '#' '' $c[3])) $argv
    else
        command lavat $argv
    end
end
