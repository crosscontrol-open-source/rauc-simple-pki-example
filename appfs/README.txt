All files included in this folder will be added to /appfs on the display.
Detailed instructions at https://crosscontrol.com/manual/CCLinux%204%20-%20RaucGuide/index.html

Example usage for CCPilot V700:

 - Extract Qt runtime folder for the CCPilot V700 display:
   Runtime can be downloaded from https://crosscontrol.com/media/p0ppmics/linx-qt68-v700-ccl40_680-1_aarch64.tar.gz
   "tar -xf linx-qt68-v700-ccl40_680-1_aarch.64tar.gz -C <this folder>"
 - Create a folder and add your binary e.g. <this folder>/bin/myAppliaction
 - Create folder structure: 
     <this folder>/lib/systemd/system/ 
     <this folder>/lib/systemd/system/multi-user.target.wants
 - Create a systemd service startup script and place it in lib/systemd/system/myApplication.service
 - Create a soft link from  lib/systemd/system/myApplication.service -> lib/systemd/system/multi-user.target.wants 
 - This will automatically start the your application during boot since /appfs/lib/systemd/system is in systemd search path



Note: Everything in this folder including this README file will be copied to the display using RAUC install.
