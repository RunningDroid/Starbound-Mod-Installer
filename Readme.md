# Starbound Mod Installer (sbmi)
A mod installer for [Starbound](http://playstarbound.com)
## Usage:
### Adding Mods:
```
$ sbmi -a 'First Awesome Mod.zip' Second_Awesome_Mod.rar "Third Awesome Mod.7z"
Adding First Awesome Mod
Adding Second Awesome Mod
Adding Third Awesome Mod
```
```
$ sbmi --add really\ awesome\ mod.rar'
Adding Really Awesome Mod
```
### Listing Installed Mods:
```
$ sbmi -l
First Awesome Mod
Second Awesome Mod
Third Awesome Mod
Really Awesome Mod
```
```
sbmi --list
First Awesome Mod
Second Awesome Mod
Third Awesome Mod
Really Awesome Mod
```
### Removing Mods:
```
$ sbmi -r "First Awesome Mod" 'Second Awesome Mod'
Removing First Awesome Mod
Removing Second Awesome Mod
```
```
$ sbmi --remove 'Third Awesome Mod'
Removing Third Awesome Mod
```
