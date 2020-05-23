## MergeSnapInstaller

This project is a Shell Script which will automatically install and configure your Debian(Buster) system to work with [MergerFS](https://github.com/trapexit/mergerfs) and [SnapRAID](https://www.snapraid.it/). 

**NOTE: The script will detect and use all non-OS drives for snapraid!**

## Installation

To obtain the script, just run the below commands using ```wget```

```bash
wget https://github.com/EdFabre/MergeSnapInstaller/archive/mergesnap-v1.3.tar.gz
tar -xzf mergesnap-v1.3.tar.gz
cd MergeSnapInstaller-mergesnap-v1.3
```
## Usage

```sh
Usage:
./mergesnap.sh [-q] [-u] [-d] [-h] [-y path_to_log] [-p someinteger]

Options:
-q              Runs script non-interactively using defaults
-u              Runs the script in uninstall mode removing installed elements
-d              Runs the script in debug mode, very loud output
-h              Prints help menu, which you are currently reading
-y /var/log/    Path to write log file
-p N            Runs script non-interactively with N parity disks
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.


## License
[MIT](https://choosealicense.com/licenses/mit/)
