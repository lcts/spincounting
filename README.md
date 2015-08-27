spincounting
============

A ESR spincounting script for MATLAB

### Overview
This MatLab toolbox is designed to facilitate and automate the evaluation of quantitative EPR data. In can be used both to calibrate an EPR spectrometer for future quantitative measurements and to calculate the number of spins from a spectrum obtained on a calibrated machine.

Additionally, when given a file containing a tune picture, it can perform automatic calculation of the quality factor Q.

### Requirements
 * spincounting v1.5
    * MatLab 2012 or later
    * tested on MatLab 2013b and Matlab 2015

### Versions
The current stable release version is v1.5. It can be downloaded from the link above.

The current development release is v2.0. It is available here.

Or you can use the git version:
 * Current stable branch:

`git clone http://github.com/lcts/spincounting`

 * Only released versions:

`git clone http://github.com/lcts/spincounting --branch release`

 * Development branch:

`git clone http://github.com/lcts/spincounting --branch develop`

### Installation & first steps
Extract the downloaded archive to any location on your computer, and add that location to your MatLab search path. (In MatLab -> 'Set Path ...' or by editing MatLab's pathdef.m). The toolbox can be invoked by typing 'spincounting' on the MatLab command line. Further information/documentation can be found in the README file and in the functions themselves.

### Support or Contact
Having trouble? Questions? Requests? Contact me and I’ll try to help you sort it out.

Author: Christopher Engelhard

Mail: christopher.engelhard [at] fu-berlin.de
