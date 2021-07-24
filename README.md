# localconfig

These are the Local Config files for a consistent user environment which I use... everywhere :-)
It's mainly .screenrc / .vimrc / .bashrc

Package version: 0.5 (2021 update)

## Pre-requisites

1. Ensure you have edited your sudoers file for passwordless sudo
2. install the following dependencies:
   1. vim-gtk
   2. htop

## Installation

Depending on the OS and VIM version, the installation path may be different. I'm using three versions for .screenrc:

1) generic for FBSD   --> see folder 1-FBSD
2) generic for Debian --> see folder 2-Debian
3) specific for Kali  --> see folder 3-Kali

### vim & screen configs

1. Copy .vimrc and .screenrc to your home dir
2. Create .vim dir under home dir

### vim color theme

The badwolf color theme is not mine, see <https://github.com/sjl/badwolf>
Change the ** to your installed version of VIM. Copy the badwolf.vim to colors/

      /usr/local/share/vim/vim**/colors or /usr/share/vim/vim**/colors
      cp colors/badwolf.vim .

### vim plugin

I'm using the airline plugin, see <https://github.com/vim-airline/vim-airline>
Change the ** to your installed version of VIM. Copy the airline files to plugin/

      /usr/local/share/vim/vim**/plugin or /usr/share/vim/vim**/plugin

      cp plugin/airline.vim .
      cp airline-themes.vim .

### vim autoload

      /usr/local/share/vim/vim**/autoload or /usr/local/share/vim/vim**/autoload
      cp -r autoload/ .
