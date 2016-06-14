# ![](https://ga-dash.s3.amazonaws.com/production/assets/logo-9f88ae6c9c3871690e33280fcf557f33.png) VM Installation Instructions & Troubleshooting Tips

## Installation
1. Create a directory somewhere to put your virutal box file in that will run your virtual machine.  (ie: dsi-bigdata-vm)
2. (Optional) [personal Dropbox account](https://www.dropbox.com/). If they don't, ask them to sign up for a free version. Due to the large size, you may need to create an account to download the VM files (I believe you can skip registration for this).
3. [Download files from the following link. There are two files to be downloaded: `dsi-bigdata-vm.box` BUT NOT `Vagrantfile`. 
    - Note: This file is 2.5gb so download may take some time. Additionally, ensure you have enough disk space.
4. Download and install [Virtualbox](https://www.virtualbox.org/wiki/Downloads)
5. Download and install [Vagrant](https://www.vagrantup.com/)
6. Put [this vagrant](./Vagrantfile) file in the same directory as the file `dsi-bigdata-vm.box`.
7. Once Vagrant and Virutalbox are installed, provision and run the VM with the following commands:

        cd dsi-bigdata-vm
        vagrant up
        vagrant ssh


## Troubleshooting

Problems?  Here are some strategies to try:

1. Make sure the VM was installed correctly by connecting to it via:
        vagrant up
        vagrant ssh
2. Free up some memory by closing some of the applications they are running.
3. Review the specific instructions for each assignment within the lesson and lab readme files for this week and ensure that the commands were input correctly.
4. If these checks don't work for some of us, find your *nearest neighbor* with a working machine then put on your safety equipment. 

We'll do our best to debug as many system problems as possible but ultimately, we will have to work in groups to get around some of the limitations of any of our setups by working together.
