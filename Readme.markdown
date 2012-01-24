This is a copy of [Objective-Zip library](http://code.google.com/p/objective-zip/) developed by [Flying Dolphin Studio](http://www.flyingdolphinstudio.com). It was forked from [Archlite](https://github.com/Arclite/Objective-Zip) and includes many fixes and changes from [AgileBits](https://github.com/AgileBits/objective-zip).

Archlite's changes included:

* Removed use of exceptions.
* Changed APIs to return NSError objects by reference.
* Removed libz and link against the system version.
* Changes to the naming scheme.

AgileBits' changes included:

* Test application was moved into its own folder.
* ZLib source code was removed and replaced with the shared libz.dylib library available on both Mac OS X and iOS.
* Compiler warnings reported by LLVM 3.0 compiler (Xcode 4) were fixed.

Additional changes include:

* Fixed issues with initializing NSErrors. They were not always created, and they were created without checking that the caller passed a variable to set.
* Added targets for static libraries for iOS (ARM) and Intel, and added a framework target for Mac OS X. Best way to use is now to add the project file as a reference to a parent project and then include the appropriate Objective-Zip target in the build phases of the target that uses it. 
* Removed includes of zip and minizip headers from Objective-Zip headers so that their use is transparent to Objective-Zip users.

Code license

* Objective-Zip: [New BSD License](http://www.opensource.org/licenses/bsd-license.php)
* MiniZip: [See MiniZip website](http://www.winimage.com/zLibDll/minizip.html)
