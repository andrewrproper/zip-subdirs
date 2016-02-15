
![&nbsp;](resources/zip-subdirs-icon-export.ico)

# Zip Subdirs

*Copyright [Andrew Proper](https://endosynth.wordpress.com/) 2016.*

Tested on Windows 7, 8, 10.

[Zip-Subdirs News Online](https://endosynth.wordpress.com/category/zip-subdirs/)

## Purpose

Allows the user to select a directory, then displays the list of
subdirectories under that directory. The user can select one or
more (Ctrl-click) subdirectories to zip, then press the Zip button.

Subdirectories will be zipped in the order they are listed. Each
one will be zipped into a timestamped zip file. Insize the zip file,
the top-level item will be the subdirectory with a timestamp appended.

## Install

First install [DWIMPerl](http://dwimperl.com).

  - This was tested with [DWIMPerl](http://dwimperl.com) v5.14.2.1 v7 32 bit for Windows.
  - If you cant get [DWIMPerl](http://dwimperl.com), Strawberry Perl may work.

After that is installed, you can run the ```zip-subdirs``` shortcut to start.

If you have problems, try running ```zip-subdirs-debug.bat``` to see any
debug or error output (in the black command prompt window).


## Compiling to Exe

You will need to install the **PAR::Packer** CPAN module into DWIMPerl, using
its cpan interface. This basically involves opening a Windows command prompt 
and running:

```
cpan
> install PAR::Packer
```

After that, you can run ```compile_to_exe.bat``` to create a .exe file from 
the .pl file. 

Note that this essentially just creates a zip of the perl code 
which can extract and run itself. It may not be better or faster than running
the .pl file directly via its .bat file.



