function cc --wraps=claude --description 'claude, from outside herdr in its ~/Claude workspace'
    if set -q HERDR_ENV
        claude $argv
        return
    end

    # The workspace with a pane in ~/Claude, or a new one running claude.
    set -l dir ~/Claude
    set -l panes (herdr pane list 2>/dev/null)
    or begin
        claude $argv
        return
    end
    set -l ws (echo $panes | jq -r --arg dir $dir 'first(.result.panes[] | select(.cwd == $dir) | .workspace_id) // empty')
    if test -z "$ws"
        set -l root (herdr workspace create --cwd $dir --no-focus | jq -r '.result.root_pane | .workspace_id, .pane_id')
        test (count $root) -eq 2; or return 1
        set ws $root[1]
        herdr pane run $root[2] (string join ' ' -- claude (string escape -- $argv)) >/dev/null
    end
    herdr workspace focus $ws >/dev/null
    herdr
end
