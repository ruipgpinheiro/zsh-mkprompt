# zsh-mkprompt
mkprompt is a simple, fast and fully customizable prompt generation framework for zsh

## About
The prompt can be one of the most powerful features of your favorite shell, but it is a mess to maintain and most people don't even bother. If you have more than a basic prompt, the `$PROMPT` and `$RPROMPT` variables become unreadable and unmaintainable. Quite a few themes out there look nice, but they're a "one-size-fits-all" approach, and there's always something that bothers me.

As such, I decided to create a simple yet powerful framework for building a prompt in a way that is maintainable and easily customizable, *mkprompt*. Instead of the framework assuming what everyone wants, it just gives you some tools to make customizing and extending your prompt easy and maintainable. *mkprompt* is in essence a builder for `$PROMPT`-like variables which allows you to add content to your prompt in sections, and automatically takes care of all the annoying book-keeping such as delimiters and prompt-escaping colors.

## Installation

### Dependencies

*mkprompt* was developed and tested on zsh 5.4.2.

The [vcs_info_async module](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/vcs_info_async.zsh) requires [zsh-async](https://github.com/mafredri/zsh-async) to be loaded.


### Getting Started

Clone this repository and source [mkprompt.zsh](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/mkprompt.zsh), or use your preffered plugin manager (such as [zplug](https://www.github.com/zplug/zplug)).

In your .zshrc, simply add `mkprompt_init --default`, and that's it! This command will load the default configuration (see [mkprompt_default.zsh](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/mkprompt_default.zsh) which is very similar to my personal setup.

To customize, copy that file to your zshrc inbetween a `mkprompt_init` and `mkprompt_finish` call. In short, `mkprompt_init` initializes the *mkprompt* subsystem, and `mkprompt_finish` writes the results to the prompt variables.

## Usage

### Initialization: mkprompt_init

The first thing you should do is call `mkprompt_init`. This initializes the *mkprompt* subsystem and exposes the various methods listed below.

### Building a Prompt

#### mkprompt_start

Starts the process of generating a prompt string. Typically, you would use `mkprompt_start "PROMPT"` or `mkprompt_start "RPROMPT"`, although any variable name is allowed.

By default, prompts are built left-to-right (except `$RPROMPT` which generates right-to-left). To override, use the `-rtl` parameter.

#### mkprompt_add

Adds a new section to the prompt.

##### Usage
`mkprompt_add [<parameters>] [-- <content> | -env <content-variable>]`, where

Name | Description
-----|-------------
`parameters` | any of the parameters listed below.
`content` | the section content
`content-variable` | environment variable containing the section content (gets expanded every time the prompt is rendered)
  
NOTE: `-- <content>` and `-env <content-variable>` are exclusive.

Parameter | Description
----------|------------
-d  | next delimiter character (equivalent to using `mkprompt_set_delim` after this command)
-s  | style escape code (e.g. `$fg[red]`) <br/> NOTE: must be only non-printable characters
       
#### mkprompt_set_delim

Sets the string that should be used before the next (and only the next) section.

#### mkprompt_add_raw

Adds a raw string to the prompt directly, ignoring the delimiter and any escaping necessary.

#### Modules

Creating a module is very simple, since it only requires creating a function which wraps a `mkprompt_add` call.

A few modules are included with *mkprompt*:

Name (`mkprompt_*`) | Description
--------------------|------------
[clock](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/clock.zsh) | Shows the current time (`HH:MM`)
[cwd](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/cwd.zsh) | Shows the current working directory. <br/> Can be customized with different formatters using `-f <formatter>`, possible ones are `zsh` (default), `prefix` and `prefix-unique`. <br/> A custom formatter function may also be provided.
[exec_time](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/exec_time.zsh) | Shows the execution time of the last command if it exceeded a certain duration
[hostname](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/hostname.zsh) | Shows the host name of the machine
[jobs](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/jobs.zsh) | Shows the number of jobs running in the background
[prompt](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/prompt.zsh) | Shows the prompt symbol (e.g. `%`)
[username](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/username.zsh) | Shows the current username
[vcs_info](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/vcs_info.zsh) | Shows information about the repository in CWD, if any. Local synchronous version
[vcs_info_async](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/vcs_info_async.zsh) | Asynchronous version of `mkprompt_vcs_info` with extra functionality. Requires [zsh-async](https://github.com/mafredri/zsh-async) plugin.
[vimode](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/modules/vimode.zsh) | Shows `vi` when ZLE is in vimode

For module usage and documentation, check the comments at the top of each module's file or the [default configuration](https://github.com/ruipgpinheiro/zsh-mkprompt/blob/master/mkprompt_default.zsh).

### Finishing up: mkprompt_finish

`mkprompt_finish` is responsible for writing the prompt variables to the environment and then cleaning up the `mkprompt_*` namespace. It should always be called after all other `mkprompt_*` calls.


## License

*mkprompt* is licensed under the MIT License.
