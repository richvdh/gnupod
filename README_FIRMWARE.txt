Apple doesn't update the iPod-Software-Updater packages anymore. This means that the old dmg2iso/wrestool method doesn't work for
newer firmware releases. Starting with iTunes 7.4.1 the process became easier anyway: You don't have to download ALL images anymore.

To obtain the latest firmware, just do what iTunes 7.4.1 does:


Step 1: Obtain the URL-List
    wget -O list.gz http://ax.phobos.apple.com.edgesuite.net//WebObjects/MZStore.woa/wa/com.apple.jingle.appserver.client.MZITunesClientCheck/version

Step 2: Extract it
    gunzip list.gz # The webserver does always send a compressed version

Step 3: 
    Open 'list' in a text editor/pager. The file is just a XML document with some interesting URLs.

    Interesting stuff (as of 2007-09-16):

    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3877.20070914.n9gGb/iPod_24.1.0.1.ipsw</string>  iPod Classic (2007)
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2790.20061206.iPr9t/iPod_25.1.2.1.ipsw</string>  iPod Video late 5th Gen (30 or 80 gb)
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3878.20070914.P0omB/iPod_26.1.0.1.ipsw</string>  ipod Nano 3th Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3326.20070507.0Pm87/iPod_29.1.1.3.ipsw</string>  iPod Nano 2nd Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3316.20070618.9n1bC/iPod_130.1.0.3.ipsw</string> iPod Shuffle 2nd Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3317.20070618.nBh6t/iPod_131.1.0.3.ipsw</string> iPod Shuffle 2nd Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2975.20061218.in8Uq/iPod_128.1.1.5.ipsw</string> iPod Shuffle 1st Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2692.20060912.pODcW/iPod_10.3.1.1.ipsw</string>  iPod Clickwheel
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2694.20060912.ipDcD/iPod_11.1.2.1.ipsw</string>  iPod Photo
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2788.20061206.nS1yA/iPod_13.1.2.1.ipsw</string>  iPod 5th Gen.
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3190.20070315.p0oj7/iPod_14.1.3.1.ipsw</string>  iPod Nano 1st Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3191.20070315.BgV6t/iPod_17.1.3.1.ipsw</string>  iPod Nano 1st Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-3325.20070507.KnB7v/iPod_19.1.1.3.ipsw</string>  iPod Nano 2nd Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2686.20060912.ipTsW/iPod_1.1.5.ipsw</string>     Scroll-Wheel iPod (1st iPod ever)
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2687.20060912.IPwdC/iPod_2.2.3.ipsw</string>     iPod 'Dock connector'
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2688.20060912.iDMni/iPod_3.1.4.1.ipsw</string>   iPod mini 1st Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2691.20060912.ipDcw/iPod_4.3.1.1.ipsw</string>   iPod Clickwheel
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2693.20060912.PdwCD/iPod_5.1.2.1.ipsw</string>   iPod Photo
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2689.20060912.ipDmn/iPod_6.1.4.1.ipsw</string>   iPod mini 1st Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2690.20060912.PdMin/iPod_7.1.4.1.ipsw</string>   iPod mini 2nd Generation (?)
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2953.20061218.yRet5/iPod_129.1.1.5.ipsw</string> iPod Shuffle 1st Generation
    <string>http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2789.20061206.9IIut/iPod_20.1.2.1.ipsw</string>  iPod 5th Gen.


    -> Checkout http://docs.info.apple.com/article.html?artnum=61688 to identify our iPod model.
    -> Please note that the description of some URLs is just a guess. Don't blame me if the upgrade doesn't work.
    -> It may be a good idea to create a backup of your old firmware before upgrading (dd if=/dev/ipod1 of=firmware_backup) 

Step 4: Upgrade (Example for a 5th Gen iPod (30 or 80GB)

    Download the firmware archive for our iPod model:
     wget http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPod/SBML/osx/bundles/061-2790.20061206.iPr9t/iPod_25.1.2.1.ipsw

    This is just a zipfile, go ahead and extract it:
     unzip iPod_25.1.2.1.ipsw
    (ignore the manifest.plist file. you'll just need the Firmware-* file)

    Ok, now you can copy the file to your iPods firmware partition:
     dd if=Firmware-25.6.2.1 of=/dev/sda1
     sync

    Unplug the iPod and it should start to re-flash itself.


    
