if status is-interactive
    # Commands to run in interactive sessions can go here
    zoxide init fish | source
    fzf --fish | source

    # Set text editor
    set -gx EDITOR hx

    # Changes greeting text.
    set -g fish_greeting "From the moment I understood the weakness of the GUI, it disgusted me."

    # Some aliases 
    alias yz="yazi"
end
