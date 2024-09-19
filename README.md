# csv-analyser.nvim

Note:  
This is a brief Readme to get started. It is likely incomplete and should definitely be improved.  
The same goes for the code. It is in an early state and not polished. Breaking changes are to be anticipated.  

## Getting Started

This is a neovim plugin, intended to help analyse csv files.  
It can be installed using your preferred plugin manager.  
i.e. using Packer.nvim:  

``` lua
use('u6xk3/csv-analyser.nvim')
```

## Prerequisites

In order for the plugin to work properly, the first line of the csv must be the row with the column names.
i.e.
```
Date; Time; Data; MoreInfo
20-01-2024; 12:02:19; Error.happened; ValueNotFound;
```
Spaces in the header row are currently not supported.  
Trailing separator characters are allowed.  

## Features

csv-analyser.nvim provides commands shortcuts to organise elements of a csv file by  
- hiding/displaying rows according to filter strings
- hiding/displaying columns according to their names
- coloring rows according to filter strings
- adding rows to a jumplist for easy access

This functionality is achieved through commands, which are described in the section [Commands](#commands).  
To start using the plugin, follow the steps under [Configuration](#configuration).  

## Configuration

In order to configure csv-analyser, its setup method is called with a configuration table.  
An Example config looks like this:  

``` lua
local csv = require("csv-analyser")

csv.setup({
    jumplist_position = "below",
    colors = {
        red = { fg = "#F54242" },
        green = { fg = "#00753B" },
        orange = { fg = "#DE8D00" },
        blue = { fg = "#026DBA" },
        yellow = { fg = "#C9A400" },
        purple = { fg = "#7F00C9" }
    },
    delimiter = ";",
    spacing = "  ",
    filters = {
        filter_name = "ColName == Value and ColName2 *= Value2 or ColName3 == Value3"
    }
})

vim.keymap.set("n", "<leader>r", csv.analyse)
```
Except for the filters key, the table visible above represents the default configuration  
if setup is called without a table.  

For any of the commands and shortcuts to be usable, the `csv-analyser.analyse()` method  
has to be called. In the example config this is mapped to `<leader>r`.  
calling `csv-analyser.analyse()` will create two temporary buffers, one with the reformatted  
csv content and one as the jumplist.  

In order to use the jumplist, the keybinding `<leader>j` is defined to open/toggle it.  
If the current window is the jumplist, it will toggle the jumplist.  
If the current window is the csv buffer, it will open the jumplist.  

The possible configuration options are:  
```
jumplist_position   Where the jumplist to csv rows should be opened
                    options are [ "below", "above", "right", "left" ]

colors              A lua table containing subtables with a named key.
                    Each subtable can contain a color code fg (foreground color)  
                    and bg (background color) at least one must be specified.
                    The key used can later be used in a command to apply the color.

delimiter           The character used in the source csv as a separator.

spacing             The string used to separate the column fields in the analyser view.

filters             A lua table containing named strings.  
                    Each string contains a set of rules with predefined header column and  
                    data column values.  
                    This can be useful if the same fields have to be analysed often across  
                    sessions or files.
                    The name of the filter can later be used in a command to apply it.  
```

## Commands

In the analyser view some commands are available to Hide/Show, Color/Clear items and add or remove  
them from a jumplist.  
The available commands are:

```
:CsvHide <filter string>            Hide rows matching <filter string>  

:CsvShow <filter string>            Show rows matching <filter string>

:CsvHideCol <column name>           Hide column by name

:CsvShowCol <column name>           Show column by name

:CsvColor <filter string> <color>   Apply color <color> to rows matching <filter string>

:CsvClear <filter string>           Clear any color on rows matching <filter string>

:CsvAdd <filter string>             Add rows matching <filter string> to jump buffer

:CsvRemove <filter string>          Remove rows matching <filter string> from jump buffer


<filter string>     Is a string matching the pattern "<column name> <compare operator> <value> and/or..."  
                    where <column name> is a name contained in the header row
                          <compare operator> is "==" for euqality or "*=" for patter matching using lua patterns (e.g. gmatch)
                          <value> is the value of the column on the rows to be filtered. This value should not contain spaces
                    possible keywords to combine comparisons are "and" aswell as "or" where "and" gets evaluated first.
                    currently, "()" cannot be used to group change the evaluation order.

<color>             Is the key to a color in the configuration. In the default configuration some colors are predefined.
```

