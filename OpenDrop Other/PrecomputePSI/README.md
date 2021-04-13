#  PrecomputePSI   
This part of our project is a command line interface (CLI) for performing the precomputation, signing and export of the identifiers used during the private set intersection (PSI). PSI is added as an addition to AirDrop to make it more private. 

## Usage

```bash
USAGE: psi-precompute [--verbose] [<Contact ids> ...] [--sign <Certificate Path>] [--password <Certificate password>] [--output <Output directoy>]

ARGUMENTS:
  <Contact ids>           A list of contact ids 
        A list of contact ids, like email addresses and phone numbers. The list
        is seperated by spaces. 
        The phone numbers do not contain a + sign or 00 they start with the
        country code: e.g. 471239239

OPTIONS:
  --verbose               Verbose logging of all steps 
  --sign <Certificate Path>
                          Sign Y-values with certificate 
        Provide a certificate to a p12 file that contains the certificate and
        the private key used for signing
  --password <Certificate password>
                          Password for the p12 file 
        Optional password for the provided p12 file
  --output <Output directoy>
                          Output directory 
        Optional output directory to which the generated files should be saved.
        If not provided the current directory will be used
  -h, --help              Show help information.
```

## Import 
The exported files need then to be imported by OpenDrop such that OpenDrop is able to use them for PSI. 
Make sure that the certificate, which is used for signing the PSI values is also made available for OpenDrop

## OS-Support 
macOS  
