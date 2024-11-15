CHANGE GLOBALLY
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

Changing existing text is one of the main editing tasks. In Vim, there are two
approaches: Either use the c and s commands, then quit insert mode; maybe
repeat this via . at another location. Or build a :substitute command for
controlled replacement in the line, range, or buffer.
This plugin implements a hybrid of these two contrasting approaches: It offers
a gc command that works just like built-in c, and after leaving insert
mode applies the local substitution to all other occurrences in the current
line (in case of a small character change) or, when entire line(s) were
changed, to the rest of the buffer.

### HOW IT WORKS

The gc command hooks itself into the InsertLeave event, then applies
something like :s/\\=@"/\\=@./g to the line or buffer.

### SEE ALSO

- ReplaceWithRegister ([vimscript #2703](http://www.vim.org/scripts/script.php?script_id=2703)) simplifies another frequent editing
  task: Replace the moved-over text / selection with the contents of register.
  Compared to the gr... and &lt;Leader&gt;gr mappings here, it provides a quicker
  way to replace single instances, and can also correctly deal with blockwise
  register contents.
- ChangeGloballySmartCase ([vimscript #4322](http://www.vim.org/scripts/script.php?script_id=4322)) is an add-on to this plugin that
  implements a gC variant that uses a "smart case" substitution which covers
  variations in upper-/lowercase ("maxSize" vs. "MaxSize") as well as
  different coding styles like CamelCase and underscore\_notation ("maxSize",
  "MAX\_SIZE").

### RELATED WORKS

- Without the plugin, you can use the star or / commands to search for the
  existing text, then use cgn to change the next occurrence, then repeat
  this with . as often as needed.
- multichange.vim ([vimscript #4309](http://www.vim.org/scripts/script.php?script_id=4309)) uses a command :[range]MultiChange to
  modify the default c command to do an entire-word global substitution in the
  entire range.
- vim-subversive (https://github.com/svermeulen/vim-subversive) implements a
  "substitute over range motion" that works like gc\* and &lt;Leader&gt;gc, but
  queries for the replacement text instead of letting you edit it in the
  buffer.
- vim-mode-plus for the Atom editor has an occurrence modifier for
  operator-pending mode
  (https://github.com/t9md/atom-vim-mode-plus/wiki/OccurrenceModifier) that
  applies the current word to the {motion} text, working like gc\* / gx\* (but
  not limited to change and delete, so other commands like gU also work).

USAGE
------------------------------------------------------------------------------

    [N]["x]gc{motion}       Delete {motion} text [into register x] and start
                            inserting.
    {Visual}[N]["x]gc       Delete the highlighted text [into register x] and
                            start inserting.
                            After exiting insert mode, the substitution is
                            applied:
                            - For characterwise motions / selections: Globally to
                              the changed line if possible, or globally in the
                              entire buffer when no additional substitution can be
                              made in the changed line or a very large [N] is
                              given g:ChangeGlobally_GlobalCountThreshold.
                            - For linewise motions / selections: Globally (for
                              identical complete lines) in the entire buffer.
                            - [N] times (including the just completed change, so
                              only N > 1 really makes sense), starting from the
                              position of the changed text, also moving into
                              following lines if not all [N] substitutions can be
                              made in the current line. To avoid this spill-over,
                              and just apply all possible substitutions from the
                              current position to the end of the line, you can
                              specify g:ChangeGlobally_LimitToCurrentLineCount.
                              Note: A possible [count] inside {motion} is
                              different from [N]; e.g., 2gc3w changes 3 words, and
                              then applies this change 1 more time.

                            The substitution is always done case-sensitive,
                            regardless of the 'ignorecase' setting.
                            When the changed text is surrounded by keyword
                            boundaries (/\<text\>/), only keyword matches are
                            replaced so spurious matches inside keywords (e.g.
                            "IN" inside "rINg") are ignored. This does not apply
                            to visual selections.

    ["x]gcc                 Delete [count] lines [into register x] and start
                            insert linewise. If 'autoindent' is on, preserve the
                            indent of the first line. After exiting insert mode,
                            the substitution is applied globally.

                            When a command is repeated via ., the previous
                            substitution (without entering a new insert mode) is
                            re-applied to the visual selection, [count] next
                            lines, or the range of the previous substitution.
                            For a command that used a limit [N], the number of
                            substitutions and the start column from where they
                            were applied are kept.

                            With the visualrepeat.vim plugin, commands can be
                            repeated on a blockwise-visual selection. In that
                            case:
                            - A repeat of gcc matches not only complete lines
                              (they probably aren't fully selected), just the text
                              itself.
                            - Start column and [N] limit restrictions are dropped;
                              the change is applied anywhere inside the selected
                              block.
                            All these modifications are kept for subsequent
                            repeats of the repeat, so the blockwise repeat can be
                            cleverly employed to remove certain change
                            restrictions for following repeats of different kinds.

    [N]["x]gx{motion}       Delete {motion} text [into register x] and apply the
                            deletion.
    {Visual}[N]["x]gx       Delete the highlighted text [into register x] and
                            apply the deletion, like with gc.
    ["x]gxx                 Delete [count] lines [into register x] and apply the
                            deletion globally.

    [N]["x]gc*{motion}      Delete the current whole \<word\> [into register x]
                            and start inserting. After exiting insert mode, that
                            text substitution is applied to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]gx*{motion}      Delete the current whole \<word\> [into register x]
                            and apply the deletion to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]gr*{motion}      Delete the current whole \<word\> and replace all /
                            the first [N] occurrences with the contents of the
                            default register / register x inside {motion} text.

    [N]["x]gcg*{motion}     Delete the current word [into register x] and
                            start inserting. After exiting insert mode, that text
                            substitution is applied to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]gxg*{motion}     Delete the current word [into register x] and
                            apply the deletion to all / the first [N] occurrences
                            inside {motion} text.

    [N]["x]grg*{motion}     Delete the current word and replace all / the first
                            [N] occurrences with the contents of the default
                            register / register x inside {motion} text.

    [N]["x]gc_ALT-8{motion} Delete the current whole \_sWORD\_s [into register x]
                            and start inserting. After exiting insert mode, that
                            text substitution is applied to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]gx_ALT-8{motion} Delete the current whole \_sWORD\_s [into register x]
                            and apply the deletion to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]gr_ALT-8{motion} Delete the current whole \_sWORD\_s and replace all /
                            the first [N] occurrences with the contents of the
                            default register / register x inside {motion} text.

    [N]["x]gcg_ALT-8{motion}Delete the current WORD [into register x] and start
                            inserting. After exiting insert mode, that text
                            substitution is applied to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]gxg_ALT-8{motion}Delete the current WORD [into register x] and
                            apply the deletion to all / the first [N] occurrences
                            inside {motion} text.

    [N]["x]gr_gALT-8{motion}Delete the current WORD and replace all / the first
                            [N] occurrences with the contents of the default
                            register / register x inside {motion} text.

    [N]["x]<Leader>gc{source-motion}{target-motion}
                            Delete {source-motion} text [into register x] and
                            start inserting. After exiting insert mode, that text
                            substitution is applied to all / the first [N]
                            occurrences inside {target-motion} text.
    {Visual}[N]["x]<Leader>gc{motion}
                            Delete the selected text [into register x] and start
                            inserting. After exiting insert mode, that text
                            substitution is applied to all / the first [N]
                            occurrences inside {motion} text.

    [N]["x]<Leader>gx{source-motion}{target-motion}
                            Delete the {source-motion} text [into register x] and
                            apply the deletion to all / the first [N] occurrences
                            inside {target-motion} text.
    {Visual}[N]["x]<Leader>gx{motion}
                            Delete the selected text [into register x] and apply
                            the deletion to all / the first [N] occurrences inside
                            {motion} text.

    [N]["x]<Leader>gr{source-motion}{target-motion}
                            Delete {source-motion} text and replace all / the
                            first [N] occurrences with the contents of the default
                            register / register x inside {target-motion} text.
    {Visual}[N]["x]<Leader>gr{motion}
                            Delete the selected text and replace all / the first
                            [N] occurrences with the contents of the default
                            register / register x inside {target-motion} text.

                            When any of these commands is repeated via ., the
                            previous substitution of the same source text is
                            re-applied to {motion} (relative to the current
                            position now) again.
                            With the visualrepeat.vim plugin, you can also
                            directly reapply to the current selection instead of
                            the previous {motion}. Further repeats will then
                            target a selection of the same size as before.
### EXAMPLE

Suppose you have a line like this, and you want to change "de" to "en":
```
A[lang=de]:after, SPAN[lang=de]:after { content: url("lang.de.gif"); }
```

With the cursor on the start of any of the "de", type |gc|e, enter the text
"en", then press &lt;Esc&gt;. The line will turn into
```
A[lang=en]:after, SPAN[lang=en]:after { content: url("lang.en.gif"); }
```
You can now re-apply this substitution to other lines or a visual selection
via . repeat.

Now we want to change all SPAN to DIV in the current paragraph. Position the
cursor on the SPAN and type |gc\*|ip, enter "DIV", and press &lt;Esc&gt;. You'll get
```
A[lang=en]:after, DIV[lang=en]:after { content: url("lang.en.gif"); }
```
The change is also propagated to surrounding lines, according to the ip text
object.

Now let's get rid of the ":after" in this line and the next 3 ones. With the
cursor on the ":", type |&lt;Leader&gt;gx|t,3+, and the line turns to
```
A[lang=en], DIV[lang=en] { content: url("lang.en.gif"); }
```
as the t, chooses the source text (to be deleted), and 3+ is a motion that
includes the next 3 lines.

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-ChangeGlobally
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim ChangeGlobally*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.042 or
  higher.
- repeat.vim ([vimscript #2136](http://www.vim.org/scripts/script.php?script_id=2136)) plugin (optional)
- visualrepeat.vim ([vimscript #3848](http://www.vim.org/scripts/script.php?script_id=3848)) plugin (version 2.00 or higher; optional)

CONFIGURATION
------------------------------------------------------------------------------

For a permanent configuration, put the following commands into your vimrc:

To apply a characterwise substitution globally in the entire buffer even when
there are additional substitutions in the current line, a very large [count]
can be supplied. To change the threshold, use:

    let g:ChangeGlobally_GlobalCountThreshold = 999

To turn off this feature, set the threshold to 0.

As it's sometimes not easy to quickly count the number of occurrences to
replace, or particular occurrences have to be skipped, the special count value
of 888 makes the commands switch to confirm each replacement (via the :s\_c
flag). You can change this value or turn off this feature by setting it to 0:

    let g:ChangeGlobally_ConfirmCount = 0

A count [N] for a characterwise gc motion / selection will also substitute
in subsequent lines if there are less than [N] matches in the current line. To
avoid that, you can specify a special number [N], which limits the
substitutions to the end of the current line. You can change this value or
turn off this feature by setting it to 0:

    let g:ChangeGlobally_LimitToCurrentLineCount = 99

If you want no or only a few of the available mappings, you can completely
turn off the creation of the default mappings by defining:

    :let g:ChangeGlobally_no_mappings = 1

This saves you from mapping dummy keys to all unwanted mapping targets.

If you want to use different mappings, map your keys to the &lt;Plug&gt;(Change...)
and &lt;Plug&gt;(Delete...) mapping targets _before_ sourcing the script (e.g. in
your vimrc):

    nmap <Leader>c <Plug>(ChangeGloballyOperator)
    nmap <Leader>cc <Plug>(ChangeGloballyLine)
    xmap <Leader>c <Plug>(ChangeGloballyVisual)
    nmap <Leader>x <Plug>(DeleteGloballyOperator)
    nmap <Leader>xx <Plug>(DeleteGloballyLine)
    xmap <Leader>x <Plug>(DeleteGloballyVisual)

    nmap gc* <Plug>(ChangeWholeWordOperator)
    nmap gx* <Plug>(DeleteWholeWordOperator)
    nmap gr* <Plug>(RegisterWholeWordOperator)
    nmap gcg* <Plug>(ChangeWordOperator)
    nmap gxg* <Plug>(DeleteWordOperator)
    nmap grg* <Plug>(RegisterWordOperator)
    nmap gc<A-8> <Plug>(ChangeWholeWORDOperator)
    nmap gx<A-8> <Plug>(DeleteWholeWORDOperator)
    nmap gr<A-8> <Plug>(RegisterWholeWORDOperator)
    nmap gcg<A-8> <Plug>(ChangeWORDOperator)
    nmap gxg<A-8> <Plug>(DeleteWORDOperator)
    nmap grg<A-8> <Plug>(RegisterWORDOperator)
    nmap <Leader>gc <Plug>(ChangeOperatorOperator)
    nmap <Leader>gx <Plug>(DeleteOperatorOperator)
    nmap <Leader>gr <Plug>(RegisterOperatorOperator)
    xmap <Leader>gc <Plug>(ChangeSelectionOperator)
    xmap <Leader>gx <Plug>(DeleteSelectionOperator)
    xmap <Leader>gr <Plug>(RegisterSelectionOperator)

LIMITATIONS
------------------------------------------------------------------------------

- During the insertion, insert-mode mappings that use i\_CTRL-O cause an
  InsertLeave event, and therefore trigger the global change -- prematurely,
  as perceived by the user who isn't aware of this.

### CONTRIBUTING

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-ChangeGlobally/issues or email (address
below).

HISTORY
------------------------------------------------------------------------------

##### 2.10    10-Nov-2024
- ENH: Add gr\*, grg\*, gr&lt;A-8&gt;, grg&lt;A-8&gt;, &lt;Leader&gt;gr mappings that replace with
  register contents instead of the changed text / deleting (and capturing in a
  register).
- Work around "E11: Invalid in command-line window" when executed in the
  command-line window.

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.042!__

##### 2.01    24-Feb-2020
- Support {target-motion} of gv in &lt;Leader&gt;gc and &lt;Leader&gt;gx to replace in
  the last selection. (Previously, the {source-motion} clobbered the
  user-established visual selection.)
- The custom operators don't clobber the previous visual selection any longer.
- BUG: Regression: gcc and gxx broken by forgotten adaptation of regexp
  magicness.

##### 2.00    09-Feb-2020
- ENH: Add a set of mappings that apply the change / deletion of cword / cWORD
  / selection over the text moved over by {motion}. So instead of specifying
  the source text via {motion}, the target area is specified. There's even a
  mapping that lets you specify both source and target as two {motion}s!
- Implement special case for the black-hole register, where we cannot extract
  the original text.
- ENH: Allow to disable all default mappings via a single
  g:ChangeGlobally\_no\_mappings configuration flag.

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.040!__

##### 1.31    03-Nov-2018
- BUG: When a {N}gc{motion} substitution is repeated, is it applied only to
  the current, single line, not for {N} instances in subsequent lines.
  ChangeGlobally#Repeat().
- Default to applying {N}gc{motion} beyond the current line, unless a count of
  g:ChangeGlobally\_LimitToCurrentLineCount is given. Especially with
  'hlsearch', one often can see the (low) number of substitutions in the few
  following lines, and it's comfortable to be able to change them all in one
  fell swoop, instead of applying to just the current line and then having to
  repeat over the next few lines with [count]. command.

##### 1.30    12-Dec-2014
- ENH: Implement global delete (gx{motion}, gxx) as a specialization of an
  empty change.

##### 1.21    25-Apr-2014
- FIX: Disable global substitution when g:ChangeGlobally\_GlobalCountThreshold
  is 0, as is documented.
- ENH: Confirm each replacement via :s\_c flag when a special
  g:ChangeGlobally\_ConfirmCount is given.

##### 1.20    19-Nov-2013
- ENH: Special handling for repeat on blockwise selection (through
  visualrepeat.vim) that makes more sense.
- Autocmds may interfere with the plugin when they temporarily leave insert
  mode (i\_CTRL-O) or create an undo point (i\_CTRL-G\_u). Disable them until the
  user is done inserting.
- Use optional visualrepeat#reapply#VisualMode() for normal mode repeat of a
  visual mapping. When supplying a [count] on such repeat of a previous
  linewise selection, now [count] number of lines instead of [count] times the
  original selection is used.
- Avoid changing the jumplist.
- Add dependency to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)).

__You need to separately
  install ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.011 (or higher)!__

##### 1.10    19-Jan-2013 (unreleased)
- ENH: Handle undo points created during insertion: Undo the whole insertion
sequence (by using :undo with the original change number) and substitute the
entire captured insertion, not just the last part, by detecting a multi-change
insert and using the original start position instead of the start change mark.

##### 1.01    19-Jan-2013
- BUG: Linewise changes (gcc) causes beep instead of substitution.

##### 1.00    23-Nov-2012
- First published version.

##### 0.01    29-Aug-2012
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2012-2024 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
