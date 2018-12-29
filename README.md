# localconfig
Local config files for consistent user environment ... everywhere :-)

Package version: 0.4

# Installation
Depending on the OS and VIM version, the installation path may be different. I'm using FBSD or Raspberry (Debian).

## vim & screen configs
Copy .vimrc and .screenrc to your home dir

## vim color theme
The badwolf color theme is not mine, see https://github.com/sjl/badwolf

FBSD: /usr/local/share/vim/vim74/colors

      cp colors/badwolf.vim .

*NIX: /usr/share/vim/vim80/colors

      cp colors/badwolf.vim .
      
## vim plugin
I'm using the airline plugin, see https://github.com/vim-airline/vim-airline

FBSD: /usr/local/share/vim/vim74/plugin

      cp plugin/airline.vim .
      cp airline-themes.vim .
      
*NIX: /usr/share/vim/vim80/plugin

      cp plugin/airline.vim .
      cp plugin/airline-themes.vim .

## vim autoload
FBSD: /usr/local/share/vim/vim74/autoload

      cp autoload/ .
      
*NIX: /usr/share/vim/vim80/autoload

      cp autoload/ .
