#Rubynette

**A norminette - Ruby flavor.**

##Synopsis

Rubynette is a Norm checker, which operates on C source files, C headers, all kinds of binairies as well as Makefiles.

##Installation

To install Rubynette:

1. Clone this repository in your home
    $> cd ~
    $> git clone https://github.com/Nax/rubynette.git
2. Make a symbolic link to the rubynette files in your ~/bin (if it doesn't exist yet you should create your bin folder).
    $> ln -s ~/rubynette/rubynette
    $> ln -s ~/rubynette/rubynette.rb
3. Add the path to your ~/.myzshrc (or ~/.bash_profile).
    export PATH=$PATH:~/bin
4. Reload your shell
    $> source ~/.myzshrc

##Usage

    $> rubynette [file1] [file2] [file3] ...

##Update
To update the rubynette just go to your ~/rubynette and pull the master branch
    $> cd ~/rubynette
    $> git fetch 
    $> git pull origin master

##License
Rubynette is available under the [GNU General Public License, version 3](LICENSE).
