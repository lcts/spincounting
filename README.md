## Spincounting Toolbox

A MatLab toolbox for quantitative EPR.

### Overview
This MatLab toolbox is designed to facilitate and automate the evaluation of quantitative EPR data.

### System Requirements
 * MatLab 2013b or later
 * Optimisation Toolbox (only when using the lorentz and gauss model for resonator dip fitting)
 * [easyspin](http://easyspin.org) (only for loading Bruker BES3T and Magnetec XML files).

### Releases & Download

Latest stable release: [v3.0.1](https://github.com/lcts/spincounting/releases/latest) ([Download](https://github.com/lcts/spincounting/archive/v3.0.1.zip))  Development version: [Download](https://github.com/lcts/spincounting/archive/master.zip)

Older releases can be found on the [releases page](https://github.com/lcts/spincounting/releases).

### Installation & first steps
Add the spincounting folder to your MatLab search path. Read and follow documentation/INSTALL. The toolbox is invoked by typing `spincounting` on the MatLab command line.

### Upgrading from v2.x.x
Version 3.0.0 of spincounting introduced machine files and various changes to scconfig as well as the output format. To migrate your configuration from v2.x.x to 3.x.x, you should, after updating

 1. copy your `scconfig.m` to `scconfig.m.backup`
 2. copy `documentation/templates/scconfig.m.template` to `private/scconfig`
 3. copy the options you set in the `DEFAULTS` variable in `scconfig.m.backup` to either `DEFAULT_OPTIONS` in `scconfig.m` or `MACHINE_PARAMETERS` in a machine file, as applicable.
 4. If you used any self-written load routines, copy them from `scconfig.m.backup` to `scconfig.m`. Note that the new `scconfig.m` uses a single variable `<TUNE|SPECTRUM>_FORMATS` instead of the old `<TUNE|SPECTRUM>_KNOWN_FORMATS` and `<TUNE|SPECTRUM>_LOADFUNCTIONS`.

Additionally, v3.x.x no longer returns `[nspins, tfactor, outstr]`, but `[out, outstr]`, where `out` contains `nspins`, `tfactor` or `nspinerror` depending on the operation mode. All values are still saved individually to the struct output `outstr`, but the structure of `outstr` has changed as well. You will need to
edit your scripts accordingly.

### Support or Contact
Having trouble? Questions? Requests? Contact me and I’ll try to help you sort it out.

Author: Christopher Engelhard

Mail: christopher.engelhard [at] fu-berlin.de
