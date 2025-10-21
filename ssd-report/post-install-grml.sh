apt-get install cups
To add an HP printer on Grml (Debian-based), you'll likely use CUPS (Common Unix Printing System).

Steps:
1. Install CUPS: Ensure CUPS is installed.

bash
sudo apt update
sudo apt install cups


2. Start CUPS service: Ensure the CUPS service is running.

bash
sudo systemctl start cups
sudo systemctl enable cups


3. Use lpadmin: Add the printer using lpadmin.

bash
sudo lpadmin -p HP_Printer -v ipp://192.168.2.96/ipp -m everywhere

* `-p HP_Printer`: Names the printer.
* `-v ipp://192.168.2.96/ipp`: Specifies the printer's IP and protocol.
* `-m everywhere`: Uses the IPP Everywhere driver.

4. Set default printer (optional):

bash
sudo lpadmin -d HP_Printer


5. Enable printer:

bash
sudo cupsenable HP_Printer


6. Accept print jobs:

bash
sudo cupsaccept HP_Printer


Verify:
- Check printer status: lpstat -p HP_Printer
- Print a test page: lp -d HP_Printer /usr/share/cups/data/testprint.ps

Ensure your HP printer supports IPP (Internet Printing Protocol) for this method to work smoothly.
